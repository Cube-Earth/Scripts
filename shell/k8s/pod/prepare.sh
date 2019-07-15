#!/bin/sh
tmp="/tmp/scripts.$$"
mkdir $tmp
cd $tmp

which curl >/dev/null && export DOWNLOAD="curl -sL" && rc=0 || rc=$?
if [ "$rc" -ne 0 ]
then
	which wget >/dev/null && export DOWNLOAD="wget -qO-" && rc=0 || rc=$?
fi
[ "$rc" -ne 0 ] && echo "ERROR: neither curl nor wget installed !" && exit 1

is_bash=`readlink -f /proc/$$/exe | awk '{ i=match($0, /\/bash$/); if (i) { print "1" } else { print "0" } }'`

set -o errexit
set -o nounset
[ "$is_bash" -eq 1 ] && set -o pipefail

$DOWNLOAD https://github.com/Cube-Earth/Scripts/archive/master.tar.gz | tar xfz -
find . -type f -name "*.sh" -exec chmod +x {} \;

mv Scripts-master/shell/k8s/pod/lazy-shell.sh /usr/local/bin
ln -s /usr/local/bin/lazy-shell.sh /bin/lsh

while getopts "c:" opt; do
    case "${opt}" in
        c)
        	case "$OPTARG" in
        		certs)
        			$DOWNLOAD https://raw.githubusercontent.com/Cube-Earth/container-k8s-cert-server/master/pod-scripts/prepare-certs.sh | sh
        			;;

        		run)
        			mv Scripts-master/shell/k8s/pod/run.sh /usr/local/bin
        			mkdir /usr/local/bin/pre_execute /usr/local/bin/post_execute
        			;;
        			
        		term)
        			mv Scripts-master/shell/docker/term_safe_start.inc /usr/local/bin
        			;;
        			
        		*)
        			echo "Unknown capability '$OPTARG'!" >&2
        			exit 1
        			;;
        			
        	esac
            ;;
            
		\?)
      		echo "Invalid option: -$OPTARG" >&2
      		exit 1
      		;;
          esac
done
shift $((OPTIND-1))

rm -Rf $tmp

