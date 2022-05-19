# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

describe ZendeskAppsSupport::Package do
  before do
    @package = ZendeskAppsSupport::Package.new('spec/app')

    lib_files_original_method = @package.method(:lib_files)
    allow(@package).to receive(:lib_files) do |*args, &block|
      lib_files_original_method.call(*args, &block).sort_by(&:relative_path)
    end
  end

  describe 'has_custom_object_requirements?' do
    it 'should return true when custom object types are present' do
      requirements_hash = {
        'custom_objects' => {
          'custom_object_types' => [
            {
              'key' => 'product',
              'schema' => { 'properties' => { 'id' => { 'type' => 'string' } } }
            }
          ]
        }
      }
      expect(described_class.has_custom_object_requirements?(requirements_hash)).to be(true)
    end

    it 'should return true when custom object relationships are present' do
      requirements_hash = {
        'custom_objects' => {
          'custom_object_relationship_types' => [
            { 'key' => 'a', 'source' => 'b', 'target' => 'a' }
          ]
        }
      }

      expect(described_class.has_custom_object_requirements?(requirements_hash)).to be(true)
    end

    it 'should return false when custom object types are not present' do
      requirements_hash = {
        'custom_objects' => {
          'custom_object_types' => []
        }
      }

      expect(described_class.has_custom_object_requirements?(requirements_hash)).to be(false)
    end

    it 'should return false when custom object relationships are not present' do
      requirements_hash = {
        'custom_objects' => {
          'custom_object_relationship_types' => []
        }
      }

      expect(described_class.has_custom_object_requirements?(requirements_hash)).to be(false)
    end

    it 'should return true when custom object types are present but relationships types are not defined' do
      requirements_hash = {
        'custom_objects' => {
          'custom_object_types' => [
            {
              'key' => 'product',
              'schema' => { 'properties' => { 'id' => { 'type' => 'string' } } }
            }
          ],
          'custom_object_relationship_types' => []
        }
      }

      expect(described_class.has_custom_object_requirements?(requirements_hash)).to be(true)
    end

    it 'should return true when custom object relationship types are present but custom object types are not defined' do
      requirements_hash = {
        'custom_objects' => {
          'custom_object_types' => [],
          'custom_object_relationship_types' => [
            { 'key' => 'a', 'source' => 'b', 'target' => 'a' }
          ]
        }
      }

      expect(described_class.has_custom_object_requirements?(requirements_hash)).to be(true)
    end

    it 'should return false when custom requirements empty' do
      requirements_hash = {
        'custom_objects' => {}
      }

      expect(described_class.has_custom_object_requirements?(requirements_hash)).to be(false)
    end

    it 'should return false when custom requirements are not present' do
      requirements_hash = {}

      expect(described_class.has_custom_object_requirements?(requirements_hash)).to be(false)
    end

    it 'should return false when requirements are not present' do
      requirements_hash = nil

      expect(described_class.has_custom_object_requirements?(requirements_hash)).to be(false)
    end
  end

  describe 'files' do
    it 'should return all the files within the app folder excluding files in tmp and vendor folder' do
      files = %w[app.css app.js assets/logo-small.png assets/logo.png lib/a.js lib/a.txt
                 lib/nested/b.js manifest.json templates/layout.hdbs translations/en.json translations/nl.json]
      expect(@package.files.map(&:relative_path)).to match_array(files)
    end

    it 'should error out when manifest is missing' do
      @package = ZendeskAppsSupport::Package.new('spec/app_nomanifest')
      err = @package.validate
      expect(err.first.class).to eq(ZendeskAppsSupport::Validations::ValidationError)
      expect(err.first.to_s).to eq('Could not find manifest.json')
    end
  end

  describe 'template_files' do
    it 'should return all the files in the templates folder within the app folder' do
      expect(@package.template_files.map(&:relative_path)).to eq(%w[templates/layout.hdbs])
    end
  end

  describe 'translation_files' do
    it 'should return all the files in the translations folder within the app folder' do
      expect(@package.translation_files.map(&:relative_path).sort).to eq(%w[translations/en.json translations/nl.json])
    end
  end

  describe 'lib_files' do
    it 'should return all the javascript files in the lib folder within the app folder' do
      expect(@package.lib_files.map(&:relative_path)).to eq(%w[lib/a.js lib/nested/b.js])
    end
  end

  describe 'commonjs_modules' do
    it 'should return an object with name value pairs containing the path and code' do
      expect(@package.send(:commonjs_modules)).to eq(
        'a.js' => "var a = {\n  name: 'This is A'\n};\n\nmodule.exports = a;\n",
        'nested/b.js' => "var b = {\n  name: 'This is B'\n};\n\nmodule.exports = b;\n"
      )
    end
  end

  describe 'compile' do
    it 'should generate js ready for installation' do
      js = @package.compile(app_name: 'ABC', app_id: 0, assets_dir: 'http://localhost:4567/0/')
      expected = File.read('spec/fixtures/legacy_app_en.js')
      expect(js).to eq(expected)

      js = @package.compile(app_name: 'EFG', app_id: 1, assets_dir: 'http://localhost:4567/2/', locale: 'nl')
      expected = File.read('spec/fixtures/legacy_app_nl.js')
      expect(js).to eq(expected)
    end

    it 'should generate css with the new flag' do
      expect(@package.manifest).to receive(:enabled_experiments).and_return(['newCssCompiler'])
      js = @package.compile(app_name: 'ABC', app_id: 0, assets_dir: 'http://localhost:4567/0/')
      expected = File.read('spec/fixtures/legacy_app_en_experimental_css.js')
      expect(js).to eq(expected)
    end

    it 'should generate js for iframe app installations' do
      @package = ZendeskAppsSupport::Package.new('spec/fixtures/iframe_only_app')
      js = @package.compile(app_name: 'ABC', app_id: 0, assets_dir: 'http://localhost:4567/0/')
      expected = File.read('spec/fixtures/iframe_app.js')
      expect(js).to eq(expected)
    end

    it 'should generate js for an iframe app with multiple locations across products' do
      @package = ZendeskAppsSupport::Package.new('spec/fixtures/multi_product_iframe_only_app')
      js = @package.compile(app_name: 'ABC', app_id: 0, assets_dir: 'http://localhost:4567/0/')
      expected = File.read('spec/fixtures/multi_product_iframe_app.js')
      expect(js).to eq(expected)
    end

    it 'should generate js with manifest noTemplate set to array' do
      allow(@package.manifest).to receive(:no_template) { ['ticket_sidebar'] }
      js = @package.compile(app_name: 'ABC', app_id: 0, assets_dir: 'http://localhost:4567/0/')
      expected = File.read('spec/fixtures/legacy_app_no_template.js')
      expect(js).to eq(expected)
    end
  end

  describe 'deep_merge_hash' do
    it 'should merge a simple hash' do
      hash1   = { 'id' => 1 }
      hash2   = { 'id' => 2 }
      expected = { 'id' => 2 }
      expect(@package.send(:deep_merge_hash, hash1, hash2)).to eq(expected)
    end

    it 'should merge 2 hashes recursively' do
      hash1   = { 'id' => 1, 'nick' => { label: 'test', gender: 'yes' } }
      hash2   = { 'id' => 2 }
      expected = { 'id' => 2, 'nick' => { label: 'test', gender: 'yes' } }
      expect(@package.send(:deep_merge_hash, hash1, hash2)).to eq(expected)

      hash1   = { 'id' => 1, 'nick' => { label: 'test', gender: 'yes' } }
      hash2   = { 'id' => 2, 'nick' => 'test' }
      expected = { 'id' => 2, 'nick' => 'test' }
      expect(@package.send(:deep_merge_hash, hash1, hash2)).to eq(expected)

      hash1   = { 'id' => 1, 'nick' => { label: { text: 'text', value: 'value' } } }
      hash2   = { 'id' => 2, 'nick' => { label: { text: 'different', option: 3 } } }
      expected = { 'id' => 2, 'nick' => { label: { text: 'different', value: 'value', option: 3 } } }
      expect(@package.send(:deep_merge_hash, hash1, hash2)).to eq(expected)
    end
  end

  let(:manifest) do
    JSON.parse(File.read('spec/bookmarks_app/manifest.json'))
  end

  let(:root) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(root) if Dir.exist?(root)
  end

  def build_app_source(app)
    app_js           = File.read('spec/bookmarks_app/app.js')
    app_css          = File.read('spec/bookmarks_app/app.css')
    main_template    = File.read('spec/bookmarks_app/templates/main.hdbs')
    layout           = nil
    en_json          = File.read('spec/bookmarks_app/translations/en.json')
    logo             = File.read('spec/bookmarks_app/assets/logo.png')
    logo_small       = File.read('spec/bookmarks_app/assets/logo-small.png')
    manifest         = JSON.generate(app[:manifest] || {})
    additional_files = app[:additional_files] || {}

    FileUtils.rm_rf(root) if Dir.exist?(root)

    {
      'manifest.json'         => manifest,
      'app.js'                => app_js,
      'app.css'               => app_css,
      'templates/layout.hdbs' => layout,
      'templates/main.hdbs'   => main_template,
      'translations/en.json'  => en_json,
      'assets/logo.png'       => logo,
      'assets/logo-small.png' => logo_small
    }.merge(additional_files).each do |path, content|
      next if content.nil?
      path = File.join(root, path)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') { |f| f << content }
    end

    File.join(root)
  end

  let(:source) { build_app_source(manifest: manifest) }

  let(:package) { ZendeskAppsSupport::Package.new(source) }

  def build_app_source_with_files(files)
    build_app_source(manifest: manifest,
                     additional_files: files)
  end

  describe '#translations' do
    let(:name) { 'Bookmarks App' }
    let(:description) { 'Quickly access bookmarked tickets. Syncs with the iPad app.' }
    let(:custom1) { 'The first custom thing' }
    context 'with default locale' do
      it 'returns translations' do
        expected_translations = { 'en' => {
          'app' => {
            'name' => name,
            'short_description' => description,
            'description' => 'Access bookmarks',
            'long_description' => 'Access bookmarks in your Zendesk',
            'installation_instructions' => 'Pull the big lever'
          },
          'custom1' => custom1
        } }
        expect(package.send(:translations)).to eq(expected_translations)
        expect(package.locales).to eq(['en'])
      end

      context 'with zh-cn.json' do
        let(:source) do
          build_app_source_with_files('translations/zh-cn.json' => File.read('spec/translations/zh-cn.json'))
        end

        it 'includes en and zh-cn in translations' do
          expect(package.locales).to match_array(['en', 'zh-cn'])
        end

        it 'includes zh-cn in translations' do
          expected_translations = JSON.parse(File.read('spec/translations/zh-cn.json'))
          expect(package.send(:translations)['zh-cn'].except('custom1')).to eq(expected_translations)
        end

        it 'merges missing keys with the default locale' do
          expect(package.send(:translations)['zh-cn']['custom1']).to eq(custom1)
        end
      end

      context 'with zh-cn_keyval.json' do
        let(:source) do
          build_app_source_with_files('translations/zh-cn.json' => File.read('spec/translations/zh-cn_keyval.json'))
        end

        it 'includes en and zh-cn in translations' do
          expect(package.locales).to match_array(['en', 'zh-cn'])
        end

        it 'removes zendesk-specific keys in translations' do
          expected_translations = JSON.parse(File.read('spec/translations/zh-cn.json'))
          expect(package.send(:translations)['zh-cn'].except('custom1')).to eq(expected_translations)
        end

        it 'merges missing keys with the default locale' do
          expect(package.send(:translations)['zh-cn']['custom1']).to eq(custom1)
        end

        it 'removes app.package key' do
          expect(package.send(:translations)['zh-cn']['app']['package']).to be_nil
        end
      end
    end

    context 'without a default locale' do
      let(:manifest) { super().merge('defaultLocale' => nil) }

      it 'returns translations' do
        expected_translations = { 'en' => {
          'app' => {
            'short_description' => description,
            'description' => 'Access bookmarks',
            'long_description' => 'Access bookmarks in your Zendesk',
            'installation_instructions' => 'Pull the big lever'
          },
          'custom1' => custom1
        } }
        expect(package.send(:translations)).to eq(expected_translations)
        expect(package.locales).to eq(['en'])
      end
    end
  end

  describe '#css' do
    context 'for an app with an app.css' do
      it 'returns the CSS' do
        expect(package.app_css).to eq(File.read('spec/bookmarks_app/app.css'))
      end
    end

    context 'for an app without an app.css' do
      let(:source) { build_app_source(additional_files: { 'app.css' => nil }) }

      it 'returns an empty string' do
        expect(package.app_css).to eq('')
      end
    end
  end

  describe '#runtime_translations' do
    let(:translations) do
      {
        'app' => {
          'name' => 'Some App',
          'short_description' => 'It does something.',
          'long_description' => 'Some App does some really fantastic things.',
          'installation_instructions' => 'Just click install.',
          'everything_else' => 'preserved'
        }
      }
    end
    let(:source) { build_app_source(additional_files: { 'translations/en.json' => translations.to_json }) }

    subject { package.send :runtime_translations, package.translations_for('en').fetch('app') }

    it 'ignores "name", "short_description", "long_description", "installation_instructions", preserving other keys' do
      expect(subject).to eq('everything_else' => 'preserved')
    end
  end

  describe '#validate' do
    before do
      allow(ZendeskAppsSupport::Validations::Marketplace).to receive(:call)
      allow(ZendeskAppsSupport::Validations::Templates).to receive(:call)
      allow(ZendeskAppsSupport::Validations::Stylesheets).to receive(:call)
      package.validate!(marketplace: false)
    end

    it 'should not run marketplace validations when app is not for the marketplace' do
      expect(ZendeskAppsSupport::Validations::Marketplace).not_to have_received(:call)
    end

    it 'normally validates templates and stylesheets' do
      expect(ZendeskAppsSupport::Validations::Templates).to have_received(:call)
      expect(ZendeskAppsSupport::Validations::Stylesheets).to have_received(:call)
    end

    context 'for a marketplace app' do
      it 'runs marketplace validations' do
        package.validate!(marketplace: true)
        expect(ZendeskAppsSupport::Validations::Marketplace).to have_received(:call).with(package)
      end
    end

    context 'for a requirements-only app' do
      let(:manifest) do
        json = JSON.parse(File.read('spec/fixtures/marketing_only_app/manifest.json'))
        json.merge('requirementsOnly' => true, 'marketingOnly' => false)
      end
      let(:source) do
        build_app_source(
          manifest: manifest,
          additional_files: {
            'requirements.json'     => read_fixture_file('requirements.json'),
            'app.js'                => nil,
            'app.css'               => nil,
            'templates/layout.hdbs' => nil,
            'templates/main.hdbs'   => nil
          }
        )
      end

      it 'does not validate templates or stylesheets' do
        expect(ZendeskAppsSupport::Validations::Templates).not_to have_received(:call)
        expect(ZendeskAppsSupport::Validations::Stylesheets).not_to have_received(:call)
      end
    end

    context 'for a marketing-only app' do
      let(:package) { ZendeskAppsSupport::Package.new('spec/fixtures/marketing_only_app') }

      it 'does not validate templates or stylesheets' do
        expect(ZendeskAppsSupport::Validations::Templates).not_to have_received(:call)
        expect(ZendeskAppsSupport::Validations::Stylesheets).not_to have_received(:call)
      end
    end

    context 'for a iframe-only app' do
      let(:package) { ZendeskAppsSupport::Package.new('spec/fixtures/iframe_only_app') }

      it 'does not validate templates or stylesheets' do
        expect(ZendeskAppsSupport::Validations::Templates).not_to have_received(:call)
        expect(ZendeskAppsSupport::Validations::Stylesheets).not_to have_received(:call)
      end
    end
  end

  describe '#commonjs_modules' do
    let(:modules) { package.send(:commonjs_modules) }

    context 'when there are js modules' do
      let(:source) do
        build_app_source_with_files('lib/a.js' => File.read('spec/bookmarks_app/lib/a.js'),
                                    'lib/foo/b.js' => File.read('spec/bookmarks_app/lib/foo/b.js'))
      end

      it 'returns the contents of the file at lib/a.js' do
        expect(modules['a.js']).to eq(File.read('spec/bookmarks_app/lib/a.js'))
      end

      it 'returns the contents of the file in subfolder lib/foo/b.js' do
        expect(modules['foo/b.js']).to eq(File.read('spec/bookmarks_app/lib/foo/b.js'))
      end
    end

    context 'when there are no js modules' do
      it { expect(modules).not_to be nil }
    end
  end

  describe '#location_icons' do
    before do
      allow(package.manifest).to receive(:locations).and_return(mocked_locations)
    end

    context 'when a product does not support location icons' do
      let(:mocked_locations) do
        {
          'chat' => { 'other_location' => { 'url' => '' } },
          'support' => {
            'top_bar' => { 'url' => 'some_url' },
            'nav_bar' => { 'url' => 'other_url' },
            'ticket_sidebar' => { 'url' => 'last_url' }
          }
        }
      end

      it 'discards that product quietly' do
        allow(package).to receive(:has_file?) do |file|
          file == 'assets/icon_top_bar.svg' || file == 'assets/icon_nav_bar.svg'
        end
        expect(package.send(:location_icons).keys).not_to include('chat')
      end
    end

    context 'when an app is multi-product and has location icons' do
      let(:mocked_locations) do
        {
          'chat' => { 'other_location' => { 'url' => '' } },
          'support' => {
            'top_bar' => { 'url' => 'some_url' },
            'nav_bar' => { 'url' => 'other_url' },
            'ticket_sidebar' => { 'url' => 'last_url' }
          },
          'sell' => {
            'top_bar' => { 'url' => 'some_url' }
          }
        }
      end

      it 'scopes the assets by product name' do
        allow(package).to receive(:has_file?) do |file|
          file =~ %r{assets/(sell|support)/icon_(top|nav)_bar.svg}
        end
        expect(package.send(:location_icons)).to eq('support' => {
                                                      'top_bar' => { 'svg' => 'support/icon_top_bar.svg' },
                                                      'nav_bar' => { 'svg' => 'support/icon_nav_bar.svg' }
                                                    }, 'sell' => {
                                                      'top_bar' => { 'svg' => 'sell/icon_top_bar.svg' }
                                                    })
      end
    end

    context 'when it has an svg and product is support' do
      let(:mocked_locations) do
        {
          'support' => {
            'top_bar' => { 'url' => 'some_url' },
            'nav_bar' => { 'url' => 'other_url' },
            'ticket_sidebar' => { 'url' => 'last_url' }
          }
        }
      end

      it 'returns correct location_icons hash for top_bar' do
        allow(package).to receive(:has_file?) do |file|
          file == 'assets/icon_top_bar.svg' || file == 'assets/icon_nav_bar.svg'
        end
        expect(package.send(:location_icons)).to eq('support' => {
                                                      'top_bar' => { 'svg' => 'icon_top_bar.svg' },
                                                      'nav_bar' => { 'svg' => 'icon_nav_bar.svg' }
                                                    })
      end
    end

    context 'when it has an svg and product is sell' do
      let(:mocked_locations) do
        {
          'sell' => { 'top_bar' => { 'url' => 'some_url' } }
        }
      end

      it 'returns correct location_icons hash for top_bar' do
        allow(package).to receive(:has_file?) do |file|
          file == 'assets/icon_top_bar.svg'
        end
        expect(package.send(:location_icons)).to eq('sell' => { 'top_bar' => { 'svg' => 'icon_top_bar.svg' } })
      end
    end

    context 'when it has three pngs' do
      let(:mocked_locations) do
        {
          'support' => {
            'top_bar' => { 'url' => 'some_url' },
            'nav_bar' => { 'url' => 'other_url' },
            'ticket_sidebar' => { 'url' => 'last_url' }
          }
        }
      end

      it 'returns correct location_icons hash' do
        allow(package).to receive(:has_file?) do |file|
          file != 'assets/icon_top_bar.svg' && file != 'assets/icon_nav_bar.svg'
        end
        expect(package.send(:location_icons)).to eq('support' => {
                                                      'top_bar' => {
                                                        'inactive' => 'icon_top_bar_inactive.png',
                                                        'active' => 'icon_top_bar_active.png',
                                                        'hover' => 'icon_top_bar_hover.png'
                                                      },
                                                      'nav_bar' => {
                                                        'inactive' => 'icon_nav_bar_inactive.png',
                                                        'active' => 'icon_nav_bar_active.png',
                                                        'hover' => 'icon_nav_bar_hover.png'
                                                      }
                                                    })
      end
    end

    context 'when it only has inactive pngs' do
      let(:mocked_locations) do
        {
          'support' => {
            'top_bar' => { 'url' => 'some_url' },
            'nav_bar' => { 'url' => 'other_url' },
            'ticket_sidebar' => { 'url' => 'last_url' }
          }
        }
      end

      it 'returns correct location_icons hash' do
        allow(package).to receive(:has_file?) do |file|
          file == 'assets/icon_top_bar_inactive.png' || file == 'assets/icon_nav_bar_inactive.png'
        end
        expect(package.send(:location_icons)).to eq('support' => {
                                                      'top_bar' => {
                                                        'inactive' => 'icon_top_bar_inactive.png',
                                                        'active' => 'icon_top_bar_inactive.png',
                                                        'hover' => 'icon_top_bar_inactive.png'
                                                      },
                                                      'nav_bar' => {
                                                        'inactive' => 'icon_nav_bar_inactive.png',
                                                        'active' => 'icon_nav_bar_inactive.png',
                                                        'hover' => 'icon_nav_bar_inactive.png'
                                                      }
                                                    })
      end
    end

    context 'when it has pngs and svgs' do
      let(:mocked_locations) do
        {
          'support' => {
            'top_bar' => { 'url' => 'some_url' },
            'nav_bar' => { 'url' => 'other_url' },
            'ticket_sidebar' => { 'url' => 'last_url' }
          }
        }
      end

      it 'returns correct location_icons hash' do
        allow(package).to receive(:has_file?) { true }
        expect(package.send(:location_icons)).to eq('support' => {
                                                      'top_bar' => {
                                                        'svg' => 'icon_top_bar.svg'
                                                      },
                                                      'nav_bar' => {
                                                        'svg' => 'icon_nav_bar.svg'
                                                      }
                                                    })
      end
    end

    context 'when it has no images' do
      let(:mocked_locations) do
        {
          'support' => {
            'top_bar' => { 'url' => 'some_url' },
            'nav_bar' => { 'url' => 'other_url' },
            'ticket_sidebar' => { 'url' => 'last_url' }
          }
        }
      end

      it 'returns correct location_icons hash' do
        allow(package).to receive(:has_file?) { false }
        expect(package.send(:location_icons)).to eq('support' => {
                                                      'top_bar' => {},
                                                      'nav_bar' => {}
                                                    })
      end
    end
  end
end
