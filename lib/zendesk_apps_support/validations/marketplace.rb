# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module Marketplace
      WHITELISTED_EXPERIMENTS = %w[hashParams newCssCompiler].freeze

      class << self
        def call(package)
          [no_symlinks(package.root), *no_experiments(package.manifest)].compact
        end

        private

        def no_symlinks(path)
          if Dir["#{path}/**/{*,.*}"].any? { |f| File.symlink?(f) }
            return ValidationError.new(:symlink_in_zip)
          end
          nil
        end

        def no_experiments(manifest)
          invalid_experiments = manifest.enabled_experiments - WHITELISTED_EXPERIMENTS
          invalid_experiments.map do |experiment|
            ValidationError.new(:invalid_experiment, experiment: experiment)
          end
        end
      end
    end
  end
end
