# frozen_string_literal: true
require 'loofah'

module ZendeskAppsSupport
  module Validations
    module Svg
      @strip_declaration = Loofah::Scrubber.new do |node|
        node.remove if node.name == 'xml' && node.children.empty?
      end

      @empty_malformed_markup = Loofah::Scrubber.new do |node|
        node.next.remove while node.name == 'svg' && node.next
      end

      # CRUFT: ignore a (very specific) style attribute which Loofah would otherwise scrub.
      # This attribute is deprecated (https://www.w3.org/TR/filter-effects/#AccessBackgroundImage)
      # but is included in many of the test apps used in fixtures for tests in ZAM, ZAT etc.
      @remove_enable_background = Loofah::Scrubber.new do |node|
        match_pattern = Regexp.new("enable-background:.*?(\;|\z)")
        if node.name == 'svg' && node['style']
          node['style'] = node['style'].gsub(match_pattern, '')
          node.attributes['style'].remove if node['style'].empty?
        end
      end

      class << self
        def call(package)
          errors = []

          package.svg_files.each do |svg|
            markup = Loofah.xml_fragment(svg.read)
                           .scrub!(@strip_declaration)
                           .scrub!(@remove_enable_background)
                           .to_xml

            clean_markup = Loofah.xml_fragment(markup)
                                 .scrub!(:prune)
                                 .scrub!(@empty_malformed_markup)
                                 .to_xml

            filepath = svg.relative_path

            next if clean_markup == markup
            begin
              compressed_clean_markup = clean_markup.tr("\n", '').squeeze(' ').gsub(/\>\s+\</, '><')
              IO.write(filepath, compressed_clean_markup)
              package.warnings << I18n.t('txt.apps.admin.warning.app_build.sanitised_svg', svg: filepath)
            rescue
              errors << ValidationError.new(:dirty_svg, svg: filepath)
            end
          end
          errors
        end
      end
    end
  end
end
