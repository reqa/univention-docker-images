#!/bin/bash
#
# Copyright 2015 Univention GmbH
#
# http://www.univention.de/
#
# All rights reserved.
#
# The source code of this program is made available
# under the terms of the GNU Affero General Public License version 3
# (GNU AGPL V3) as published by the Free Software Foundation.
#
# Binary versions of this program provided by Univention to you as
# well as other copyrighted, protected or trademarked materials like
# Logos, graphics, fonts, specific documentations and configurations,
# cryptographic keys etc. are subject to a license agreement between
# you and Univention and not subject to the GNU AGPL V3.
#
# In the case you use this program under the terms of the GNU AGPL V3,
# the program is provided in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License with the Debian GNU/Linux or Univention distribution in file
# /usr/share/common-licenses/AGPL-3; if not, see
# <http://www.gnu.org/licenses/>.

argv0="$0"
usage() {
	echo >&2 "usage: $argv0 <univention-role>"
	echo >&2 "e.g.:  $argv0 member"
	exit 1
}

if [ $# -lt 1 ]; then
	usage
fi

opttemp=$(getopt --options '+h' --longoptions 'debug,help' --name "$argv0" -- "$@")
eval set -- "$opttemp"
unset opttemp

unset debug
while true; do
	case "$1" in
		--debug)
			debug=1
			shift;
			;;
		--help)
			usage;
			;;
		--)
			shift;
			break
			;;
		*)
			usage;
			;;
	esac
done

if [ -n "$debug" ]; then
	set -x
fi

ucr_settings=()
system_role="$1"
install_packages=("univention-container-role-server-common")
case "$system_role" in
	master|server-master)
		system_role="master"
		ucr_settings+=("server/role=domaincontroller_master")
		install_packages+=("univention-server-master")
		shift;
		;;
	backup|server-backup)
		system_role="backup"
		ucr_settings+=("server/role=domaincontroller_backup")
		install_packages+=("univention-server-backup")
		shift;
		;;
	slave|server-slave)
		system_role="slave"
		ucr_settings+=("server/role=domaincontroller_slave")
		install_packages+=("univention-server-slave")
		shift;
		;;
	member|memberserver|server-member)
		system_role="member"
		ucr_settings+=("server/role=memberserver")
		install_packages+=("univention-server-member")
		shift;
		;;
	basesystem)
		system_role="basesystem"
		install_packages=("univention-container-basesystem")	## only this
		shift;
		;;
	*)
		echo "ERROR: unknown system role";
		usage;
		;;
esac

## Wait for ((UCR committed resolv.conf) and (runlevel 2))
echo -n "INFO: Waiting for container runlevel 2 "
for ((i=0;i<30;i++)); do
	sleep 1	## first wait, the /sbin/init wrapper needs to reset utmp
	echo -n "."
	read clvl rlvl < <(/sbin/runlevel)
	if [ "$rlvl" = 2 ]; then
		break 2
	fi
done
if [ "$i" -eq 30 ]; then
	echo "Timeout"
	exit 1
else
	echo "Ok"
fi

## Univention: Install role package
export DEBIAN_FRONTEND=noninteractive

ucr_settings+=(
repository/online=true
repository/online/server=univention-repository.knut.univention.de
repository/online/component/ucs-container=enabled
repository/online/component/ucs-container/unmaintained=yes
system/setup/boot/pkgcache=false
system/setup/boot/start=false
)

/usr/sbin/univention-config-registry set "${ucr_settings[@]}"

apt-get update \
	&& apt-get install -y univention-docker-container-mode \
	&& apt-get install -y ${install_packages[@]} \
	&& apt-get install -y --no-install-recommends univention-system-setup-boot univention-management-console \
	&& apt-get install -y smbclient curl

## additionally hide the role dialog in system setup and set locale for system setup:
/usr/sbin/univention-config-registry set \
	system/setup/boot/pages/blacklist="role SoftwarePage" \
	locale="de_DE.UTF-8:UTF-8 en_US.UTF-8:UTF-8"

## Univention: Cleanup: remove policy-rc.d blocker and clean apt stuff
apt-get autoremove -y
ucr set repository/online/server=updates.software-univention.de
apt-get update
apt-get clean && find /var/lib/apt/lists -type f -exec rm {} +
