CHAPTERS=chapter-1.rst chapter-2.rst chapter-3.rst appendix-1.rst appendix-n.rst
MISC=pdf.style version.rst
PICS=img/c3/*png img/c1/*png img/c2/*png
W=varnishfoo.info
WA=${W}/index.html ${W}/chapter-1.html ${W}/chapter-2.html ${W}/chapter-3.html ${W}/appendix-1.html ${W}/appendix-2.html ${W}/appendix-n.html

varnishfoo.pdf: varnishfoo.rst ${MISC} ${CHAPTERS} ${PICS}
	rst2pdf -b2 -s pdf.style varnishfoo.rst -o $@

version.rst: ${CHAPTERS} Makefile .git/index
	echo ":Author: Kristian Lyngstøl <kristian@bohemians.org>" > version.rst
	echo ":Version: $$(git describe --always --tags --dirty)" >> version.rst
	echo ":Date: $$(date --iso-8601)" >> version.rst

${W}/chapter-%.html: chapter-%.rst ${W}/template.raw
	rst2html --template ${W}/template.raw $< > $@

${W}/appendix-%.html: appendix-%.rst ${W}/template.raw
	rst2html --template ${W}/template.raw $< > $@

${W}/index.html: ${W}/index.rst ${W}/template.raw
	rst2html --template ${W}/template.raw $< > $@

web: ${WA} varnishfoo.pdf
	cp -a img/ ${W}/
	cp varnishfoo.pdf ${W}

clean:
	-rm varnishfoo.pdf version.rst

.PHONY: clean
