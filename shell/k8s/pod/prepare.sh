#!/bin/sh
tmp="/tmp/scripts.$$"
mkdir $tmp
cd $tmp

is_bash=`readlink -f /proc/$$/exe | awk '{ i=match($0, /\/bash$/); if (i) { print "1" } else { print "0" } }'`

set -o errexit
set -o nounset
[[ "$is_bash" -eq 1 ]] && set -o pipefail

wget -sO- https://github.com/Cube-Earth/Scripts/archive/master.tar.gz | tar xf -
chmod -R +x *.sh

mv shell/k8s/pod/lazy-shell.sh /usr/local/bin
ln -s /usr/local/bin/lazy-shell.sh /bin/lsh

while getopts ":c" opt; do
    case "${opt}" in
        c)
        	case "$OPTARG" in
        		certs)
        			wget -sO- https://raw.githubusercontent.com/Cube-Earth/container-k8s-cert-server/master/pod-scripts/prepare-certs.sh | sh
        			;;

        		run)
        			mv shell/k8s/pod/run.sh /usr/local/bin
        			;;
        			
        		term)
        			mv shell/docker/term_safe_start.inc /usr/local/bin
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


