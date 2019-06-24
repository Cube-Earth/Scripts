#!/bin/sh

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
IFS=$OFS
