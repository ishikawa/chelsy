# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chelsy/version'

Gem::Specification.new do |spec|
  spec.name          = 'chelsy'
  spec.version       = Chelsy::VERSION
  spec.authors       = ['Takanori Ishikawa']
  spec.email         = ['takanori.ishikawa@gmail.com']

  spec.homepage      = 'https://github.com/ishikawa/chelsy'
  spec.summary       = 'C code generator'
  spec.description   = 'C code generator written in Ruby (Work in progress)'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.required_ruby_version = '~> 2.0'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'pry', '~> 0.10.4'
end
