#!/usr/local/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/ssh/telnet'
require 'wikk_configuration'

unless defined? WIKK_CONF
  load '/wikk/etc/wikk.conf'
end

# SSH to the VDSL Modem and run the command specified by the arguments passed.

@config = WIKK::Configuration.new("#{ARGV[0]}")

begin
  # Reduce the transport algorithms, as our box crashes when sent too many.
  kex = Net::SSH::Transport::Algorithms::ALGORITHMS[:kex] + [ 'diffie-hellman-group1-sha1' ]
  encryption = [ '3des-cbc', 'none' ]

  Net::SSH.start(@config.hostname, @config.admin_user, password: @config.admin_key, encryption: encryption, kex: kex) do |session|
    t = Net::SSH::Telnet.new('Session' => session, 'Prompt' => /^.*[>#] .*$/, 'Telnetmode' => false)

    # Get a shell
    t.cmd( 'echo && bash')

    # Check ip tables haven't reverted to dumb state, and fix if necessary
    @output = ''
    t.cmd( ARGV[1..-1].join(' ')) { |o| @output << o } # Found sometimes we get partial lines back.
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
