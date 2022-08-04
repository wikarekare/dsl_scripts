#!/usr/local/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/ssh/telnet'
require 'pp'
require 'wikk_configuration'
RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/wikk_conf.rb"

# Zyxel VMG8324-B10A manual shows how to set up multiple routed subnets on the internal network
# unfortunately, it then sets up the ip Masquerade rule to only allow the subnet on the interface of the Zyxel
# to connect to the internet.
#
# I run this every 3 minutes using cron on a server to update the iptable NAT MASQUERADE rule to work with multiple subnets.
# (this script is imbedded in another script that checks I can ping the zyxel, and the script has locking so only one instance of this code can ever run).
# This is really only needed when the router restarts, but I have no way to know when this happens, short of polling.
#
# An alternate fix would be to double NAT. i.e put a NAT router between the internal subnets and the Zyxel.

puts 'In Zyxel fix iptables'

@zyxel = WIKK::Configuration.new("#{ARGV[0]}")

# determine if we need to fix the NAT rules (hence also do other changes too)
def fix_nat_rule(line)
  line = line.strip
  if line =~ /^[0-9]+    MASQUERADE  all  --  #{@zyxel.local_lan}     anywhere/
    rule_number = line.split[0]
    return true, rule_number
  else
    return false, 0
  end
end

def fix_firewall(line)
  return line.strip == '1        0     0 VOIP_INPUT  udp  --  ppp2.1 *       0.0.0.0/0            114.23.248.105      udp dpt:5060'
end

# Zyxel has default passwords in the firmware, that are well known.
# These need changing each reboot, as they always revert.
def fix_passwords(t)
  puts 'changing default passwords'
  t.cmd("echo -e \"#{@zyxel.zyuser_key}\n#{@zyxel.zyuser_key}\" | (passwd  zyuser )" ) { |l| puts l }
  t.cmd( "echo -e \"#{@zyxel.support_key}\n#{@zyxel.support_key}\" | (passwd  support )" ) { |l| puts l }
  t.cmd("echo -e \"#{@zyxel.supervisor_key}\n#{@zyxel.supervisor_key}\" | (passwd  supervisor )") { |l| puts l }
  t.cmd("echo -e \"#{@zyxel.user_key}\n#{@zyxel.user_key}\" | (passwd  user )" ) { |l| puts l }
end

def fix_routes(t)
  puts 'Add private address range routes'
  # Add local route, as saving settings is failing
  t.cmd "route add -net 192.168.0.0 netmask 255.255.0.0 gw #{GATE_DSL}"
  t.cmd "route add -net 172.16.0.0 netmask 255.240.0.0 gw #{GATE_DSL}"
  t.cmd "route add -net 10.0.0.0 netmask 255.0.0.0 gw #{GATE_DSL}"
  t.cmd "route add -net 100.64.0.0 netmask 255.192.0.0 gw #{GATE_DSL}"
  t.cmd 'route -n'
end
# Next line limits encryption algorithms so packet size doesn't overflow Zyxel sshd, causing it to disconnect before authentication.
Net::SSH::Transport::Algorithms::ALGORITHMS[:encryption] = [ '3des-cbc', 'none' ]

begin
  Net::SSH.start(@zyxel.hostname, @zyxel.admin_user, password: @zyxel.admin_key) do |session|
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
      t.cmd "iptables -t nat -A POSTROUTING -o #{@zyxel.ppp} -j MASQUERADE"
      fix_passwords(t) # Assume we got here from a reboot, and the default user passwords are in affect again, so need fixing too.
      fix_routes(t)
      #      end
      # if fix_firewall
      # puts 'Fix Firewall rules'
      # Drop the VOIP rules put in by the firmware
      puts '  Drop the VOIP rules'
      t.cmd 'iptables -D INPUT 1'
      t.cmd 'iptables -D FORWARD 1'

      # Drop everything from outside
      t.cmd 'iptables -I INPUT 1 -i ppp2.1 -p tcp -j DROP'
      t.cmd 'iptables -I INPUT 1 -i ppp2.1 -p udp -j DROP'

      # Accept pings from anywhere
      t.cmd 'iptables -I INPUT 1 -p icmp  -j ACCEPT'

      # ADSL net addresses. Need to change these to service rules
      t.cmd "iptables -I INPUT 1 -p tcp -s #{@zyxel.local_lan} -j ACCEPT"
      t.cmd "iptables -I INPUT 1 -p udp -s #{@zyxel.local_lan} -j ACCEPT"

      @zyxel.admin_lans.each do |al|
        # Admin possible from these Net addresses. (Need to change these to service rules)
        t.cmd "iptables -I INPUT 1 -p tcp -s #{al} -j ACCEPT"
        t.cmd "iptables -I INPUT 1 -p udp -s #{al} -j ACCEPT"
      end

      # Drop from others inside the network
      t.cmd 'iptables -I INPUT 7 -p tcp -i br+  -j DROP'
      t.cmd 'iptables -I INPUT 7 -p udp -i br+  -j DROP'

      # Correct the SERVICE Control rule for www
      t.cmd 'iptables  -R SERVICE_CONTROL 1 -p tcp -i br+ --dport 80 -j ACCEPT'
    end

    # Exit sh
    t.puts 'exit'
    # Exit CLI
    t.puts 'exit'
  end
rescue StandardError => e
  puts "Error: #{e}"
end
