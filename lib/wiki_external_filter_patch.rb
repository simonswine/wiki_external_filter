require 'digest/md5'

module Redmine
  module WikiFormatting

  MACROS_RE = /
    (!)?                        # escaping
    (\{\{                        # opening tag
    ([\w]+)                     # macro name
    (\((.*?)\))?                # optional arguments
    \}\}                        # closing tag
    )
  /xm unless const_defined?(:MACROS_RE)

    class << self

      def to_html_with_external_filter(format, text, options={})
        text, @@macros_grabbed = preprocess_macros(text)
        to_html_without_external_filter(format, text, options)
      end

      def preprocess_macros(text)
        macros_grabbed = {}
        text = text.gsub(MACROS_RE) do |s|
          esc, all, macro = $1, $2, $3.downcase
          if esc.nil? and (WikiExternalFilterHelper.has_macro macro rescue false)
            args = $5.chomp
            key = ["#{macro}:#{args}"].pack('m').gsub(/\n/,'')
            "{{_macros_grabbed(#{key})}}"
          else
            s
          end
        end
        [text, macros_grabbed]
      end

      alias_method_chain :to_html, :external_filter
    end

  end
end

module Redmine::WikiFormatting::Macros::Definitions
  def exec_macro_with_macros_grabbed(name, obj, args, text)
    if name =~ /_macros_grabbed/
      args[0].unpack('m')[0] =~ /([^:]+):(.*)/m
      name,args = [$1,$2]
    end
    exec_macro_without_macros_grabbed(name, obj, args, text)
  end
  alias_method_chain :exec_macro, :macros_grabbed
end
