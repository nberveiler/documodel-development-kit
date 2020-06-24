# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'documodel_development_kit'

Gem::Specification.new do |spec|
  spec.name          = 'documodel-development-kit'
  spec.version       = DMDK::GEM_VERSION
  spec.authors       = ['Nick Berveiler', 'DocuModel']
  spec.email         = ['nberveiler@gmail.com']

  spec.summary       = 'CLI for DocuModel Development Kit'
  spec.description   = 'CLI for DocuModel Development Kit.'
  spec.homepage      = 'https://github.com/nberveiler/documodel-development-kit.git'
  spec.license       = 'MIT'
  spec.files         = ['lib/documodel_development_kit.rb']
  spec.executables   = ['dmdk']

  spec.required_ruby_version = '~> 2.6.6'
end
