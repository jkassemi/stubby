# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
Gem::Specification.new do |s|
  s.name        = "stubby"
  s.version     = "0.0.1"
  s.authors     = ["James Kassemi"]
  s.email       = ["jkassemi@gmail.com"]
  s.homepage    = "http://github.com/jkassemi/stubby"
  s.summary     = ""
  s.description = ""
 
  s.required_rubygems_version = ">= 1.8.23"
  s.rubyforge_project         = "stubby"
 
  s.add_development_dependency "rspec"
 
  s.files        = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)
  s.executables  = ['stubby']
  s.require_path = 'lib'
end
