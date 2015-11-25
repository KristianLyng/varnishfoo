CHAPTERS=chapter-1.rst chapter-2.rst
MISC=pdf.style version.rst

varnishfoo.pdf: varnishfoo.rst ${MISC} ${CHAPTERS}
	rst2pdf -b2 -s pdf.style varnishfoo.rst -o $@

version.rst: ${CHAPTERS}
	echo ":Version: $$(git describe --always --dirty)" > version.rst

