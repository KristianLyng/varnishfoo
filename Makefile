CHAPTERS=chapter-1.rst chapter-2.rst chapter-3.rst appendix-1.rst appendix-N.rst
MISC=pdf.style version.rst
PICS=img/c3/*png img/c1/*png img/c2/*png

varnishfoo.pdf: varnishfoo.rst ${MISC} ${CHAPTERS} ${PICS}
	rst2pdf -b2 -s pdf.style varnishfoo.rst -o $@

version.rst: ${CHAPTERS} Makefile .git/index
	echo ":Version: $$(git describe --always --tags --dirty)" > version.rst

clean:
	-rm varnishfoo.pdf version.rst

.PHONY: clean
