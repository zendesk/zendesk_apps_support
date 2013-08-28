require 'zendesk_apps_support'

describe ZendeskAppsSupport::AppVersion do

  describe 'the current version' do
    subject do
      ZendeskAppsSupport::AppVersion.new(ZendeskAppsSupport::AppVersion::CURRENT)
    end

    it { should be_frozen }
    it { should be_present }
    it { should be_servable }
    it { should be_valid_for_update }
    it { should_not be_blank }
    it { should_not be_deprecated }
    it { should_not be_obsolete }
    it { should == ZendeskAppsSupport::AppVersion.new(ZendeskAppsSupport::AppVersion::CURRENT) }
    it { should_not == ZendeskAppsSupport::AppVersion.new('0.2') }

    its(:to_s) { should == ZendeskAppsSupport::AppVersion::CURRENT }
    its(:to_json) { should == MultiJson.encode(ZendeskAppsSupport::AppVersion::CURRENT) }
  end

  describe 'the deprecated version' do
    subject do
      ZendeskAppsSupport::AppVersion.new(ZendeskAppsSupport::AppVersion::DEPRECATED)
    end

    it { should be_frozen }
    it { should be_present }
    it { should be_servable }
    it { should_not be_valid_for_update }
    it { should_not be_blank }
    it { should be_deprecated }
    it { should_not be_obsolete }
    it { should == ZendeskAppsSupport::AppVersion.new(ZendeskAppsSupport::AppVersion::DEPRECATED) }
    it { should_not == ZendeskAppsSupport::AppVersion.new('0.2') }

    its(:to_s) { should == ZendeskAppsSupport::AppVersion::DEPRECATED }
    its(:to_json) { should == MultiJson.encode(ZendeskAppsSupport::AppVersion::DEPRECATED) }
  end

  describe 'a really old version' do
    subject do
      ZendeskAppsSupport::AppVersion.new('0.1')
    end

    it { should be_frozen }
    it { should be_present }
    it { should_not be_servable }
    it { should_not be_valid_for_update }
    it { should_not be_blank }
    it { should_not be_deprecated }
    it { should be_obsolete }
    it { should == ZendeskAppsSupport::AppVersion.new('0.1') }
    it { should_not == ZendeskAppsSupport::AppVersion.new('0.2') }

    its(:to_s) { should == '0.1' }
    its(:to_json) { should == MultiJson.encode('0.1') }
  end
end