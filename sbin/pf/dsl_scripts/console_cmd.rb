#!/usr/local/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/ssh/telnet'
require 'wikk_configuration'
RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/wikk_conf.rb"

# SSH to the VDSL modem and run the command specified by the arguments passed.

@config = WIKK::Configuration.new("#{ARGV[0]}")

begin
  Net::SSH::Transport::Algorithms::ALGORITHMS[:encryption] = [ '3des-cbc', 'none' ]

  Net::SSH.start(@config.hostname, @config.admin_user, password: @config.admin_key) do |session|
    t = Net::SSH::Telnet.new('Session' => session, 'Prompt' => /^.*[>#] .*$/, 'Telnetmode' => false)

    # Check ip tables haven't reverted to dumb state, and fix if necessary
    @output = ''
    t.cmd( ARGV[1..-1].join(' ')) { |o| @output << o } # Found sometimes we get partial lines back.
    @output.each_line do |l|
      puts l
    end

    # Exit CLI
    t.puts 'exit'
  end
rescue StandardError => e
  puts "Error: #{e}"
end
