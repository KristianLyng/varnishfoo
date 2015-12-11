CHAPTERS=chapter-1.rst chapter-2.rst chapter-3.rst appendix-1.rst appendix-N.rst
MISC=pdf.style version.rst
PICS=img/c3/*png img/c1/*png img/c2/*png
W=varnishfoo.info
WA=${W}/chapter-1.html ${W}/chapter-2.html ${W}/chapter-3.html

varnishfoo.pdf: varnishfoo.rst ${MISC} ${CHAPTERS} ${PICS}
	rst2pdf -b2 -s pdf.style varnishfoo.rst -o $@

version.rst: ${CHAPTERS} Makefile .git/index
	echo ":Author: Kristian Lyngstøl <kristian@bohemians.org>" > version.rst
	echo ":Version: $$(git describe --always --tags --dirty)" >> version.rst
	echo ":Date: $$(date --iso-8601)" >> version.rst

${W}/chapter-%.html: chapter-%.rst
	rst2html $< > $@

web: ${WA} varnishfoo.pdf
	cp -a img/ ${W}/
	cp varnishfoo.pdf ${W}

clean:
	-rm varnishfoo.pdf version.rst

.PHONY: clean
