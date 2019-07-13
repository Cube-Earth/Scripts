#!/bin/sh
export SH=`which bash`
if [[ ! -z "${SH-}" ]]
then
	export IS_BASH=1
	"$SH" -o errexit -o nounset -o pipefail "$@"
else
	export IS_BASH=0
	export SH="/bin/sh"
	sh -o errexit -o nounset "$@"
fi
