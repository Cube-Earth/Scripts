#!/bin/lsh

cd /tmp

SCRIPT_DIR="$(dirname "$0")"

SH="/bin/lsh"

OFS=$IFS
IFS=$'\n'


function handleInteractiveShell
{
	if [[ ! -t 0 ]]
	then
		echo "INFO: Container started non-interactively."
	else
		echo "WARN: Container started interactively. Waiting for SIGWINCH to prevent errors!"
		trap "CONSUMED=1; echo 'INFO: SIGWINCH received. Continuing startup ...'" WINCH
		n=${2-15}
		while [[ "$n" -gt 0 ]] && [[ -z "$CONSUMED" ]]
		do
			sleep 0.2
			n=$((n-1))
		done
		if [[ -z "${CONSUMED-}" ]]
		then
			trap - WINCH
			echo "BOGUS: No SIGWINCH received. Nevertheless continuing startup ..."
		fi
	fi
}


function post_execute() {
	sleep 0.5
	
	if [[ ! -z "${WAIT_POST_EXECUTE-}" ]]
	then
		"$SH" -c "$WAIT_POST_EXECUTE"
	else
		if [[ -f "/opt/post_execute/wait-ready.sh" ]]
		then
			/opt/post_execute/wait-ready.sh
		else
			sleep 5
		fi
	fi
	
#	n=$(grep -e '^INITIALIZE=true$' /proc/*/environ 2>/dev/null | wc -l || rc=$?)
#	[[ "$n" -gt 0 ]] && export INITIALIZE=true
	[[ -f /run/initialize.state ]] && export INITIALIZE=true
		
	for var in $(set | awk "{ l=1 } !c && match(\$0, /^[^=]+=/) { print substr(\$0,0,RLENGTH-1); \$0=substr(\$0,RLENGTH+1); c=!match(\$0, /^((\”'\")|('[^']*'))*\$/); l=0 } l && c { c=!match(\$0, /^[^']*'((\”'\")|('[^']*'))*$/) }" | grep -E '^POST_EXECUTE|POST_EXECUTE_.*$' | sort || rc=$?)
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
	
	for file in $(find /opt/post_execute -type f -maxdepth 1 \( -name "*.sh" -and ! -name "has_*" -and ! -name "has-*" -and ! -name "wait-ready.sh" \) 2>/dev/null || rc=$?)
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

function createStartupCommand
{
	local cmd=""
	
	[ ! -z "${STARTUP-}" ] && echo "$STARTUP" > /tmp/startup.sh && chmod +x /tmp/startup.sh && cmd="/tmp/startup.sh" "$@"

	[ -z "$cmd" ] && [ -f "/opt/startup/startup.sh" ] && cmd="/opt/startup/startup.sh" "$@"
	[ ! -z "$cmd" ] && [ ! -z "${STARTUP_USER-}" ] && cmd="su -s \"$SH\" \"$STARTUP_USER\" $cmd"
	[ ! -z "$cmd" ] && [ -z "${STARTUP_USER-}" ] && cmd="\"$SH\" $cmd"
	[ -z "$cmd" ] && cmd="tail -f /dev/null"
	
	echo $cmd
}


handleInteractiveShell

[[ -f /run/initialize.state ]] && rm /run/initialize.state

if [[ -f "/usr/local/bin/update-certs.sh" ]]
then
	"/usr/local/bin/update-certs.sh"
fi

"$SCRIPT_DIR/executeActions.sh"


for var in $(set | awk "{ l=1 } !c && match(\$0, /^[^=]+=/) { print substr(\$0,0,RLENGTH-1); \$0=substr(\$0,RLENGTH+1); c=!match(\$0, /^((\”'\")|('[^']*'))*\$/); l=0 } l && c { c=!match(\$0, /^[^']*'((\”'\")|('[^']*'))*$/) }" | grep -E '^PRE_EXECUTE|PRE_EXECUTE_.*$' | sort || rc=$?)
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

for file in $(ls -1 /opt/pre_execute 2>/dev/null || rc=$?)
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

has_post_execute=$(set | awk "{ l=1 } !c && match(\$0, /^[^=]+=/) { print substr(\$0,0,RLENGTH-1); \$0=substr(\$0,RLENGTH+1); c=!match(\$0, /^((\”'\")|('[^']*'))*\$/); l=0 } l && c { c=!match(\$0, /^[^']*'((\”'\")|('[^']*'))*$/) }" | grep -E '^POST_EXECUTE|POST_EXECUTE_.*$' | wc -l || rc=$?)

if [[ "$has_post_execute" -eq 0 ]]
then
	i=0
	for file in $(find /opt/post_execute -type f -maxdepth 1 \( -name "has_*.sh" -or -name "has-*.sh" \) || rc=$?)
	do
		has_post_execute=$("$SH" "$file")
		rc=$?
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


eval $(createStartupCommand) && rc=0 || rc=$?
[[ $rc != 0 ]] && echo "ERROR: script failed with exit code $rc!" || echo "SUCCESS: script succeeded!"
[[ $rc != 0 ]] && exit 1

IFS=$OFS
