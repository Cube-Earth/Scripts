#!/bin/sh

env 

if [ -z "${DOWNLOAD-}" ]
then
	curl >/dev/null 2>&1 && rc=0 || rc=$?
	if [ "$rc" -ne 127 ]
	then
		export DOWNLOAD="curl -Ls"
	else
		wget >/dev/null 2>&1 && rc=0 || rc=$?
		if [ "$rc" -eq 127 ]
		then
			case "$os" in
				debian|ubuntu)
					apt-get update
					apt-get install -y wget
					;;

				centos)
					yum install -y wget
					;;

				alpine)
					apk add --no-cache wget
					;;
			esac			
		fi
		export DOWNLOAD="wget -qO-"
	fi
fi

IFS=$'\n'
while read LINE
do
#	FILE="/usr/bin/${LINE/*\//}"
#	$DOWNLOAD "$LINE" > "$FILE"
#	chmod +x $FILE
#	"$FILE" "$@"
	echo "---$LINE---"	
done
