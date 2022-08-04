#!/usr/local/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/ssh/telnet'
require 'pp'
require 'wikk_configuration'
RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/wikk_conf.rb"

# NFV4 manual shows how to set up multiple routed subnets on the internal network
# unfortunately, it then sets up the ip Masquerade rule to only allow the subnet on the interface of the NFV4
# to connect to the internet.
#
# I run this every 3 minutes using cron on a server to update the iptable NAT MASQUERADE rule to work with multiple subnets.
# (this script is imbedded in another script that checks I can ping the NFV4, and the script has locking so only one instance of this code can ever run).
# This is really only needed when the router restarts, but I have no way to know when this happens, short of polling.
#
# An alternate fix would be to destination NAT. i.e put a NAT router between the internal subnets and the NFV4.

puts 'In NFV4 fix iptables'

@nf4v = WIKK::Configuration.new("#{ARGV[0]}")

# determine if we need to fix the NAT rules (hence also do other changes too)
def fix_nat_rule(line)
  line = line.strip
  if line =~ /^[0-9]+ +MASQUERADE +all +-- +#{@nf4v.local_lan} +anywhere/
    rule_number = line.split(' ')[0] # rubocop:disable Style/RedundantArgument
    return true, rule_number
  else
    return false, 0
  end
end

def fix_firewall(line)
  return line.strip == '1        0     0 VOIP_INPUT  udp  --  ppp2.1 *       0.0.0.0/0            114.23.248.105      udp dpt:5060'
end

# NFV4 has default passwords in the firmware, that are well known.
# These need changing each reboot, as they always revert.
def fix_passwords(t)
  puts 'changing default passwords'
  t.cmd( "echo -e \"#{@nf4v.support_key}\n#{@nf4v.support_key}\" | (passwd  support )" ) { |l| puts l }
  t.cmd("echo -e \"#{@nf4v.user_key}\n#{@nf4v.user_key}\" | (passwd  user )" ) { |l| puts l }
  t.cmd("echo -e \"#{@nf4v.nobody_key}\n#{@nf4v.nobody_key}\" | (passwd  nobody )") { |l| puts l }
end

# Next line limits encryption algorithms so packet size doesn't overflow NFV4 sshd, causing it to disconnect before authentication.
Net::SSH::Transport::Algorithms::ALGORITHMS[:encryption] = [ '3des-cbc', 'none' ]

begin
  Net::SSH.start(@nf4v.hostname, @nf4v.admin_user, password: @nf4v.admin_key) do |session|
    t = Net::SSH::Telnet.new('Session' => session, 'Prompt' => /^.*[>#] .*$/, 'Telnetmode' => false)

    # Get a shell
    t.cmd( 'echo && bash')

    # Check ip tables haven't reverted to dumb state, and fix if necessary
    @output = ''
    t.cmd( 'iptables -t nat -L POSTROUTING --line-numbers') { |o| @output << o } # Found sometimes we get partial lines back.
    @output.each_line do |l|
      r = fix_nat_rule(l)
      next unless r[0]

      puts 'fixing nat tables'
      t.cmd "iptables -t nat -D POSTROUTING #{r[1]}"
      t.cmd "iptables -t nat -A POSTROUTING -o #{@nf4v.ppp} -j MASQUERADE"
      # fix_passwords(t) #Assume we got here from a reboot, and the default user passwords are in affect again, so need fixing too.

      # Accept pings from anywhere
      t.cmd 'iptables -I INPUT 1 -p icmp  -j ACCEPT'

      # ADSL net addresses. Need to change these to service rules
      t.cmd "iptables -I INPUT 1 -p tcp -s #{@nf4v.local_lan} -j ACCEPT"
      t.cmd "iptables -I INPUT 1 -p udp -s #{@nf4v.local_lan} -j ACCEPT"

      @nf4v.admin_lans.each do |al|
        # Admin possible from these Net addresses. (Need to change these to service rules)
        t.cmd "iptables -I INPUT 1 -p tcp -s #{al} -j ACCEPT"
        t.cmd "iptables -I INPUT 1 -p udp -s #{al} -j ACCEPT"
      end
    end

    # Exit sh
    t.puts 'exit'
    # Exit CLI
    t.puts 'exit'
  end
rescue StandardError => e
  puts "Error: #{e}"
end
