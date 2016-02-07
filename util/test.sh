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
		print >> target "/" FILENAME "-" n ".vcl"
}
END {
	print n " VCLs written to " target
}
' "$@"

ok() {
	echo -e "\033[32m$*\033[0m"
}

fail() {
	echo -e "\033[31m$*\033[0m"
}

testvcl(){
	VCL=$1
	echo -n " [Testing] "
	OUT=$(${VARNISHD} -n ${TARGET} -C -f ${VCL} 2>&1)
	if [ $? -eq "0" ]; then
		ok $a
		return 0
	else
		fail $a
		echo -e "$OUT"
		return 1
	fi
}

_tmp=${TARGET}'/*.vcl'
_tmp2=$(echo $_tmp)

if [ "$_tmp2" = "$_tmp" ]; then
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
