require 'digest/md5'

module ApplicationHelper
  MACROS_RE = /
    (!)?                        # escaping
    (\{\{                        # opening tag
    ([\w]+)                     # macro name
    (\((.*?)\))?                # optional arguments
    \}\}                        # closing tag
    )
  /xm unless const_defined?(:MACROS_RE)
end

module Redmine
  module WikiFormatting
    class << self
      include ApplicationHelper
      def to_html_with_external_filter(format, text, options={})
        text, @@macros_grabbed = preprocess_macros(text)
        to_html_without_external_filter(format, text, options)
      end

      def preprocess_macros(text)
        macros_grabbed = {}
        text = text.gsub(MACROS_RE) do |s|
          esc, all, macro = $1, $2, $3.downcase
          if esc.nil? and (WikiExternalFilterHelper.has_macro macro rescue false)
            args = $5
            key = Digest::MD5.hexdigest("#{macro}:#{args}")
            macros_grabbed[key] = {:macro => macro, :args => args}
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
  def exec_macro_with_macros_grabbed(name, obj, args)
    exec_macro_without_macros_grabbed(name, obj, args)
  end
  alias_method_chain :exec_macro, :macros_grabbed
end
