#!/bin/sh

if [ -z "${DOWNLOAD-}" ]
then
	which curl >/dev/null && export DOWNLOAD="curl -sL" && rc=0 || rc=$?
	if [ "$rc" -ne 0 ]
	then
		which wget >/dev/null && export DOWNLOAD="wget -qO-" && rc=0 || rc=$?
	fi
	[ "$rc" -ne 0 ] && echo "ERROR: neither curl nor wget installed !" && exit 1
fi

export SH=`which bash`
if [ ! -z "${SH-}" ]
then
	export IS_BASH=1
	"$SH" -o errexit -o nounset -o pipefail "$@"
else
	export IS_BASH=0
	export SH="/bin/sh"
	sh -o errexit -o nounset "$@"
fi
