require 'eslintrb'

module ZendeskAppsSupport
  module Validations
    module Source
      LINTER_OPTIONS = {
        rules: {
          # enforcing options:
          'semi' => 2,
          'no-extra-semi' => 2,
          'no-caller' => 2,
          'no-undef' => 2,

          # relaxing options:
          'no-unused-expressions' => 2,
          'no-redeclare' => 2,
          'no-eq-null' => 0,
          'comma-dangle' => 0,
          'dot-notation' => 0
        },
        env: {
          'browser' => true,
          'commonjs' => true
        },
        # predefined globals:
        globals: Hash[
          %w(_ Base64 services helpers moment)
        .map { |x| [x, false] }]
      }.freeze

      ENFORCED_LINTER_OPTIONS = {
        rules: {
          # enforcing options:
          'no-caller' => 2
        },
        env: {
          'browser' => true,
          'commonjs' => true
        },
        # predefined globals:
        globals: Hash[
          %w(_ Base64 services helpers moment)
        .map { |x| [x, false] }]
      }.freeze

      class <<self
        def call(package)
          files = package.js_files
          app   = files.find { |file| file.relative_path == 'app.js' }
          eslint_config_path = "#{package.root}/.eslintrc.json"
          has_eslint_config = File.exists?(eslint_config_path)
          options = has_eslint_config ? JSON.parse(File.read(eslint_config_path)) : LINTER_OPTIONS

          if package_needs_app_js?(package)
            return [ ValidationError.new(:missing_source) ] unless app
          else
            return (package_has_code?(package) ? [ ValidationError.new(:no_code_for_ifo_notemplate) ] : [])
          end

          errors = eslint_errors(files, options)
          errors << eslint_errors(files, ENFORCED_LINTER_OPTIONS) if errors.empty? && has_eslint_config
          return app ? errors.flatten! : [ValidationError.new(:missing_source)]
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

        def eslint_error(file, options)
          errors = Eslintrb.lint(file.read, options)
          [ESLintValidationError.new(file.relative_path, errors)] if errors.any?
        end

        def eslint_errors(files, options)
          files.each_with_object([]) do |file, errors|
            error = eslint_error(file, options)
            errors << error unless error.nil?
          end
        end
      end
    end
  end
end
