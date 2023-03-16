# frozen_string_literal: true

require 'loofah'

module ZendeskAppsSupport
  module Validations
    module Svg
      PLACEHOLDER_SVG_MARKUP = File.read(File.expand_path('../../assets/default_app_logo.svg', __FILE__))

      # whitelist elements and attributes used in Zendesk Garden assets
      Loofah::HTML5::SafeList::ALLOWED_ELEMENTS_WITH_LIBXML2.add 'symbol'
      Loofah::HTML5::SafeList::ACCEPTABLE_CSS_PROPERTIES.add 'position'

      # CRUFT: ignore a (very specific) style attribute which Loofah would otherwise scrub.
      # This attribute is deprecated (https://www.w3.org/TR/filter-effects/#AccessBackgroundImage)
      # but is included in many of the test apps used in fixtures for tests in ZAM, ZAT etc.
      Loofah::HTML5::SafeList::ACCEPTABLE_CSS_PROPERTIES.add 'enable-background'

      @strip_declaration = Loofah::Scrubber.new do |node|
        node.remove if node.name == 'xml' && node.children.empty?
      end

      # Loofah's default scrubber strips spaces between CSS attributes. Passing the input markup through this scrubber
      # first ensures that this stripped whitespace in the output doesn't register as a diff.
      @strip_spaces_between_css_attrs = Loofah::Scrubber.new do |node|
        match_pattern = Regexp.new(/\;\s+/)
        if node.name == 'svg' && node['style']
          node['style'] = node['style'].gsub(match_pattern, ';')
        end
      end

      @empty_malformed_markup = Loofah::Scrubber.new do |node|
        node.next.remove while node.name == 'svg' && node.next
      end

      class << self
        def contains_embedded_bitmap?(markup)
          Nokogiri::XML(markup).css('//image').any?
        end

        def rewrite_svg(svg, new_markup, package, errors)
          warning_string = if contains_embedded_bitmap?(svg.read)
                             'txt.apps.admin.warning.app_build.bitmap_in_svg'
                           else
                             'txt.apps.admin.warning.app_build.sanitised_svg'
                           end

          package.warnings << I18n.t(warning_string, svg: svg.relative_path)
          compressed_new_markup = new_markup.tr("\n", '').squeeze(' ').gsub(/\>\s+\</, '><')
          IO.write(svg.absolute_path, compressed_new_markup)
        rescue
          errors << ValidationError.new(:dirty_svg, svg: svg.relative_path)
        end

        def call(package)
          errors = []

          package.svg_files.each do |svg|
            if contains_embedded_bitmap?(svg.read)
              rewrite_svg(svg, PLACEHOLDER_SVG_MARKUP, package, errors)
            else
              markup = Loofah.xml_fragment(svg.read)
                             .scrub!(@strip_declaration)
                             .scrub!(@strip_spaces_between_css_attrs)
                             .to_xml.strip

              clean_markup = Loofah.xml_fragment(markup)
                                   .scrub!(:prune)
                                   .scrub!(@empty_malformed_markup)
                                   .to_xml

              next if clean_markup == markup
              rewrite_svg(svg, clean_markup, package, errors)
            end
          end
          errors
        end
      end
    end
  end
end
