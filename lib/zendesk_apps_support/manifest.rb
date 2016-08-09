# frozen_string_literal: true
module ZendeskAppsSupport
  class Manifest
    class << self
      def private_attr_reader(*names)
        private
        attr_reader(*names)
      end
    end

    LEGACY_URI_STUB = '_legacy'

    RUBY_TO_JSON = {
      name: 'name',
      requirements_only: 'requirementsOnly',
      version: 'version',
      author: 'author',
      framework_version: 'frameworkVersion',
      single_install: 'singleInstall',
      signed_urls: 'signedUrls',
      no_template: 'noTemplate',
      default_locale: 'defaultLocale',
      original_locations: 'location',
      private: 'private',
      oauth: 'oauth',
      original_parameters: 'parameters',
      domain_whitelist: 'domainWhitelist',
      remote_installation_url: 'remoteInstallationURL',
      terms_conditions_url: 'termsConditionsURL',
      google_analytics_code: 'gaID'
    }

    attr_reader(*RUBY_TO_JSON.keys)

    alias_method :requirements_only?, :requirements_only
    alias_method :signed_urls?, :signed_urls
    alias_method :single_install?, :single_install
    alias_method :private?, :private

    def no_template?
      if no_template.is_a?(Array)
        false
      else
        no_template
      end
    end

    def no_template_locations
      no_template || []
    end

    def location?
      locations != { 'zendesk' => {} }
    end

    def locations
      @locations ||=
        case original_locations
        when Hash
          original_locations
        when Array
          { 'zendesk' => NoOverrideHash[original_locations.map { |location| [ location, LEGACY_URI_STUB ] }] }
        when String
          { 'zendesk' => { original_locations => LEGACY_URI_STUB } }
        # TODO: error out for numbers and Booleans
        else # NilClass
          { 'zendesk' => {} }
        end
    end

    def iframe_only?
      product_names = locations.keys
      # if the app is not for Zendesk / Support, it must be iframe only
      return true if product_names.any? { |name| !%w(zendesk support).include? name }
      iframe_urls = locations.values.flat_map(&:values)
      iframe_urls.any? { |url| url != LEGACY_URI_STUB }
    end

    def parameters
      @parameters ||= begin
        parameter_array = @original_parameters.is_a?(Array) ? @original_parameters : []
        parameter_array.map do |parameter_hash|
          Parameter.new(parameter_hash)
        end
      end
    end

    def initialize(manifest_text)
      m = parse_json(manifest_text)
      RUBY_TO_JSON.each do |ruby, json|
        instance_variable_set(:"@#{ruby}", m[json])
      end
      @single_install ||= false
      @private = m.fetch('private', true)
      @signed_urls ||= false
      @no_template ||= false
    end

    private

    def parse_json(manifest_text)
      parser_opts = { object_class: Manifest::NoOverrideHash }
      JSON.parse(manifest_text, parser_opts)
    end
  end
end
