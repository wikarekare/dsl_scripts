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
  host_key = [ 'ssh-dss', 'none' ]
  kex = Net::SSH::Transport::Algorithms::ALGORITHMS[:kex] + [ 'diffie-hellman-group1-sha1' ]
  # Next line limits encryption algorithms so packet size doesn't overflow NFV4 sshd, causing it to disconnect before authentication.
  encryption = [ '3des-cbc', 'none' ]

  Net::SSH.start(@config.hostname, @config.admin_user, password: @config.admin_key, encryption: encryption, kex: kex, host_key: host_key) do |session|
    Net::SSH::Telnet.new('Session' => session, 'Prompt' => /^> .*$/, 'Telnetmode' => false)
  end
rescue StandardError => e
  puts "Error: #{e}"
end
