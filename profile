export PATH=${PATH:-"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"}

export EDITOR=vim
export PAGER=less
umask 022

# use nicer PS1 for bash and busybox ash
if [ -n "$BASH_VERSION" -o "$BB_ASH_VERSION" ]; then
	PS1='\h:\w\$ '
# use nicer PS1 for zsh
elif [ -n "$ZSH_VERSION" ]; then
	PS1='%m:%~%# '
# set up fallback default PS1
else
	: "${HOSTNAME:=$(hostname)}"
	PS1='${HOSTNAME%%.*}:$PWD'
	[ "$(id -u)" -eq 0 ] && PS1="${PS1}# " || PS1="${PS1}\$ "
fi

for script in /etc/profile.d/*.sh ; do
	if [ -r "$script" ] ; then
		. "$script"
	fi
done
unset script
PATH=${PATH:-"/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin"}

PS1="\033[1m\033[31mRosetta Internal:\033[33m\w> \033[0m"

clear
echo ""
fortune
echo ""
