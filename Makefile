all:
	echo "Only valid option is make install"

install:
	install zyxel_ssh.rb zyxel_dump_nat.rb zyxel_fix_iptables.rb /usr/local/wikk/sbin
