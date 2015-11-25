CHAPTERS=chapter-1.rst chapter-2.rst
varnishfoo.pdf: varnishfoo.rst pdf.style ${CHAPTERS}
	rst2pdf -b2 -s pdf.style varnishfoo.rst -o $@
