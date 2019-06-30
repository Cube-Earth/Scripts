#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

[[ -f /bin/bash ]] && SH=/bin/bash || SH=/bin/sh

OFS=$IFS
IFS=$'\n'

for var in $(set | awk "{ l=1 } !c && match(\$0, /^[^=]+=/) { print substr(\$0,0,RLENGTH-1); \$0=substr(\$0,RLENGTH+1); c=!match(\$0, /^((\”'\")|('[^']*'))*\$/); l=0 } l && c { c=!match(\$0, /^[^']*'((\”'\")|('[^']*'))*$/) }" | grep -E '^PRE_EXECUTE|PRE_EXECUTE_.*$' | sort)
do
	echo
	echo "--- start script $var ----------------"
	eval SCRIPT=\$$var
	"$SH" -c "$SCRIPT" && rc=0 || rc=$?
	echo
	[[ $rc != 0 ]] && echo "ERROR: script failed with exit code $rc!" || echo "SUCCESS: script succeeded!"
	echo "--- end script $var ------------------"
	echo
done

for file in $(ls -1 /usr/local/bin/startup | grep -v "startup.sh" 2>/dev/null || rc=$?)
do
	echo
	echo "--- start script $file ----------------"
	"$file" && rc=0 || rc=$?
	echo
	[[ $rc != 0 ]] && echo "ERROR: script failed with exit code $rc!" || echo "SUCCESS: script succeeded!"
	echo "--- end script $file ------------------"
	echo
done


if [[ -z "${STARTUP_USER-}" ]]
then
	if [[ ! -z "${STARTUP_SCRIPT-}" ]]
	then
		"$SH" -c "$SCRIPT" && rc=0 || rc=$?
	else
		f="/usr/local/bin/startup/startup.sh" 
		if [[ -f "$f" ]] then
			chmod +x "$f"
			"$f" && rc=0 || rc=$?
		else
			tail -f /dev/null
		fi
	fi
else
	if [[ ! -z "${STARTUP-}" ]]
	then
		su -s "$SH" "$STARTUP_USER" -c "$SCRIPT" && rc=0 || rc=$?
	else
		f="/usr/local/bin/startup/startup.sh" 
		if [[ -f "$f" ]] then
			chmod +x "$f"
			su -s "$SH" "$STARTUP_USER" "$f" && rc=0 || rc=$?
		else
			tail -f /dev/null
		fi
	fi
fi

IFS=$OFS

