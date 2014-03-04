# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
Gem::Specification.new do |s|
  s.name        = "stubby"
  s.version     = "0.0.10"
  s.authors     = ["James Kassemi", "Glen Holcomb"]
  s.email       = ["jkassemi@gmail.com", "damnbigman@gmail.com"]
  s.homepage    = "http://github.com/jkassemi/stubby"
  s.summary     = "Declarative hosts / proxy management for multi-environment development"
  s.licenses    = ["MIT"]
  s.bindir      = "bin"
 
  s.required_rubygems_version = ">= 1.8.23"
  s.rubyforge_project         = "stubby"
 
  s.add_dependency 'bundler'
  s.add_dependency 'rubydns', '0.7.0'
  s.add_dependency 'liquid', '2.6.1'
  s.add_dependency 'multi_json', '1.8.4'
  s.add_dependency 'sinatra', '1.4.4'
  s.add_dependency 'sinatra-contrib', '1.4.2'
  s.add_dependency 'rack-ssl', '1.3.3'
  s.add_dependency 'dns-zonefile', '1.0.4'
  s.add_dependency 'ipaddress', '0.8.0'
  s.add_dependency 'httpi', '2.1.0'
  s.add_dependency 'thor', '0.18.1'
  s.add_dependency 'listen', '2.6.2'
  s.add_dependency 'oj', '2.5.5'
  s.add_dependency 'thin', '1.5.1'
  s.add_dependency 'mailcatcher', '0.5.12'
  s.add_dependency 'curb'

  s.add_development_dependency "rspec"
  s.add_development_dependency "pry"
 
  s.files        = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)
  s.executables  = ['stubby']
  s.require_path = 'lib'
end
