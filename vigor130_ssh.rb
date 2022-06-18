#!/usr/local/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/ssh/telnet'
require 'wikk_configuration'
RLIB = '../../../rlib'
require_relative "#{RLIB}/wikk_conf.rb"

# SSH to the VDSL Modem and run the command specified by the arguments passed.

@config = WIKK::Configuration.new("#{KEYS_DIR}/#{ARGV[0]}")

begin
  Net::SSH::Transport::Algorithms::ALGORITHMS[:encryption] = [ '3des-cbc', 'none' ]
  Net::SSH::Transport::Algorithms::ALGORITHMS[:host_key] = [ 'ssh-dss', 'none' ]

  Net::SSH.start(@config.hostname, @config.admin_user, password: @config.admin_key) do |session|
    Net::SSH::Telnet.new('Session' => session, 'Prompt' => /^> .*$/, 'Telnetmode' => false)
  end
rescue StandardError => e
  puts "Error: #{e}"
end
