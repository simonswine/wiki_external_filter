require 'digest/sha2'

module WikiExternalFilterHelper

  def load_config
    unless @config
      unless File.exists?($wiki_external_filter_config)
        raise "Config not found: #{$wiki_external_filter_config}"
      end
      @config = YAML.load_file($wiki_external_filter_config)[ENV["RAILS_ENV"]]
    end
    @config
  end

  def has_macro(macro)
    config = load_config
    config.key?(macro)
  end

  module_function :load_config, :has_macro

  def construct_cache_key(macro, name)
    ['wiki_external_filter', macro, name].join("/")
  end

  def build(text, attachments, macro, info)

    name = Digest::SHA256.hexdigest(text)
    result = {}
    content = nil
    cache_key = nil
    expires = 0

    if info.key?('cache_seconds')
      expires = info['cache_seconds']
    else
      expires = Setting.plugin_wiki_external_filter['cache_seconds'].to_i
    end

    Rails.logger.warn "build: expires is #{expires}"

    if expires > 0
      cache_key = self.construct_cache_key(macro, name)
      begin
        content = read_fragment cache_key, :expires_in => expires.seconds
        if content 
            cl = content.length()
        else
            cl = 0
        end
        Rails.logger.warn "Read fragment #{cache_key} #{cl} bytes"
      rescue => detail
        Rails.logger.error "Failed to load cache: #{cache_key}, error: " + $!.to_s + detail.backtrace.join("\n")
      end
    end

    if content
      result[:source] = text
      result[:content] = content
      Rails.logger.debug "from cache: #{cache_key}"
    else
      result = self.build_forced(text, attachments, info)
      if result[:status]
        if expires > 0
          begin
            Rails.logger.warn "About to write fragment #{cache_key} #{result[:content].length()} bytes"
            write_fragment cache_key, result[:content], :expires_in => expires.seconds
            Rails.logger.debug "cache saved: #{cache_key}"
          rescue => detail
            Rails.logger.error "Failed to save cache: #{cache_key}, error: " + $!.to_s + detail.backtrace.join("\n")
	  end
	end
      else
        raise "Error applying external filter: stdout is #{result[:content]}, stderr is #{result[:errors]}"
      end
    end

    result[:name] = name
    result[:macro] = macro
    result[:content_types] = info['outputs'].map { |out| out['content_type'] }
    result[:template] = info['template']

    return result
  end

  def build_forced(text, attachments, info)

    if info['replace_attachments'] and attachments
      attachments.each do |att|
       if text
        text.gsub!(/#{att.filename.downcase}/i, att.diskfile)
       end
      end
    end

    result = {}
    content = []
    errors = ""

    info['outputs'].each do |out|
      Rails.logger.info "executing command: #{out['command']}"

      c = nil
      e = nil
   
      Rails.logger.warn "before cleanup, text is #{text}"

      if text && text != "[]"
        #
        #  the text we get at this point is really hosey, so clean it up
        #
        text.gsub!(/<br\s\/>/, "\n")
        text.gsub!(/<\/?strong>/, "*")
        text = CGI.unescapeHTML(text)
        text = text[2,text.length()-4]
        text.gsub!('", "',",")
        text.gsub!("\\r","\r")
        text.gsub!("\\n","\n")
        text.gsub!("\\\\","\\")
      end
      Rails.logger.warn "after eval, text is #{text}"

      # If popen4 is available - use it as it provides stderr
      # redirection so we can get more info in the case of error.
      begin
        require 'open4'

        Open4::popen4(out['command']) { |pid, fin, fout, ferr|
          fin.write out['prolog'] if out.key?('prolog')
          fin.write text
          fin.write out['epilog'] if out.key?('epilog')
          fin.close
          c, e = [fout.read, ferr.read]
        }
      rescue LoadError
        IO.popen(out['command'], 'r+b') { |f|
          f.write out['prolog'] if out.key?('prolog')
          f.write text
          f.write out['epilog'] if out.key?('epilog')
          f.close_write
          c = f.read
	}
      end

      Rails.logger.debug("child status: sig=#{$?.termsig}, exit=#{$?.exitstatus}")

      content << c.html_safe
      errors += e if e
    end

    result[:content] = content.join("")
    result[:errors] = errors
    result[:source] = text
    result[:status] = $?.exitstatus == 0

    return result
  end

  def render_tag(result)
    result = result.dup
    result[:render_type] = 'inline'
    html = render_common(result).chop
    html << headers_common(result).chop
    html
  end

  def render_block(result, wiki_name)
    result = result.dup
    result[:render_type] = 'block'
    result[:wiki_name] = wiki_name
    result[:inside] = render_common(result)
    html = render_to_string(:template => 'wiki_external_filter/block', :layout => false, :locals => result).chop.html_safe
    html << headers_common(result).chop
    html
  end

  def render_common(result)
    render_to_string :template => "wiki_external_filter/macro_#{result[:template]}", :layout => false, :locals => result
  end

  def headers_common(result)
    render_to_string :template => 'wiki_external_filter/headers', :layout => false, :locals => result
  end

  class Macro
    def initialize(view, source, attachments, macro, info)
      @view = view
      @view.controller.extend(WikiExternalFilterHelper)
      @result = @view.controller.build(source, attachments, macro, info)
    end

    def render()
      @view.controller.render_tag(@result).html_safe
    end

    def render_block(wiki_name)
      @view.controller.render_block(@result, wiki_name).html_safe
    end
  end
end
