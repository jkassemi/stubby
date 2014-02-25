STUBBY_MASTER="172.16.123.1"

require 'multi_json'
require 'rubygems'
require 'bundler/setup'
require 'stubby/extensions/dns/osx'
require 'stubby/extensions/dns'
require 'stubby/extensions/http'
require 'stubby/extensions/smtp'
require 'stubby/extensions/reload'
require 'stubby/registry'
require 'stubby/stub'
require 'stubby/master'

=begin
module Kernel
  alias _trap trap

  def trap(*args)
    puts "kernel::trap: #{args.inspect}\n---------------\n #{caller.join("\n")}\n\n"
    _trap(*args)
  end
end
=end
