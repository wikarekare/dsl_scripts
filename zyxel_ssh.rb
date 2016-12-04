#!/usr/local/ruby2.2/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/ssh/telnet'
require_relative 'wikk_configuration' 

#SSH to the zyxel and run the command specified by the arguments passed.

@config = WIKK::Configuration.new('/usr/local/wikk/etc/keys/vdsl1.json')

begin  
Net::SSH::Transport::Algorithms::ALGORITHMS[:encryption] = %w(3des-cbc none)

  Net::SSH.start(@config.hostname, @config.admin_user, :password => @config.admin_key) do |session|
    t = Net::SSH::Telnet.new("Session" => session, "Prompt" => /^.*[>#] .*$/, "Telnetmode" => false)

    #Get a shell
    t.cmd( 'echo && bash') 
    
    #Check ip tables haven't reverted to dumb state, and fix if necessary
    @output = ""
    t.cmd( ARGV.join(' '))  { |o| @output << o } #Found sometimes we get partial lines back.
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
