# frozen_string_literal: true
require 'loofah'

module ZendeskAppsSupport
  module Validations
    module Svg
      PLACEHOLDER_SVG_MARKUP = %(<?xml version="1.0" encoding="utf-8"?><svg version="1.1" id="Layer_1" \
xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 18 18" \
style="enable-background:new 0 0 18 18;" xml:space="preserve"><path id="Fill-3" d="M1.5,6.1C1.3,5.9,1,6,1,6.4l0,7c0,\
0.3,0.2,0.7,0.5,0.9l6,3.6C7.8,18.1,8,18,8,17.6l0-7.1c0-0.3-0.2-0.7-0.5-0.9L1.5,6.1z"/><path id="Fill-5" \
d="M10.5,17.9c-0.3,0.2-0.5,0-0.5-0.3l0-7c0-0.3,0.2-0.7,0.5-0.9l6-3.6C16.8,5.9,17,6,17,6.4l0,7.1c0,0.3-0.2,0.7-0.5,\
0.9L10.5,17.9z"/><path id="Fill-1" d="M2.2,3.7c-0.3,0.2-0.3,0.4,0,0.6l6.2,3.6C8.7,8,9.2,8,9.4,7.9l6.3-3.6c0.3-0.2,0.3-\
0.4,0-0.6L9.5,0.1C9.2,0,8.8,0,8.5,0.1L2.2,3.7z"/></svg>)

      # whitelist elements and attributes used in Zendesk Garden assets
      Loofah::HTML5::WhiteList::ALLOWED_ELEMENTS_WITH_LIBXML2.add 'symbol'
      Loofah::HTML5::WhiteList::ACCEPTABLE_CSS_PROPERTIES.add 'position'

      # CRUFT: ignore a (very specific) style attribute which Loofah would otherwise scrub.
      # This attribute is deprecated (https://www.w3.org/TR/filter-effects/#AccessBackgroundImage)
      # but is included in many of the test apps used in fixtures for tests in ZAM, ZAT etc.
      Loofah::HTML5::WhiteList::ACCEPTABLE_CSS_PROPERTIES.add 'enable-background'

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
          Nokogiri::XML(markup).css('image').any?
        end

        def rewrite_svg(svg, new_markup, package, errors)
          warning_string = if contains_embedded_bitmap?(svg.read)
                             'txt.apps.admin.warning.app_build.bitmap_in_svg'
                           else
                             'txt.apps.admin.warning.app_build.sanitised_svg'
                           end

          package.warnings << I18n.t(warning_string, svg: svg.relative_path)
          IO.write(svg.absolute_path, new_markup)
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
              compressed_clean_markup = clean_markup.tr("\n", '').squeeze(' ').gsub(/\>\s+\</, '><')
              rewrite_svg(svg, compressed_clean_markup, package, errors)
            end
          end
          errors
        end
      end
    end
  end
end
