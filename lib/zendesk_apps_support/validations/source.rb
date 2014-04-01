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

        # predefined globals:
        :predef => %w(_ console services helpers alert JSON Base64 clearInterval clearTimeout setInterval setTimeout require module)
      }.freeze

      class <<self
        def call(package)
          source = package.files.find { |f| f.relative_path == 'app.js' }

          if package.requirements_only
            return source ? [ ValidationError.new(:no_app_js_required) ] : []
          end

          return [ ValidationError.new(:missing_source) ] unless source

          jshint_errors = []
          app_js_errors = linter.lint(source.read)
          if app_js_errors.any?
            jshint_errors += [ JSHintValidationError.new(source.relative_path, app_js_errors) ]
          end
          Dir["#{package.root}/lib/**/*.js"].each do |file|
            lib_js_errors = linter.lint(File.read(file))
            if lib_js_errors.any?
              jshint_errors += [ JSHintValidationError.new(Pathname.new(file).relative_path_from(package.root), lib_js_errors) ]
            end
          end
          jshint_errors
        end

        private

        def linter
          Jshintrb::Lint.new(LINTER_OPTIONS)
        end

      end
    end
  end
end
