#!/bin/lsh

SH="/bin/lsh"

OFS=$IFS
IFS=$'\n'

function post_execute() {
	sleep 0.5
	
	if [[ ! -z "${WAIT_POST_EXECUTE-}" ]]
	then
		"$SH" -c "$WAIT_POST_EXECUTE"
	else
		if [[ -f "/usr/local/bin/post_execute/wait-ready.sh" ]]
		then
			/usr/local/bin/wait-ready.sh
		else
			sleep 5
		fi
	fi
	
	grep -e '^INITIALIZE=true$' /proc/*/environ && rc=0 || rc=$?
	[[ $rc -eq 0 ]] && INITIALIZE=true
		
	for var in $(set | awk "{ l=1 } !c && match(\$0, /^[^=]+=/) { print substr(\$0,0,RLENGTH-1); \$0=substr(\$0,RLENGTH+1); c=!match(\$0, /^((\”'\")|('[^']*'))*\$/); l=0 } l && c { c=!match(\$0, /^[^']*'((\”'\")|('[^']*'))*$/) }" | grep -E '^POST_EXECUTE|POST_EXECUTE_.*$' | sort)
	do
		echo
		echo "--- start script $var ----------------"
		eval SCRIPT=\$$var
		"$SH" -c "$SCRIPT" && rc=0 || rc=$?
		echo
		[[ $rc != 0 ]] && echo "ERROR: script failed with exit code $rc!" || echo "SUCCESS: script succeeded!"
		[[ $rc != 0 ]] && return 1
		echo "--- end script $var ------------------"
		echo
	done
	
	for file in $(find /usr/local/bin/post_execute -type f -maxdepth 1 \( -name "*.sh" -and ! -name "has*" -and ! -name "wait-ready.sh" \) 2>/dev/null || rc=$?)
	do
		echo
		echo "--- start script $file ----------------"
		"$SH" "$file" && rc=0 || rc=$?
		echo
		[[ $rc != 0 ]] && echo "ERROR: script failed with exit code $rc!" || echo "SUCCESS: script succeeded!"
		[[ $rc != 0 ]] && return 1
		echo "--- end script $file ------------------"
		echo
done
}

if [[ -f "/usr/local/bin/update_certs.sh" ]]
then
	"/usr/local/bin/update_certs.sh"
fi

for var in $(set | awk "{ l=1 } !c && match(\$0, /^[^=]+=/) { print substr(\$0,0,RLENGTH-1); \$0=substr(\$0,RLENGTH+1); c=!match(\$0, /^((\”'\")|('[^']*'))*\$/); l=0 } l && c { c=!match(\$0, /^[^']*'((\”'\")|('[^']*'))*$/) }" | grep -E '^PRE_EXECUTE|PRE_EXECUTE_.*$' | sort)
do
	echo
	echo "--- start script $var ----------------"
	eval SCRIPT=\$$var
	"$SH" -c "$SCRIPT" && rc=0 || rc=$?
	echo
	[[ $rc != 0 ]] && echo "ERROR: script failed with exit code $rc!" || echo "SUCCESS: script succeeded!"
	[[ $rc != 0 ]] && return 1
	echo "--- end script $var ------------------"
	echo
done

for file in $(ls -1 /usr/local/bin/pre_execute 2>/dev/null || rc=$?)
do
	echo
	echo "--- start script $file ----------------"
	"$SH" "$file" && rc=0 || rc=$?
	echo
	[[ $rc != 0 ]] && echo "ERROR: script failed with exit code $rc!" || echo "SUCCESS: script succeeded!"
	[[ $rc != 0 ]] && return 1
	echo "--- end script $file ------------------"
	echo
done

has_post_execute=$(set | awk "{ l=1 } !c && match(\$0, /^[^=]+=/) { print substr(\$0,0,RLENGTH-1); \$0=substr(\$0,RLENGTH+1); c=!match(\$0, /^((\”'\")|('[^']*'))*\$/); l=0 } l && c { c=!match(\$0, /^[^']*'((\”'\")|('[^']*'))*$/) }" | grep -E '^POST_EXECUTE|POST_EXECUTE_.*$' | wc -l)

if [[ "$has_post_execute" -eq 0 ]
then
	i=0
	for file in $(find /usr/local/bin/post_execute -type f -maxdepth 1 -name "has_*.sh")
	do
		has_post_execute=$($file && rc=0 || rc=$?)
		[[ "$rc" -ne 0 ]] && echo "ERROR: script '$file' failed!" && exit 1
		[[ "$has_post_execute" -ne 0 ]] && break
		i=$((i+1))
	done
	[[ "$i" -eq 0 ]] && has_post_execute=1
fi


if [[ "$has_post_execute" -gt 0 ]]
then
	post_execute &
fi

if [[ -z "${STARTUP_USER-}" ]]
then
	if [[ ! -z "${STARTUP-}" ]]
	then
		"$SH" -c "$STARTUP" && rc=0 || rc=$?
	else
		f="/usr/local/bin/startup.sh" 
		if [[ -f "$f" ]] then
			"$SH" "$f" && rc=0 || rc=$?
		else
			tail -f /dev/null
		fi
	fi
else
	if [[ ! -z "${STARTUP-}" ]]
	then
		su -s "$SH" "$STARTUP_USER" -c "$STARTUP" && rc=0 || rc=$?
	else
		f="/usr/local/bin/startup/startup.sh" "$@"
		if [[ -f "$f" ]] then
			su -s "$SH" "$STARTUP_USER" "$f" && rc=0 || rc=$?
		else
			tail -f /dev/null
		fi
	fi
fi
[[ $rc != 0 ]] && echo "ERROR: script failed with exit code $rc!" || echo "SUCCESS: script succeeded!"
[[ $rc != 0 ]] && exit 1

IFS=$OFS
