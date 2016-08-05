# frozen_string_literal: true
module ZendeskAppsSupport
  class Manifest
    class << self
      def private_attr_reader(*names)
        private
        attr_reader(*names)
      end
    end
    attr_reader :requirements_only, :version, :author, :framework_version, :single_install,
                :signed_urls, :no_template, :default_locale, :original_location, :oauth, :parameters,
                :original_parameters
    private_attr_reader :original_locations
    LEGACY_URI_STUB = '_legacy'

    alias_method :requirements_only?, :requirements_only
    alias_method :signed_urls?, :signed_urls
    alias_method :single_install?, :single_install

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
          { 'zendesk' => Hash[original_locations.map { |location| [ location, LEGACY_URI_STUB ] }] }
        when String
          { 'zendesk' => { original_locations => LEGACY_URI_STUB } }
        else # NilClass
          { 'zendesk' => {} }
        end
    end

    def iframe_only?
      product_names = locations.keys
      return false if product_names.any? { |name| !%w(zendesk support).include? name }
      iframe_urls = locations.values.flat_map(&:values)
      iframe_urls.any? { |url| url != LEGACY_URI_STUB }
    end

    def initialize(m)
      @requirements_only = m['requirementsOnly']
      @version = m['version']
      @author = m['author']
      @framework_version = m['frameworkVersion']
      @single_install = m['singleInstall'] || false
      @signed_urls = m['signedUrls'] || false
      @no_template = m['noTemplate'] || false
      @default_locale = m['defaultLocale']
      @original_locations = m['location']
      @oauth = m['oauth']
      @original_parameters = m['parameters']
      parameter_array = @original_parameters.is_a?(Array) ? @original_parameters : []
      @parameters = parameter_array.map do |parameter_hash|
        Parameter.new(parameter_hash)
      end
    end
  end
end
