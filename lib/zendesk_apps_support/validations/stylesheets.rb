# frozen_string_literal: true

require 'zendesk_apps_support/stylesheet_compiler'

module ZendeskAppsSupport
  module Validations
    module Stylesheets
      class << self
        def call(package)
          css_error = validate_styles(package.app_css)
          css_error ? [css_error] : []
        end

        private

        def validate_styles(css)
          compiler = ZendeskAppsSupport::StylesheetCompiler.new(css, nil, nil)
          begin
            compiler.compile
          rescue SassC::SyntaxError, Sass::SyntaxError => e
            return ValidationError.new(:stylesheet_error, sass_error: e.message)
          end
          nil
        end
      end
    end
  end
end
