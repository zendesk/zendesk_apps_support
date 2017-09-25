# frozen_string_literal: true
require 'loofah'

module ZendeskAppsSupport
  module Validations
    module Svg
      class << self
        def call(package)
          errors = []
          package.svg_files.each do |svg|
            # ignore extra whitespace in SVGs
            markup = svg.read.gsub("\n", ' ').squeeze(' ')

            clean_markup = Loofah.scrub_xml_document(markup, :prune).to_html
            filepath = svg.relative_path

            # to ignore the optional XML declaration at the top of a document
            def strip_declaration(markup)
              Nokogiri::XML(markup).root.to_s
            end

            def are_equivalent_sans_declarations(clean_markup, markup)
              # skip the check if it isn't possible for the markup to contain a declaration
              return false unless Nokogiri::XML(markup).root.children.length >= 1
              strip_declaration(clean_markup) == strip_declaration(markup)
            end

            next if are_equivalent_sans_declarations(clean_markup, markup) || clean_markup == markup
            begin
              IO.write(filepath, clean_markup)
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
