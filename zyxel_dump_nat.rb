#!/usr/local/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/ssh/telnet'
require 'wikk_configuration'
RLIB = '../../../rlib'
require_relative "#{RLIB}/wikk_conf.rb"

# Connects to the VDSL modem and dumps the IP tables.

@config = WIKK::Configuration.new("#{KEYS_DIR}/#{ARGV[0]}")

begin
  Net::SSH::Transport::Algorithms::ALGORITHMS[:encryption] = [ '3des-cbc', 'none' ]

  Net::SSH.start(@config.hostname, @config.admin_user, password: @config.admin_key) do |session|
    t = Net::SSH::Telnet.new('Session' => session, 'Prompt' => /^.*[>#] .*$/, 'Telnetmode' => false)

    # Get a shell
    t.cmd( 'echo && bash')

    # Check ip tables haven't reverted to dumb state, and fix if necessary
    @output = ''
    t.cmd( 'iptables -t nat -L POSTROUTING --line-numbers') { |o| @output << o } # Found sometimes we get partial lines back.
    @output.each_line do |l|
      puts l
    end

    # Exit sh
    t.puts 'exit'
    # Exit CLI
    t.puts 'exit'
  end
rescue StandardError => e
  puts "Error: #{e}"
end
