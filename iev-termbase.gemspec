# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "iev/termbase/version"

Gem::Specification.new do |spec|
  spec.name          = "iev-termbase"
  spec.version       = IEV::Termbase::VERSION
  spec.authors       = ["Ribose"]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = %q{Build scripts for the ISO/TC 211 Termbase}
  spec.description   = %q{Build scripts for the ISO/TC 211 Termbase}
  spec.homepage      = "https://open.ribose.com"

  spec.require_paths = ["lib"]
  spec.bindir        = "exe"
  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {spec}/*`.split("\n")
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.required_ruby_version = ">= 3.0"

  spec.add_runtime_dependency "creek", "~> 2.5"
  spec.add_runtime_dependency "mathml2asciimath", "< 1"
  spec.add_runtime_dependency "glossarist", "~> 0.1.0"
  spec.add_runtime_dependency "relaton", "~> 1.0"
  spec.add_runtime_dependency "sequel", "~> 5.40"
  spec.add_runtime_dependency "sqlite3", "~> 1.4.2"
  spec.add_runtime_dependency "thor", "~> 1.0"
  spec.add_runtime_dependency "zeitwerk", "~> 2.4"

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "debase"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "ruby-debug-ide"
  spec.add_development_dependency "ruby-prof"
end
