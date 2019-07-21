function process() {
	i0=RSTART;
	j0=RSTART+RLENGTH;
	i=i0 + 2;
	j=j0 - 3;
	while(substr($0,i)==" ") {
		i=i+1
	}
	while(substr($0,j)==" ") {
		j=j-1
	}
	e=substr($0,i,j-i+1);
	v=ENVIRON[e]
	if(match(v, /\{\{/)) {
		print "ERROR: invalid environment variable value!" > "/dev/stderr"
		exit 1
	}
	$0=substr($0, 0, i0) v substr($0, j0)
}

{ while(match($0, /\{\{ *[^}]+ *\}\}/)) { process() }; print }
