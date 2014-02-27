# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
Gem::Specification.new do |s|
  s.name        = "stubby"
  s.version     = "0.0.3"
  s.authors     = ["James Kassemi"]
  s.email       = ["jkassemi@gmail.com"]
  s.homepage    = "http://github.com/jkassemi/stubby"
  s.summary     = ""
  s.description = ""
  s.bindir      = "bin"
 
  s.required_rubygems_version = ">= 1.8.23"
  s.rubyforge_project         = "stubby"
 
  s.add_dependency 'rubydns'
  s.add_dependency 'ipaddress'
  s.add_dependency 'sinatra'
  s.add_dependency 'liquid'
  s.add_dependency 'oj'
  s.add_dependency 'multi_json'
  s.add_dependency 'httpi'
  s.add_dependency 'rack-ssl'
  s.add_dependency 'dns-zonefile'
  s.add_dependency 'thor'
  s.add_dependency 'listen'
  s.add_dependency 'thin'
  s.add_dependency 'mailcatcher'
  
  s.add_development_dependency "rspec"
 
  s.files        = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)
  s.executables  = ['stubby']
  s.require_path = 'lib'
end
