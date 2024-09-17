# frozen_string_literal: true

require 'spec_helper'

describe ZendeskAppsSupport::BuildTranslation do
  include ZendeskAppsSupport::BuildTranslation

  let(:en_json) do
    {
      'app' => {
        'abc' => {
          'title' => 'description for abc field',
          'value' => 'value of abc'
        }
      },
      'a' => {
        'a1' => {
          'title' => 'description for a1 field',
          'value' => 'value of a1'
        },
        'b' => {
          'b1' => {
            'title' => 'description for b1 field',
            'value' => 'value of b1'
          }
        }
      }
    }
  end

  describe '#to_flattened_namespaced_hash' do
    context 'not zendesk i18n format' do
      it 'should flatten hash without removing zendesk keys' do
        expected = {
          'app.abc.title' => 'description for abc field',
          'app.abc.value' => 'value of abc',
          'a.a1.title'    => 'description for a1 field',
          'a.a1.value'    => 'value of a1',
          'a.b.b1.title'  => 'description for b1 field',
          'a.b.b1.value'  => 'value of b1'
        }

        expect(to_flattened_namespaced_hash(en_json)).to eq(expected)
      end
    end

    context 'zendesk i18n format' do
      context 'flatten value keys' do
        it 'should flatten hash by removing zendesk title keys' do
          expected = {
            'app.abc' => 'value of abc',
            'a.a1'    => 'value of a1',
            'a.b.b1'  => 'value of b1'
          }
          value_key = ZendeskAppsSupport::BuildTranslation::I18N_VALUE_KEY
          expect(to_flattened_namespaced_hash(en_json, value_key)).to eq(expected)
        end
      end

      context 'flatten title keys' do
        it 'should flatten hash by removing zendesk value keys' do
          expected = {
            'app.abc' => 'description for abc field',
            'a.a1'    => 'description for a1 field',
            'a.b.b1'  => 'description for b1 field'
          }
          title_key = ZendeskAppsSupport::BuildTranslation::I18N_TITLE_KEY
          expect(to_flattened_namespaced_hash(en_json, title_key)).to eq(expected)
        end
      end
    end
  end

  describe '#remove_zendesk_keys' do
    it 'should remove zendesk translation keys' do
      expected = {
        'app' => {
          'abc' => 'value of abc'
        },
        'a' => {
          'a1' => 'value of a1',
          'b'  => {
            'b1' => 'value of b1'
          }
        }
      }
      expect(remove_zendesk_keys(en_json)).to eq(expected)
    end
  end
end
