#!/bin/bash

VARNISHD=/usr/local/sbin/varnishd
TARGET=$(mktemp -d /tmp/foo.XXXXXX)
awk -v target=${TARGET} '
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
' "$@"

testvcl(){
	VCL=$1
	echo "Testing $a"
	OUT=$(${VARNISHD} -n ${TARGET} -C -f ${VCL} 2>&1)
	if [ $? -eq "0" ]; then
		echo "FINE!";
		return 0
	else
		echo -e "$OUT"
		return 1
	fi
}

_tmp=${TARGET}'/*.vcl'

if [ $_tmp = "$_tmp" ]; then
	echo "Nothing to test"
	rm -r ${TARGET}
	exit 0
fi
ret=0
for a in ${TARGET}/*.vcl; do
	testvcl $a
	ret=$(( $ret + $? ))
done
rm -r ${TARGET}
exit $ret
