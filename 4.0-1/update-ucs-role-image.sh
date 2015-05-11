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

# Run univention-upgrade on a generic UCS Docker Container to get a new layer

argv0="$0"
usage() {
	echo >&2 "usage: $argv0 [--debug]"
	exit 1
}

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
			break;
			;;
		*)
			usage;
			;;
	esac
done

if [ -n "$debug" ]; then
	set -x
fi

univention-config-registry set server/role?generic

eval "$(ucr shell \
	server/role version/version version/patchlevel)"

updateto="$version_version-$((version_patchlevel+1))"
univention_updater_options+=("--updateto=$updateto" --noninteractive)

## Wait for ((UCR committed resolv.conf) and (runlevel 2))
echo -n "INFO: Waiting for container runlevel 2 "
for ((i=0;i<30;i++)); do
	sleep 1
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

i=0
until host "$(ucr get repository/online/server)" >/dev/null 2>&1; do
	sleep 1
	i=$((i+1))
	if [ $i -gt 10 ]; then
		eval "$(ucr shell repository/online/server)"
		echo "ERROR: Container cannot resolve $repository_online_server"
		exit 1
	fi
done

## Run the update
/usr/share/univention-updater/univention-updater net "${univention_updater_options[@]}"

apt-get clean
