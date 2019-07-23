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

/^---+ */ { reset(); }

/^kind:.*/ { match($0, /:.*$/); k=trim(substr($0,RSTART+1,RLENGTH-1)) }

k=="DaemonSet" && f==0 && /^ *ports *: *$/ { match($0, /^ +/); s=substr($0, RSTART, RLENGTH); f=1 }
k=="DaemonSet" && f==1 && /^ *- *name:/ { n=$0; sub(/:.*$/, ": ", n); f=2 }
k=="DaemonSet" && f==2 && /^ *containerPort:/ { p=$0; sub(/:.*$/, ": ", p); f=3 }
k=="DaemonSet" && f==3 && match($0, "^" s "[^\- ]") { print n protocol; print p port; f=-1 }

k=="ConfigMap" && f==0 && /^data *: *$/ { f=1 }
k=="ConfigMap" && f==1 && /^ / { match($0, /^ +/); s=substr($0, RSTART, RLENGTH); f=2 }
k=="ConfigMap" && f==2 && ! /^  "[0-9]+"/ { print s "\"" port "\": \"" target "\""; f=-1 }

{ print }
