# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'bundler/setup'
require 'rspec/core/rake_task'
require 'bump/tasks'

RSpec::Core::RakeTask.new(:spec)
task default: :spec

def array_to_nested_hash(array)
  array.each_with_object({}) do |item, result|
    add_translation(result, item['key'], item['value'])
  end
end

require 'pathname'
require 'yaml'
project_root = Pathname.new(File.dirname(__FILE__))
zendesk_i18n_file = project_root.join('config/locales/translations/zendesk_apps_support.yml')
standard_i18n_file = project_root.join('config/locales/en.yml')

file standard_i18n_file => zendesk_i18n_file do |task|
  header = "# This is a generated file. Do NOT edit directly.\n# To update, run 'bundle exec rake i18n:standardize'.\n"
  input = YAML.safe_load_file(task.prerequisites.first)
  translations = input['parts'].map { |part| part['translation'] }
  yaml = YAML.dump('en' => array_to_nested_hash(translations))
  save_file(task.name, header + yaml)
end

namespace :i18n do
  desc 'Generate the standard I18n file'
  task standardize: standard_i18n_file
end

def add_translation(translations, key, value)
  parts = key.split('.')
  leaf = parts[0..-2].inject(translations) do |current, part|
    current[part] ||= {}
  end
  leaf[parts.last] = value

  translations
end

def save_file(file, content)
  puts "Writing #{file}"
  File.write(file, content)
end

namespace :translations do
  desc 'Download translations'
  task :download do
    require 'net/http'
    require 'json'
    require 'parallel'

    package = 'apps_support'
    translations_dir = 'config/locales'
    base_url = 'https://static.zdassets.com/translations'

    puts "Fetching manifest for package: #{package}"
    manifest_uri = URI("#{base_url}/#{package}/manifest.json")
    manifest_response = Net::HTTP.get_response(manifest_uri)

    if manifest_response.code.to_s != '200'
      abort "Failed to fetch manifest from #{manifest_uri}. Skipping!"
    end

    manifest = JSON.parse(manifest_response.body)

    Parallel.each(manifest.fetch('json')) do |asset|
      asset_path = asset.fetch('path')
      locale = asset.fetch('name')

      puts "Fetching translations for locale: #{locale}"
      asset_uri = URI("#{base_url}#{asset_path}")
      response = Net::HTTP.get_response(asset_uri)

      if response.code.to_s != '200'
        abort "Failed to download translations from: #{asset_uri}"
      end

      translations_json = JSON.parse(response.body).fetch('translations')

      # Convert translations
      translations = translations_json.each_with_object({}) do |(key, value), translations|
        add_translation(translations, key, value)
      end
      yaml = YAML.dump(locale.to_sym => translations)

      yml_file = File.join(translations_dir, "#{locale}.yml")
      save_file(yml_file, yaml)
    end
  end
end
