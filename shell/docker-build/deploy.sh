#!/bin/sh

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
DEPLOY_CNF="/opt/deploy/deployments.cnf"
cmds=''

function deploy
{
	IFS=$'\n'
	for f in $(awk -v id="$1" 'match($0, /^[^#]*#/) { $0=substr($0, RSTART, RLENGTH-1) } match($0, "^[^ \t]+:[ \t]*$") { f=0 } f { gsub(/^[ \t]+/, ""); gsub(/[ \t]+$/, ""); if(length($0) > 0) { print $0 } } match($0, "^" id ":[ \t]*$") { f=1 }' "$DEPLOY_CNF")
	do
		if [[ "$f" =~ ^@.*$ ]]
		then
			deploy "${f:1}"
		else
			cmds="$cmds
($f)"
		fi
	done
	
}


function init_downloads
{
	which curl >/dev/null && export DOWNLOAD="curl -LOJ" && rc=0 || rc=$?
	if [ "$rc" -ne 0 ]
	then
		which wget >/dev/null && export DOWNLOAD="wget" && rc=0 || rc=$?
	fi
	[ "$rc" -ne 0 ] && echo "ERROR: neither curl nor wget installed !" && exit 1

	mkdir -p /tmp/tmp_deploy
	cd /tmp/tmp_deploy
}

function download
{
	local f="$1"
	$DOWNLOAD "$f"
	archive=$(ls -1 /tmp/tmp_deploy/*)
	ext=$(echo ${archive//*./} | tr '[:upper:]' '[:lower:]')
	case $ext in
		zip)
			rpm -qi zip > /dev/null || $RPM_INSTALL zip
			unzip "$archive"
			;;

		tgz)
			rpm -qi tar > /dev/null || $RPM_INSTALL tar
			tar xfz "$archive"
			;;
		
		bz2)
			rpm -qi tar > /dev/null || $RPM_INSTALL tar
			tar xfj "$archive"
			;;

		xz)
			rpm -qi tar > /dev/null || $RPM_INSTALL tar
			tar xfJ "$archive"
			;;

		*)
			echo "ERROR: unsupported archive format for '$archive'!"
			return 1
	esac
	
	rm "$archive"
	cp -Rf /tmp/tmp_deploy/* /opt/deploy/
	rm -Rf /tmp/tmp_deploy/*
}


os=$(cat /etc/os-release | awk '/^ID=/ { sub(/^ID=/, ""); print $0 }')
case "$os" in
	debian|ubuntu)
		apt-get update
		RPM_INSTALL="apt-get install -y" 
		;;

	centos)
		RPM_INSTALL="yum install -y"
		;;

	alpine)
		RPM_INSTALL="apk add --no-cache"
		;;
esac


mkdir -p /opt/deploy

if [[ ! -z "${DEPLOY_DOWNLOAD_URL-}" ]]
then
	init_downloads
	IFS=$'\n'
	for url in $(echo "$DEPLOY_DOWNLOAD_URL" | awk 'match($0, /^[^a-zA-Z]*/) { d=substr($0, RSTART, RLENGTH) } !d { print } d { split(substr($0, length(d)+1), a, d); for (e in a) { print a[e] } }'
    do
    	download "$url"
	done
fi



cd /opt/deploy
deploy "$DEPLOY_ID"

eval "$cmds"

rm -Rf /opt/deploy
