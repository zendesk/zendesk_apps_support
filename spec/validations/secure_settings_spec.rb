# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

describe ZendeskAppsSupport::Validations::SecureSettings do
  def create_package(parameter_hash)
    dir = Dir.mktmpdir
    package = ZendeskAppsSupport::Package.new(dir, false)
    allow(package).to receive(:manifest).and_return(ZendeskAppsSupport::Manifest.new(parameter_hash.to_json))
    package
  end

  context 'when scopes validations are enforced' do
    context 'when default manifest parameters are not secure or hidden' do
      it 'returns no warning' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'subdomain',
              'type' => 'text',
              'secure' => false
            },
            {
              'name' => 'subdomain2',
              'type' => 'text',
              'secure' => false,
              'default' => 'mysubdomain'
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)

        expect(package.warnings).to be_empty
      end
    end

    context 'when default manifest parameters are secure' do
      it 'returns a warning' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'secured_default_subdomain',
              'type' => 'text',
              'secure' => true,
              'default' => 'mysubdomain'
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)
        expect(package.warnings.size).to eq(2)
        expect(package.warnings[0]).to include('confirm they do not contain sensitive data')
        expect(package.warnings[1]).to include(
          'The scopes property is not configured for parameter(s): secured_default_subdomain. This may cause token exposure vulnerabilities. Learn about:'
        )
      end
    end

    context 'when default manifest parameters are hidden' do
      it 'returns a warning' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'default_subdomain',
              'type' => 'hidden',
              'default' => 'mysubdomain'
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)

        expect(package.warnings.size).to eq(1)
        expect(package.warnings[0]).to include('confirm they do not contain sensitive data')
      end
    end

    context 'when manifest parameters do not contain SECURABLE_KEYWORDS' do
      it 'returns no warning' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'subdomain',
              'type' => 'text'
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)

        expect(package.warnings).to be_empty
      end
    end

    context 'when manifest parameters contain SECURABLE_KEYWORDS' do
      it 'returns a warning if secure key is false/undefined' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'my_token',
              'type' => 'text'
            },
            {
              'name' => 'subdomain',
              'type' => 'text'
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)

        expect(package.warnings.size).to eq(1)
        expect(package.warnings[0]).to include('Make sure to set secure to true')
      end

      it 'returns warning for secured, insecured, default parameters' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'my_token',
              'secure' => true,
              'type' => 'text'
            },
            {
              'name' => 'oauth_token',
              'secure' => true,
              'type' => 'text'
            },
            {
              'name' => 'token_with_scopes',
              'secure' => true,
              'type' => 'text',
              'scopes' => ['header']
            },
            {
              'name' => 'my_token',
              'type' => 'text'
            },
            {
              'name' => 'subdomain',
              'type' => 'text'
            },
            {
              'name' => 'default_subdomain',
              'type' => 'text',
              'default' => 'mysubdomain'
            },
            {
              'name' => 'secured_default_subdomain',
              'secure' => true,
              'type' => 'text',
              'default' => 'mysubdomain'
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)

        expect(package.warnings.size).to eq(3)
        expect(package.warnings[0]).to include('Make sure to set secure to true when using keys in Settings')
        expect(package.warnings[1]).to include('Default values for secure or hidden parameters are not stored securely')
        expect(package.warnings[2]).to include(
          'The scopes property is not configured for parameter(s): my_token, oauth_token, secured_default_subdomain. This may cause token exposure vulnerabilities. Learn about:'
        )
      end

      it 'returns no warning if all parameters pass scopes validations' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'token_with_scopes',
              'secure' => true,
              'type' => 'text',
              'scopes' => ['header']
            },
            {
              'name' => 'subdomain',
              'type' => 'text'
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)

        expect(package.warnings).to be_empty
      end
    end

    context 'when scopes are falsy - [] or nil' do
      it 'returns warning for nil scopes' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'token_with_nil_scopes',
              'secure' => true,
              'type' => 'text',
              'scopes' => nil
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)

        expect(package.warnings[0]).to include(
          'The scopes property is not configured for parameter(s): token_with_nil_scopes. This may cause token exposure vulnerabilities. Learn about:'
        )
      end

      it 'returns warning for [] scopes' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'token_with_empty_scopes',
              'secure' => true,
              'type' => 'text',
              'scopes' => []
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)

        expect(package.warnings[0]).to include(
          'The scopes property is not configured for parameter(s): token_with_empty_scopes. This may cause token exposure vulnerabilities. Learn about:'
        )
      end

      it 'returns warning for nil and [] scopes' do
        manifest_hash = {
          'parameters' => [
            {
              'name' => 'token_with_nil_scopes',
              'secure' => true,
              'type' => 'text',
              'scopes' => nil
            },
            {
              'name' => 'token_with_empty_scopes',
              'secure' => true,
              'type' => 'text',
              'scopes' => []
            }
          ]
        }
        package = create_package(manifest_hash)
        subject.call(package)

        expect(package.warnings[0]).to include(
          'The scopes property is not configured for parameter(s): token_with_nil_scopes, token_with_empty_scopes. This may cause token exposure vulnerabilities. Learn about:'
        )
      end
    end
  end
end
