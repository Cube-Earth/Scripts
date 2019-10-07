#!/bin/bash
set -o errexit
set -o nounset

export ACTIONS_SAMPLE='--- createGroup;admins;5000
--- createUser;admin1;5001;admins
--- createSambaUser;admin2;5002;admins
--- createFile;/tmp/test.txt
abc
def


ghi


--- appendFile;/tmp/test2.txt;admin1:admins;777
ghi
jkl
--- ###; Comment
--- exec;do anything
echo "hello world!"
--- pipe;grep success
failed
error
success
warning
'

#ACTIONS="$ACTIONS_SAMPLE"; PWD_admin1="abc"; PWD_admin2="def"


function extractDelim {
	local arr
	IFS=' ' read -ra arr << EOF
$line
EOF
	if [ "${#arr[@]}" -le 1 ] || [ "${#arr[0]-}" -eq 0 ]
	then
		echo "ERROR: missing or malformed action definitions!"
		return 1
	fi 
	delim="${arr[0]} "
}

function extractActionParams {
	local arr
	IFS=';' read -ra arr << EOF
$line
EOF
	action="${arr[0]}"
	path="${arr[1]}"
	owner="${arr[2]-}"
	perm="${arr[3]-}"
	params=( "${arr[@]}" )
}


function createUser {
	opts=""
	[ ! -z "${params[2]-}" ] && opts="$opts -u \"${params[2]-}\""  # uid
	[ ! -z "${params[3]-}" ] && opts="$opts -g \"${params[3]-}\""  # primary group (gid or name)
	[ ! -z "${params[4]-}" ] && opts="$opts -g \"${params[4]-}\""  # list pf supplementary groups
	
	pwd=$(eval echo \$\{PWD_$path\-})
	if [ -z "$pwd" ]
	then
		pwd=$(curl -Ls https://pod-cert-server/pwd/$path)
		if [ -z "$pwd" ]
		then
			echo "ERROR: could not retrieve password from Pod Cert Server!"
			return 1
		fi
	fi
	opts="$opts -p '$(echo "$pwd" | openssl passwd -1 -stdin)'"
			
	if [ ! -z "${params[5]-}" ]    # backdoor
	then
		opts="$opts \"${params[5]-}\""
	else
		opts="$opts -M -s /sbin/nologin"
	fi

	if cat /etc/passwd | grep -e "^$path:" > /dev/null 2>&1
	then
		echo "user '$path' does already exist!"
	else
		eval useradd $opts "$path"
	fi		
}


function showHeader {
	echo
	echo "####################################################################"
	echo "### $currLine"
	echo "####################################################################"
	echo
}

function processAction {
	[ -z "$action" ] && return
	
	case "$action" in
		createGroup)
			showHeader
			cat /etc/group | grep -e "^$path:" > /dev/null 2>&1 && rc=0 || rc=$?
			if [ $rc -ne 0 ]
			then
				gid="${params[2]-}"
				[ -z "$gid" ] && groupadd "$path" || groupadd -g "$gid" "$path"
			else
				echo "group '$path' does already exist!"
			fi		
			;;

		createUser)
			showHeader
			createUser
			;;
	
		createSambaUser)
			showHeader
			createUser
			echo -e "$pwd\n$pwd\n" | smbpasswd -a "$path"
			smbpasswd -e "$path"
			;;

		createFile)
			showHeader
			echo "$cnt" > "$path"
			[ ! -z "$owner" ] && chown "$owner" "$path" || rc=$?
			[ ! -z "$perm" ] && chmod "$perm" "$path" || rc=$?
			;;

		appendFile)
			showHeader
			echo "$cnt" >> "$path"
			[ ! -z "$owner" ] && chown "$owner" "$path"
			[ ! -z "$perm" ] && chmod "$perm" "$path"
			;;

		createDir|createDirectory)
			showHeader
			mkdir -p "$path"
			[ ! -z "$owner" ] && chown -R "$owner" "$path"
			[ ! -z "$perm" ] && chown -R "$perm" "$path"
			;;
			
		exec)
			showHeader
			"$SHELL" -o errexit -o nounset -c "$cnt" || return $?
			;;
			
		pipe)
			showHeader
			echo "$cnt" | eval "$path" || return $?
			;;

		'#'*)
			;;
			
		*)
			showHeader
			echo "ERROR: unkown action '$action'!"
			return 1
			;;

	esac
}

function processAll {
	[ -z "${ACTIONS-}" ] && echo "nothing to do!" && return

	action=""
	lf=0
	cnt=""
	IFS=$'\n'
	while read line 
	do
		[ -z "${delim-}" ] && extractDelim
		if [ "${line:0:${#delim}}" = "$delim" ]
		then
			line="${line:${#delim}}"
			processAction || return $?
			currLine="$line"
			extractActionParams
			cnt=""
			lf=0
		else
			if [ ${#line} -eq 0 ]
			then
				lf=$((lf+1))
			else
				for i in $(seq 1 $lf)
				do
					cnt="$cnt
"
				done
	
				lf=0
				cnt="$cnt$line
"
			fi
		fi
	done << EOF
$ACTIONS
EOF

	processAction || return $?
}

processAll && err=0 || err=$?

echo
echo
if [ $err -eq 0 ]
then
	echo "processing finished."
else
	echo "ERROR: processing failed. exit code = $err"
fi

