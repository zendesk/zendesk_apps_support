# frozen_string_literal: true
require 'jshintrb'

module ZendeskAppsSupport
  module Validations
    module Source
      LINTER_OPTIONS = {
        # enforcing options:
        noarg: true,
        undef: true,

        # relaxing options:
        eqnull: true,
        laxcomma: true,
        sub: true,

        # predefined globals:
        predef: %w(_ console services helpers alert confirm window document self
                   JSON Base64 clearInterval clearTimeout setInterval setTimeout
                   require module exports top frames parent moment),

        browser: true
      }.freeze

      class <<self
        def call(package)
          files = package.js_files
          app   = files.find { |file| file.relative_path == 'app.js' }

          if package_needs_app_js?(package)
            return [ ValidationError.new(:missing_source) ] unless app
          else
            return (package_has_code?(package) ? [ ValidationError.new(:no_code_for_ifo_notemplate) ] : [])
          end

          jshint_errors(files).flatten!
        end

        private

        def package_has_code?(package)
          !(package.js_files.empty? && package.template_files.empty? && package.app_css.empty?)
        end

        def package_needs_app_js?(package)
          return false if package.manifest.marketing_only?
          return false if package.manifest.requirements_only?
          return false if package.manifest.iframe_only?
          true
        end

        def jshint_error(file)
          errors = linter.lint(file.read)
          [JSHintValidationError.new(file.relative_path, errors)] if errors.any?
        end

        def jshint_errors(files)
          files.each_with_object([]) do |file, errors|
            error = jshint_error(file)
            errors << error unless error.nil?
          end
        end

        def linter
          Jshintrb::Lint.new(LINTER_OPTIONS)
        end
      end
    end
  end
end
