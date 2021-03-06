# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'object/cache'

Gem::Specification.new do |spec|
  spec.name          = 'object-cache'
  spec.version       = Cache::VERSION
  spec.authors       = %w[Jean Mertz]
  spec.email         = %w[jean@mertz.fm]

  spec.summary       = 'Caching of objects, using a Redis store.'
  spec.description   = 'Easily cache objects in Ruby, using a Redis store backend'
  spec.homepage      = 'https://github.com/blendle/object-cache'
  spec.license       = 'MIT'
  spec.files         = `git ls-files -z`.split("\x0")
  spec.require_paths = %w[lib]

  spec.add_development_dependency 'bundler', '~> 2.1'
  spec.add_development_dependency 'm', '~> 1.5'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'mock_redis', '~> 0.16'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop'
end
