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

SCRIPT_DIR="/opt/scripts"

mkdir -p "$(dirname "$SCRIPT_DIR")"
mv Scripts-master "$SCRIPT_DIR"

ln -s "$SCRIPT_DIR/shell/lazy-shell.sh" /bin/lsh

export INSTALL=1
while getopts "c:" opt; do
    case "${opt}" in
        c)
        	case "$OPTARG" in
        		certs)
        			$DOWNLOAD https://raw.githubusercontent.com/Cube-Earth/container-k8s-cert-server/master/pod-scripts/prepare-certs.sh | sh
        			;;

        		run)
        			ln -s "$SCRIPT_DIR/shell/startup/run.sh" /usr/bin/run.sh
        			mkdir -p /opt/pre_execute /opt/post_execute
        			;;
        			
        		*)
        			echo "Unknown capability '$OPTARG'!" >&2
        			exit 1
        			;;
        			
        	esac
            ;;

        s)
        	"$SCRIPT_DIR/shell/$OPTARG.sh"
            
		\?)
      		echo "Invalid option: -$OPTARG" >&2
      		exit 1
      		;;
          esac
done
shift $((OPTIND-1))
unset INSTALL

rm -Rf $tmp

