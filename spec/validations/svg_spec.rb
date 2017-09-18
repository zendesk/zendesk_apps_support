# frozen_string_literal: true
require 'spec_helper'

describe ZendeskAppsSupport::Validations::Svg do
  let(:clean_markup) do
    %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><path fill="none" \
stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 \
5l9-5m-9 5v10"></path></svg>\n)
  end
  let(:svg) { double('AppFile', relative_path: 'assets/icon_nav_bar.svg', read: markup) }
  let(:package) { double('Package', svg_files: [svg], warnings: []) }
  let(:warning) do
    'The markup in assets/icon_nav_bar.svg has been edited for use in Zendesk, and may not display as intended.'
  end

  before do
    allow(IO).to receive(:write)
  end

  context 'clean markup' do
    let(:markup) { clean_markup }

    it 'leaves the original svg files unchanged when they contain well-formed, clean markup' do
      errors = ZendeskAppsSupport::Validations::Svg.call(package)
      expect(IO).not_to have_received(:write)
      expect(package.warnings).to be_empty
      expect(errors).to be_empty
    end
  end

  context 'non-suspicious but superfluous markup' do
    superfluous_markup = [
      # markup containing a leading XML declaration
      %(<?xml version="1.0" encoding="utf-8"?>
<svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" \
y="0px"
   viewBox="0 0 18 18" xml:space="preserve">
<path id="Fill-3" d="M1.5,6.1C1.3,5.9,1,6,1,6.4l0,7c0,0.3,0.2,0.7,0.5,0.9l6,3.6C7.8,18.1,8,18,8,\
17.6l0-7.1c0-0.3-0.2-0.7-0.5-0.9
  L1.5,6.1z"/>
<path id="Fill-5" d="M10.5,17.9c-0.3,0.2-0.5,0-0.5-0.3l0-7c0-0.3,0.2-0.7,0.5-0.9l6-3.6C16.8,5.9,17,6,17,6.4l0,7.1
  c0,0.3-0.2,0.7-0.5,0.9L10.5,17.9z"/>
<path id="Fill-1" d="M2.2,3.7c-0.3,0.2-0.3,0.4,0,0.6l6.2,3.6C8.7,8,9.2,8,9.4,7.9l6.3-3.6c0.3-0.2,0.3-0.4,0-0.6L9.5,0.1
  C9.2,0,8.8,0,8.5,0.1L2.2,3.7z"/>
</svg>),
      # markup containing a doctype
      %(<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" \
y="0px"
   width="14px" height="11px" viewBox="-1 -1 14 11" xml:space="preserve">
<path d="M11.7,0.3C11.4,0.1,11.1,0,10.8,0c-0.3,0-0.6,0.1-0.8,0.2l0,0l-5.8,6L1.9,3.9C1.7,3.7,1.4,3.6,1.1,3.6S0.6,3.7,\
0.3,3.9
  C0.1,4.1,0,4.4,0,4.7C0,5,0.1,5.3,0.3,5.5l3.1,3.2C3.8,9,4.1,9,4.2,9C4.6,9,4.9,8.9,5,8.7l6.6-6.7C12.1,1.5,12.1,0.8,\
  11.7,0.3z"
  fill="#78a300" />
</svg>)
    ]

    superfluous_markup.map do |markup|
      let(:markup) { markup }
      it 'leaves the original svg files unchanged when they contain some superfluous but otherwise clean markup' do
        errors = ZendeskAppsSupport::Validations::Svg.call(package)
        expect(IO).not_to have_received(:write)
        expect(package.warnings).to be_empty
        expect(errors).to be_empty
      end
    end
  end

  context 'dirty markup' do
    dirty_markup_examples = [
      %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><path fill="none" \
stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 \
5l9-5m-9 5v10" onclick="alert(1)"></path></svg>\n),
      %(<svg onload=alert&#x28;1&#x29 viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"> \
<path fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 \
23l-9-5.2zm9 5L4 8m9 5l9-5m-9 5v10"></path></svg>\n),
      %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><path fill="none" \
stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 \
5l9-5m-9 5v10"><script type="text/javascript">alert(1);</script></path></svg>\n),
      %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><script>//&NewLine;confirm(1); \
</script <path fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 \
5v9.7L13 23l-9-5.2zm9 5L4 8m9 5l9-5m-9 5v10"></path></svg>\n)
    ]

    dirty_markup_examples.map do |markup|
      let(:markup) { markup }
      it 'sanitises questionable markup and notifies the user that the offending svgs were modified' do
        errors = ZendeskAppsSupport::Validations::Svg.call(package)
        expect(IO).to have_received(:write).with(svg.relative_path, clean_markup)
        expect(package.warnings[0]).to eq(warning)
        expect(errors).to be_empty
      end
    end
  end

  context 'malformed, suspicious markup' do
    malformed_markup_examples = [
      %(<svg onload=innerHTML=location.hash>#<script>alert(1)</script> viewBox="0 0 26 26" id="zd-svg-icon-26-app" \
width="100%" height="100%"><path fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" \
d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 5l9-5m-9 5v10"><script type="text/javascript">alert('XSS');</script> \
      </path></svg>\n),
      %(<svg onResize svg onResize="javascript:javascript:alert(1)" viewBox="0 0 26 26" id="zd-svg-icon-26-app" \
width="100%" height="100%"><path fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" \
d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 5l9-5m-9 5v10"></path></svg onResize>\n)
    ]

    malformed_markup_examples.map do |markup|
      let(:markup) { markup }
      let(:empty_svg) { %(<svg></svg>\n) }

      it 'empties the contents of malformed suspicious svg tags and notifies the user that the offending svgs were \
      modified' do
        errors = ZendeskAppsSupport::Validations::Svg.call(package)
        expect(IO).to have_received(:write).with(svg.relative_path, empty_svg)
        expect(package.warnings[0]).to eq(warning)
        expect(errors).to be_empty
      end
    end
  end

  context 'read-only error' do
    let(:markup) do
      %(<svg viewBox="0 0 26 26" id="zd-svg-icon-26-app" width="100%" height="100%"><path fill="none" \
stroke="currentColor" stroke-linejoin="round" stroke-width="2" d="M4 8l9-5 9 5v9.7L13 23l-9-5.2zm9 5L4 8m9 \
5l9-5m-9 5v10" onclick="alert(1)"></path></svg>\n)
    end

    before do
      allow(IO).to receive(:write).and_raise('Failed to write to original file')
    end

    it 'raises an error when a file contains questionable markup but it fails to be overwritten' do
      errors = ZendeskAppsSupport::Validations::Svg.call(package)
      expect(errors.size).to eq(1)
      expect(errors[0].key).to eq(:dirty_svg)
      expect(errors[0].data).to eq(svg: svg.relative_path)
    end
  end
end
