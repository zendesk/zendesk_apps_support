Gem::Specification.new do |s|
  s.name        = 'zendesk_apps_support'
  s.version     = '1.28.0'
  s.license     = 'Apache License Version 2.0'
  s.authors     = ['James A. Rosen', 'Likun Liu', 'Sean Caffery', 'Daniel Ribeiro']
  s.email       = ['dev@zendesk.com']
  s.homepage    = 'http://github.com/zendesk/zendesk_apps_support'
  s.summary     = 'Support to help you develop Zendesk Apps.'
  s.description = s.summary

  s.required_rubygems_version = '>= 1.3.6'

  s.add_runtime_dependency 'i18n'
  s.add_runtime_dependency 'sass'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'json-stream'
  s.add_runtime_dependency 'image_size'
  s.add_runtime_dependency 'erubis'
  s.add_runtime_dependency 'jshintrb', '~> 0.3.0'
  s.add_runtime_dependency 'babel-transpiler'
  s.add_runtime_dependency 'therubyracer'

  s.add_development_dependency 'rspec', '~> 3.4.0'
  s.add_development_dependency 'bump', '~> 0.5.1'

  s.files = Dir.glob('{lib,config}/**/*') + %w(README.md LICENSE)
end
