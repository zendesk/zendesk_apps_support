require 'jshintrb'

module ZendeskAppsSupport
  module Validations
    module Source

      LINTER_OPTIONS = {
        # enforcing options:
        :noarg => true,
        :undef => true,

        # relaxing options:
        :eqnull => true,
        :laxcomma => true,
        :sub => true,

        # predefined globals:
        :predef => %w(_ console services helpers alert window document self
                      JSON Base64 clearInterval clearTimeout setInterval setTimeout
                      require module exports top frames parent)
      }.freeze

      class <<self
        def call(package)
          app   = package.files.find { |file| file.relative_path == 'app.js' }
          files = package.lib_files << app

          if package.requirements_only
            return app ? [ ValidationError.new(:no_app_js_required) ] : []
          end

          return [ ValidationError.new(:missing_source) ] unless app

          jshint_errors(files).flatten!
        end

        private

        def jshint_error(file)
          errors = linter.lint(file.read)
          [ JSHintValidationError.new(file.relative_path, errors) ] if errors.any?
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
