# frozen_string_literal: true
require 'loofah'

module ZendeskAppsSupport
  module Validations
    module Svg
      class << self
        def call(package)
          errors = []
          package.svg_files.each do |svg|
            markup = Nokogiri::XML(svg.read).to_s.
                     # ignore extra whitespace in SVGs
                     tr("\n", '').squeeze(' ').gsub(/\>\s+\</, '><')

            clean_markup = Loofah.scrub_xml_document(markup, :prune).to_html
            filepath = svg.relative_path

            next if are_equivalent(clean_markup, markup) || clean_markup == markup
            begin
              IO.write(filepath, clean_markup)
              package.warnings << I18n.t('txt.apps.admin.warning.app_build.sanitised_svg', svg: filepath)
            rescue
              errors << ValidationError.new(:dirty_svg, svg: filepath)
            end
          end
          errors
        end

        private

        WHITELISTED_ATTRS = [ # ignore the following attributes when evaluating equivalent XML
          # CRUFT: ignore a (very specific) style attribute which Loofah would otherwise scrub.
          # This attribute is deprecated (https://www.w3.org/TR/filter-effects/#AccessBackgroundImage)
          # but is included in many of the test apps used in fixtures for tests in ZAM, ZAT etc.
          '//svg/@style:enable-background'
        ].freeze

        # to ignore the optional XML declaration at the top of a document
        def strip_declaration(markup_doc)
          markup_doc.root.to_s
        end

        def are_equivalent(clean_markup, markup)
          # strip namespaces initially here as it makes searching the document easier,
          # see: http://www.nokogiri.org/tutorials/searching_a_xml_html_document.html
          filtered_markup_doc = Nokogiri::XML(markup).remove_namespaces!

          WHITELISTED_ATTRS.map do |attr|
            attr_path = attr.split(':')[0]
            attr_prop = attr.split(':')[1]

            next if filtered_markup_doc.xpath(attr_path).empty?
            attr_value = filtered_markup_doc.xpath(attr_path).first.value

            # move to next attribute if this property can simply be removed
            if attr_value == attr_prop
              filtered_markup_doc.xpath(attr_path).first.remove
              next
            end

            match_pattern = Regexp.new(attr_prop + ":.*?(\;|\z)")
            clean_attr = attr_value.gsub(match_pattern, '')

            # depending on its contents, strip either the offending property in the attribute, or the entire attribute
            if clean_attr.empty?
              filtered_markup_doc.xpath(attr_path).first.remove
            else
              filtered_markup_doc.xpath(attr_path).first.value = clean_attr
            end
          end

          # skip the check if it isn't possible for the markup to contain a declaration
          return false unless filtered_markup_doc.root.children.length >= 1

          # check equivalence, ignoring leading declarations
          strip_declaration(Nokogiri::XML(clean_markup).remove_namespaces!) == strip_declaration(filtered_markup_doc)
        end
      end
    end
  end
end
