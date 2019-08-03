function reset() {
  k=""; f=0
}

function trim(s) {
  gsub(/^ +/, "", s);
  gsub(/ +$/, "", s);
  return s;
}

BEGIN {
  reset()
}

{ skip=0 }

/^---+ */ { reset(); }

/^kind:.*/ { match($0, /:.*$/); k=trim(substr($0,RSTART+1,RLENGTH-1)) }

k=="Deployment" && f==0 && /^ *template *: *$/ { f=1 }
f==1 && /^ *spec *: *$/ {
	f=2;
	skip=1;
	match($0, "^ *");
	p = substr($0, RSTART, RLENGTH) "  ";
	print p "nodeSelector:"
#        beta.kubernetes.io/os: linux
#        beta.kubernetes.io/arch: amd64
}

{ if(!skip) { print } }


