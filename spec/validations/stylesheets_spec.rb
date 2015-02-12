require 'spec_helper'

describe ZendeskAppsSupport::Validations::Stylesheets do
  it 'does not return errors if there is no custom css' do
    package = double(customer_css: '')
    expect(ZendeskAppsSupport::Validations::Stylesheets.call(package)).to be_empty
  end

  it 'does not return errors for valid css' do
    valid_css = <<-CSS
.my-class {
  border: solid 1px black;
}
    CSS
    package = double(customer_css: valid_css)

    errors = ZendeskAppsSupport::Validations::Stylesheets.call(package)
    expect(errors).to be_empty
  end

  it 'returns style sheet validation error for invalid css' do
    invalid_css = <<-CSS
.my-class {
  border: }
}
    CSS
    package = double(customer_css: invalid_css)

    errors = ZendeskAppsSupport::Validations::Stylesheets.call(package)
    expect(errors.count).to eq(1)
    expect(errors.first.to_s).to match(/Sass error: Invalid CSS after.*/)
  end
end
