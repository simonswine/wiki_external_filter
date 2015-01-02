
class WikiExternalFilterController < ApplicationController
  unloadable

  include WikiExternalFilterHelper

  def filter
    name = params[:name]
    macro = params[:macro]
    index = params[:index].to_i
    filename = params[:filename] ? params[:filename] : name
    config = load_config
    cache_key = self.construct_cache_key(macro, name)
    begin 
       content = read_fragment cache_key
    rescue => detail
        Rails.logger.error "Failed to load cache: #{cache_key}, error: " + $!.to_s + detail.backtrace.join("\n")
    end

    if (content)
      send_data content, :type => config[macro]['outputs'][index]['content_type'], :disposition => 'inline', :filename => filename
    else
      render_404
    end
  end
end
