#!/bin/bash

set -e

VARNISHD=/usr/local/sbin/varnishd
TARGET=$(mktemp -d /tmp/foo.XXXXXX)
awk -v target=${TARGET} '
/.. code:: VCL/ {
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
' "$@"

prefix() {
	{ echo "$1"; cat $2; } | sponge $2
}
cleanup() {
	if ! egrep -q '^\s*backend ' $1; then
		prefix 'backend foo { .host = "localhost"; }' $1
		prefix "vcl 4.0;" $1
	fi
	if ! egrep -q '^\s*vcl 4\.0;' $1; then
		prefix "vcl 4.0;" $1
	fi
}
ok() {
	echo -e "\033[32m$*\033[0m"
}

fail() {
	echo -e "\033[31m$*\033[0m"
}

testvcl(){
	VCL=$1
	cleanup $1
	OUT=$(${VARNISHD} -n ${TARGET} -C -f ${VCL} 2>&1)
	if [ $? -eq "0" ]; then
		echo -n " [VCL Syntax] "
		ok $a
		return 0
	else
		echo -n " [VCL Syntax] "
		fail $a
		echo -e "$OUT"
		return 1
	fi
}

_tmp=${TARGET}'/*.vcl'
_tmp2=$(echo $_tmp)

if [ "$_tmp2" = "$_tmp" ]; then
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
