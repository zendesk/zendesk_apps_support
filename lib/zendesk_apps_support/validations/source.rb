require 'eslintrb'

module ZendeskAppsSupport
  module Validations
    module Source
      LINTER_OPTIONS = {
        rules: {
          # enforcing options:
          'no-caller' => 2,
          'no-undef' => 2,

          # relaxing options:
          'no-eq-null' => 0,
          'comma-dangle' => 0,
          'dot-notation' => 0
        },
        env: {
          'browser' => true
        },
        # predefined globals:
        globals: %w(_ console services helpers alert confirm window document self
                   JSON Base64 clearInterval clearTimeout setInterval setTimeout
                   require module exports top frames parent moment)
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
          return false if package.manifest_json['requirementsOnly']
          return false if package.iframe_only?
          true
        end

        def jshint_error(file)
          errors = Eslintrb.lint(file.read, LINTER_OPTIONS)
          [JSHintValidationError.new(file.relative_path, errors)] if errors.any?
        end

        def jshint_errors(files)
          files.each_with_object([]) do |file, errors|
            error = jshint_error(file)
            errors << error unless error.nil?
          end
        end
      end
    end
  end
end
