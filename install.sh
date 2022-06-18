#!/bin/bash
HOST="admin2"
	scp zyxel_ssh.rb zyxel_dump_nat.rb zyxel_fix_iptables.rb root@${HOST}:/usr/local/wikk/sbin
