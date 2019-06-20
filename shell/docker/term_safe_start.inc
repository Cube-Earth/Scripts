function term_safe_start {
	if [[ -z "$TERM" ]]
	then
		echo "INFO: Container started without terminal."
		eval $1
	else
		echo "WARN: Container started with terminal. Waiting for SIGWINCH to prevent errors!"
		trap "CONSUMED=1; echo 'INFO: SIGWINCH received. Continuing startup ...'; eval $1" WINCH
		n=${2-15}
		while [[ "$n" -gt 0 ]] && [[ -z "$CONSUMED" ]]
		do
			sleep 0.2
			n=$((n-1))
		done
		if [[ -z "$CONSUMED" ]]
		then
			trap - WINCH
			echo "BOGUS: No SIGWINCH received. Nevertheless continuing startup ..."
			eval $1
		fi
	fi
}
