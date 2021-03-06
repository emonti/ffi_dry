# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ffi_dry}
  s.version = "0.1.12"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Eric Monti"]
  s.date = %q{2010-11-08}
  s.description = %q{Provides some useful modules, classes, and methods for FFI bindings  as well as a DSL-like syntax for FFI::Struct layouts}
  s.email = %q{emonti@matasano.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "History.txt",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "ffi_dry.gemspec",
     "lib/ffi/dry.rb",
     "lib/ffi/dry/errno.rb",
     "lib/ffi_dry.rb",
     "samples/afmap.rb",
     "samples/basic.rb",
     "samples/describer.rb",
     "spec/errno_spec.rb",
     "spec/ffi_dry_spec.rb",
     "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/emonti/ffi_dry}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{Syntactic sugar and helper utilities for FFI}
  s.test_files = [
    "spec/errno_spec.rb",
     "spec/ffi_dry_spec.rb",
     "spec/spec_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ffi>, [">= 0.5.0"])
    else
      s.add_dependency(%q<ffi>, [">= 0.5.0"])
    end
  else
    s.add_dependency(%q<ffi>, [">= 0.5.0"])
  end
end

