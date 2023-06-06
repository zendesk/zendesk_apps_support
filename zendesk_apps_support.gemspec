# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'zendesk_apps_support'
  s.version     = '4.39.0'
  s.license     = 'Apache License Version 2.0'
  s.authors     = ['James A. Rosen', 'Likun Liu', 'Sean Caffery', 'Daniel Ribeiro']
  s.email       = ['dev@zendesk.com']
  s.homepage    = 'http://github.com/zendesk/zendesk_apps_support'
  s.summary     = 'Support to help you develop Zendesk Apps.'
  s.description = s.summary

  s.required_ruby_version = Gem::Requirement.new('>= 2.7')
  s.required_rubygems_version = '>= 1.3.6'

  s.add_runtime_dependency 'i18n', '>= 1.7.1'
  s.add_runtime_dependency 'sassc'
  s.add_runtime_dependency 'sass' # remove explicit dependency when all compilation uses SassC
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'image_size', '~> 2.0.2'
  s.add_runtime_dependency 'erubis'
  s.add_runtime_dependency 'loofah', '>= 2.3.1', '< 2.20.0'
  s.add_runtime_dependency 'nokogiri'
  s.add_runtime_dependency 'rb-inotify', '0.9.10'
  s.add_runtime_dependency 'marcel'
  s.add_runtime_dependency 'ipaddress_2', '~> 0.13.0'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'bump', '~> 0.5.1'
  s.add_development_dependency 'faker'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'byebug', '~> 9.0.6'
  s.add_development_dependency 'bundler', '~> 2.2'
  s.add_development_dependency 'parallel', '1.12.1'
  s.add_development_dependency 'rake'

  s.files = Dir.glob('{lib,config}/**/*') + %w[README.md LICENSE]
end
