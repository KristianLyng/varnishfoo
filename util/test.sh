#!/bin/bash

VARNISHD=/usr/local/sbin/varnishd
TARGET=$(mktemp -d /tmp/foo.XXXXXX)
cat chapter-4.rst | awk -v target=${TARGET} '
/.. code::/ {
	n += 1
	code=1
	next
}
! (/^\s/ || /^$/ ) {
	code=0
}
{
	if (code>0)
		print >> target "/foo" n ".vcl"
}
END {
	print n " VCLs written to " target
}
'

testvcl(){
	VCL=$1
	echo "Testing $a"
	OUT=$(${VARNISHD} -n ${TARGET} -C -f ${VCL} 2>&1)
	if [ $? -eq "0" ]; then
		echo "FINE!";
	else
		echo -e "$OUT"
	fi
}


for a in ${TARGET}/*.vcl; do
	testvcl $a
done


