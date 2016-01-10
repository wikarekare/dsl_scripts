#!/usr/local/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/ssh/telnet'
require 'yaml'
require 'pp'
require_relative '../rlib/configuration.rb' #need to replace with a gem

#Zyxel VMG8324-B10A manual shows how to set up multiple routed subnets on the internal network 
#unfortunately, it then sets up the ip Masquerade rule to only allow the subnet on the interface of the Zyxel
#to connect to the internet.
#
#I run this every 3 minutes using cron on a server to update the iptable NAT MASQUERADE rule to work with multiple subnets.
# (this script is imbedded in another script that checks I can ping the zyxel, and the script has locking so only one instance of this code can ever run). 
#This is really only needed when the router restarts, but I have no way to know when this happens, short of polling.
#
#An alternate fix would be to double NAT. i.e put a NAT router between the internal subnets and the Zyxel. 

#puts "In Zyxel fix iptables"

@zyxel = Configuration.new('/usr/local/wikk/etc/keys/vdsl1.json')

#determine if we need to fix the NAT rules (hence also do other changes too)
def fix_nat_rule(line)
  line = line.strip
  if line =~ /^[0-9]+    MASQUERADE  all  --  #{@zyxel.local_lan}     anywhere/
    rule_number = line.split(' ')[0]
    return true, rule_number
  else
    return false, 0
  end
end

def fix_firewall(line)
  return line.strip == "1        0     0 VOIP_INPUT  udp  --  ppp2.1 *       0.0.0.0/0            114.23.248.105      udp dpt:5060"
end

#Zyxel has default passwords in the firmware, that are well known. 
#These need changing each reboot, as they always revert.
def fix_passwords(t)
  t.cmd("echo -e \"#{@zyxel.zyuser_key}\n#{@zyxel.zyuser_key}\" | (passwd  zyuser )" ) { |l| puts l }
  t.cmd( "echo -e \"#{@zyxel.support_key}\n#{@zyxel.support_key}\" | (passwd  support )" ) { |l| puts l }
  t.cmd("echo -e \"#{@zyxel.supervisor_key}\n#{@zyxel.supervisor_key}\" | (passwd  supervisor )")  { |l| puts l }
  t.cmd("echo -e \"#{@zyxel.user_key}\n#{@zyxel.user_key}\" | (passwd  user )" ) { |l| puts l }
end

#Next line limits encryption algorithms so packet size doesn't overflow Zyxel sshd, causing it to disconnect before authentication.
Net::SSH::Transport::Algorithms::ALGORITHMS[:encryption] = %w(3des-cbc none)

begin
  Net::SSH.start(@zyxel.hostname, @zyxel.admin_user, :password => @zyxel.admin_key) do |session|
    t = Net::SSH::Telnet.new("Session" => session, "Prompt" => /^.*[>#] .*$/, "Telnetmode" => false)

    #Get a shell
    t.cmd( 'echo && bash') 
    
    #Check ip tables haven't reverted to dumb state, and fix if necessary
    @output = ""
    t.cmd( 'iptables -t nat -L POSTROUTING --line-numbers')  { |o| @output << o } #Found sometimes we get partial lines back.
    @output.each_line do |l|
      r = fix_nat_rule(l)
      if r[0]
        puts "fixing nat tables"
        t.cmd "iptables -t nat -D POSTROUTING #{r[1]}"
        t.cmd "iptables -t nat -A POSTROUTING -o #{@zyxel.ppp} -j MASQUERADE"
        fix_passwords(t) #Assume we got here from a reboot, and the default user passwords are in affect again, so need fixing too.
#      end
      #if fix_firewall 
        #Drop the VOIP rules put in by the firmware
        t.cmd "iptables -D INPUT 1"
        t.cmd "iptables -D FORWARD 1"

        #Drop everything from outside
        t.cmd "iptables -I INPUT 1 -i ppp2.1 -p tcp -j DROP"
        t.cmd "iptables -I INPUT 1 -i ppp2.1 -p udp -j DROP"

        #Accept pings from anywhere
        t.cmd "iptables -I INPUT 1 -p icmp  -j ACCEPT"

        #ADSL net addresses. Need to change these to service rules
        t.cmd "iptables -I INPUT 1 -p tcp -s #{@zyxel.local_net} -j ACCEPT"
        t.cmd "iptables -I INPUT 1 -p udp -s #{@zyxel.local_net} -j ACCEPT"

        @zyxel.admin_lans.each do |l| 
          #Admin possible from these Net addresses. (Need to change these to service rules)
          t.cmd "iptables -I INPUT 1 -p tcp -s #{l} -j ACCEPT"
          t.cmd "iptables -I INPUT 1 -p udp -s #{l} -j ACCEPT"
        end
        
        #Drop from others inside the network
        t.cmd "iptables -I INPUT 7 -p tcp -i br+  -j DROP"
        t.cmd "iptables -I INPUT 7 -p udp -i br+  -j DROP"

        #Correct the SERVICE Control rule for www
        t.cmd "iptables  -R SERVICE_CONTROL 1 -p tcp -i br+ --dport 80 -j ACCEPT"
      end
    end
        
    #Exit sh
    t.puts 'exit'
    #Exit CLI
    t.puts 'exit'
  end
rescue Exception => error
  puts "Error: #{error}"
end
