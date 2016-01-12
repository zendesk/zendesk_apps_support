require 'eslintrb'

module ZendeskAppsSupport
  module Validations
    module Source
      LINTER_OPTIONS = {
        rules: {
          # enforcing options:
          'semi' => 2,
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
        globals: Hash[
          %w(_ Base64 services helpers require module exports moment)
        .map { |x| [x, 'true'] }]
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

          return app ? eslint_errors(files).flatten! : [ValidationError.new(:missing_source)]
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

        def eslint_error(file)
          errors = Eslintrb.lint(file.read, LINTER_OPTIONS)
          [ESLintValidationError.new(file.relative_path, errors)] if errors.any?
        end

        def eslint_errors(files)
          files.each_with_object([]) do |file, errors|
            error = eslint_error(file)
            errors << error unless error.nil?
          end
        end
      end
    end
  end
end
