#!/bin/sh
set -o errexit
set -o nounset

function createConf{
	cat << EOF > /etc/supervisord.conf
[unix_http_server]
file=/tmp/supervisor.sock

[supervisord]
logfile=/logs/supervisor/supervisord.log
logfile_maxbytes=50MB
logfile_backups=10
loglevel=info
childlogdir=/logs/supervisor
pidfile=/tmp/supervisord.pid
minprocs=100
minfds=1024
nodaemon=true

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl = unix:///tmp/supervisor.sock

[eventlistener:check_fatals]
events=PROCESS_STATE_FATAL
command=sh -c "read; supervisorctl shutdown"
EOF
}

function createStartup
{
	cat << EOF > /usr/local/bin/startup/startup.sh
#!/bin/sh
/usr/bin/supervisord -c /etc/supervisord.conf
EOF
}

function installPackages
{
	os=$(cat /etc/os-release | awk '/^ID=/ { sub(/^ID=/, ""); print $0 }')
	case "$os" in
		debian|ubuntu)
			apt-get update
			apt-get install -y supervisord
			;;

		centos)
			yum install -y supervisord
			;;

		alpine)
			apk add --no-cache supvervisord
			;;
	esac	
}


function getPackages
{
	echo "supervisord"
}


function addSvc
{
	cat << EOF >> /etc/supervisord.conf

[program:$1]
command=$2
autorestart=true
EOF
}



function writeStartup
{
	local cmd="/usr/bin/supervisord -c /etc/supervisord.conf"
	
	case "${operation-overwrite}" in
		overwrite)
			echo -e "#!/bin/sh\n$cmd" > "$file"
			chmod +x "$file"
   			;;

		append)
			echo "$cmd" > "$file"
   			;;

		print)
			echo "$cmd"
   			;;
   			
   		*)
   			echo "ERROR: unknown operation '$operation'!"
   			return 1
   			;;
	esac
}



function executeAction
{
	case "$action" in
		installPackages)
    		installPackages
   			;;

		install)
    		installPackages
   			;;

		getPackages)
    		getPackages
   			;;

		add)
			[ -f /etc/supervisord.conf ] || createConf
    		addSvc "$name" "$command"
   			;;
   			
   		startup)
   			writeStartup "${operation:-}" "$file"
   			
   		*)
   			echo "ERROR: unknown action '$action'!"
   			return 1
   			;;
	esac
	unset action
}


if [ ! -z "${INSTALL-}" ]
then
	mkdir -p /logs/supervisor /opt/startup

	installPackages

	operation="overwrite"
	file="/opt/startup/startup.sh"
	writeStartup
	
	exit 0
fi


while getopts "a:n:c:o:f:" opt; do
    case "${opt}" in
        a)
        	[ -z "${action-}" ] || executeAction
        	action="$OPTARG"
   			;;
   			
        n)
        	name="$OPTARG"
   			;;

        c)
        	command="$OPTARG"
   			;;

        o)
        	operation="$OPTARG"
   			;;

        f)
        	file="$OPTARG"
   			;;

        			
		\?)
      		echo "Invalid option: -$OPTARG" >&2
      		exit 1
      		;;
          esac
done
shift $((OPTIND-1))

[ -z "${action-}" ] || executeAction
