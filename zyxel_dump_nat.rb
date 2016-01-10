#!/usr/local/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/ssh/telnet'
require_relative '../rlib/configuration.rb' #need to replace with a gem

#Connects to the Zyxel VDSL modem and dumps the IP tables.

@config = Configuration.new('/usr/local/wikk/etc/keys/vdsl1.json')

begin
Net::SSH::Transport::Algorithms::ALGORITHMS[:encryption] = %w(3des-cbc none)

  Net::SSH.start(@config.hostname, @config.admin_user, :password => @config.admin_key) do |session|
    t = Net::SSH::Telnet.new("Session" => session, "Prompt" => /^.*[>#] .*$/, "Telnetmode" => false)

    #Get a shell
    t.cmd( 'echo && bash') 
    
    #Check ip tables haven't reverted to dumb state, and fix if necessary
    @output = ""
    t.cmd( 'iptables -t nat -L POSTROUTING --line-numbers')  { |o| @output << o } #Found sometimes we get partial lines back.
    @output.each_line do |l|
      puts l
    end

    #Exit sh
    t.puts 'exit'
    #Exit CLI
    t.puts 'exit'
  end
rescue Exception => error
puts "Error: #{error}"
end
