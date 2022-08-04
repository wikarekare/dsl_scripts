# DSL_Scripts

scripts to update zyxel and nf4v iptables, change default passwords and issue random shell commands through ssh.

##zyxel_fix_ip_tables.rb and nf4v_fix_iptables

Zyxel VMG8324-B10A and the NF4V manuals show how to set up multiple routed subnets on the internal network.
Unfortunately, they then sets up the ip Masquerade rule to only allow the subnet directly on the interface of the modem,
to connect to the internet.

This script is really only needed when the router restarts, but I have no way to know when this happens, short of polling.
I run this every 3 minutes using cron on a server to update the iptable NAT MASQUERADE rule to work with multiple subnets.
 (this script is imbedded in another script that checks I can ping the modem, and the script has locking so only one instance of this code can ever run).

An alternate fix would be to double NAT. i.e put a NAT router between the internal subnets and the modem (or get a better modem).

The modem also has default passwords in the firmware, that are well known, and can't be changed. I use the same script to change these each reboot.

I also set up iptable rules to allow only specified internal networks to connect to the modem itself, and deny all external connections to the modem. This does not stop traffic that is forwarded to/from the Internet.

A json config file with the keys for the modem has the form:
```
zyxel.json
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
nf4v.json
{
  "admin_user": "admin",
  "admin_key":  "random-pwd-1",
  "support_key": "random-pwd-2",
  "user_key": "random-pwd-3",
  "nobody_key": "random-pwd-4",
  "ppp": "ppp0.1",
  "hostname": "host.domain",
  "local_lan": "192.168.1.0/24",
  "admin_lans": [""192.168.2.0/24","10.0.1.0/24"]
}
```
**Nb.** *Depends on wikk_configuration gem*

##dump_nat.rb <conf_file>

Runs  
`bash_cmd <conf_file> "iptables -t nat -L POSTROUTING --line-numbers'"`

##bash_cmd.rb <conf_file>

Runs arbitrary linux command, taken from the arguments and passed to modem via ssh

##console_cmd.rb <conf_file>

Runs arbitrary menu command, taken from the arguments and passed to modem via ssh
