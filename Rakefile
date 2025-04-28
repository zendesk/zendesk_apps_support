# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'bundler/setup'
require 'rspec/core/rake_task'
require 'bump/tasks'

RSpec::Core::RakeTask.new(:spec)
task default: :spec

def array_to_nested_hash(array)
  array.each_with_object({}) do |item, result|
    keys = item['key'].split('.')
    current = result
    keys[0..-2].each do |key|
      current = (current[key] ||= {})
    end
    current[keys[-1]] = item['value']
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
  File.open(task.name, 'w') { |f| f << (header + yaml) }
end

namespace :i18n do
  desc 'Generate the standard I18n file'
  task standardize: standard_i18n_file
end
