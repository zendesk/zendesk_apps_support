# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module Source
      class << self
        def call(package)
          if app_doesnt_require_source?(package.manifest) && contain_source_files?(package)
            ValidationError.new(:no_code_for_ifo_notemplate)
          end
        end

        private

        def contain_source_files?(package)
          package.js_files.any? || package.template_files.any? || !package.app_css.empty?
        end

        def app_doesnt_require_source?(manifest)
          manifest.requirements_only? || manifest.marketing_only?
        end
      end
    end
  end
end
