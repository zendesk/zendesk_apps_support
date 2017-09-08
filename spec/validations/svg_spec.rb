# frozen_string_literal: true
require 'spec_helper'

describe ZendeskAppsSupport::Validations::Svg do
  let(:markup) { "<svg viewBox=\"0 0 26 26\" id=\"zd-svg-icon-26-app\" width=\"100%\" height=\"100%\"><path fill=\"none\" stroke=\"currentColor\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 5l9-5m-9 5v10\"></path></svg>\n" }
  let(:svg) { double('AppFile', relative_path: 'assets/icon_nav_bar.svg', read: markup) }
  let(:package) { double('Package', svg_files: [svg], warnings: []) }

  it 'makes no changes when the files contain well-formed, clean markup' do
    errors = ZendeskAppsSupport::Validations::Svg.call(package)
    expect(package.warnings).to be_empty
    expect(errors).to be_empty
  end

  # it 'sanitises questionable markup and notifies the user that their offending svgs were changed' do
    # let(:markup) { } # dirty markup
  # end

  # it 'raises an error when a file contains questionable markup and sanitisation fails' do
    # let(:markup) { } # erroneous markup
  # end
end
