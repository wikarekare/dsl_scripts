# zyxel-VMG8324-B10A-tools

scripts to update zyxel's iptables, change default passwords and issue random shell commands through ssh.

##zyxel_fix_ip_tables.rb_
Zyxel VMG8324-B10A manual shows how to set up multiple routed subnets on the internal network 
unfortunately, it then sets up the ip Masquerade rule to only allow the subnet directly on the interface of the Zyxel,
to connect to the internet.

This is really only needed when the router restarts, but I have no way to know when this happens, short of polling.
I run this every 3 minutes using cron on a server to update the iptable NAT MASQUERADE rule to work with multiple subnets.
 (this script is imbedded in another script that checks I can ping the zyxel, and the script has locking so only one instance of this code can ever run). 

An alternate fix would be to double NAT. i.e put a NAT router between the internal subnets and the Zyxel. 

The Zyxel also has default passwords in the firmware, that are well known, and can't be changed. I use the same script to change these each reboot.

I also set up iptable rules to allow only specified internal networks to connect to the Zyxel itself, and deny all external connections to the Zyxel. This does not stop traffic that is forwarded to/from the Internet.

A json config file with the keys for the Zyxel has the form:

{
  "admin_user": "admin",
  "admin_key":  "random-pwd-1",
  "zyuser_key": "random-pwd-2",
  "support_key": "random-pwd-3",
  "supervisor_key": "random-pwd-4",
  "user_key": "random-pwd-5",
  "ppp": "ppp2.1",
  "hostname": "host.domain",
  "local_lan": "192.168.1.0/24"
  "admin_lans": ["192.168.2.0/24","10.0.1.0/24]
}

Depends on configuration.rb

##zyxel_dump_nat.rb

Runs  "iptables -t nat -L POSTROUTING --line-numbers'" on the Zyxel

##zyxel_ssh.rb

Runs arbitrary command, taken from the arguments passed to zyxel_ssh.rb


