CHAPTERS=chapter-1.rst chapter-2.rst chapter-3.rst appendix-1.rst appendix-n.rst
MISC=pdf.style version.rst
PICS=img/c3/*png img/c1/*png img/c2/*png
W=varnishfoo.info
WA=${W}/index.html ${W}/chapter-1.html ${W}/chapter-2.html ${W}/chapter-3.html ${W}/appendix-1.html ${W}/appendix-2.html ${W}/appendix-n.html

web: ${WA} varnishfoo.pdf
	@echo " [WEB] Populating ${W}"
	@cp -a img/ ${W}/
	@cp -a varnishfoo.pdf ${W}

dist: web
	@echo " [WEB] Rsync"
	@rsync --delete -L -a ./varnishfoo.info/ pathfinder.kly.no:public_html/varnishfoo.info/
	@echo " [WEB] Purge"
	@GET -d http://kly.no/purgeall

varnishfoo.pdf: varnishfoo.rst ${MISC} ${CHAPTERS} ${PICS}
	@echo " [PDF] $<"
	@FOO=$$(rst2pdf -b2 -s pdf.style varnishfoo.rst -o $@ 2>&1); \
		ret=$$? ; \
		echo "$$FOO" | egrep -v 'is too.*frame.*scaling'; \
		exit $$ret


version.rst: ${CHAPTERS} ${PICS} Makefile .git/index
	@echo " [RST] $@"
	@echo ":Version: $$(git describe --always --tags --dirty)" > version.rst
	@echo ":Date: $$(date --iso-8601)" >> version.rst

${W}/web-version.rst: version.rst
	@echo " [RST] $@"
	@echo "This content was generated from source on $$(date --iso-8601)" > ${W}/web-version.rst
	@echo >> ${W}/web-version.rst
	@echo "The git revision used was $$(git describe --always --tags)" >> ${W}/web-version.rst
	@echo >> ${W}/web-version.rst
	@git describe --tags --dirty | egrep -q "dirty$$" && echo "*Warning: This was generated with uncomitted local changes!*" >> ${W}/web-version.rst || true

${W}/chapter-%.html: chapter-%.rst ${W}/template.raw
	@echo " [WEB] $<"
	@rst2html --template ${W}/template.raw $< > $@

${W}/appendix-%.html: appendix-%.rst ${W}/template.raw
	@echo " [WEB] $<"
	@rst2html --template ${W}/template.raw $< > $@

${W}/index.html: ${W}/index.rst ${W}/template.raw ${W}/web-version.rst
	@echo " [WEB] $<"
	@rst2html --template ${W}/template.raw $< > $@

clean:
	-rm varnishfoo.pdf version.rst

.PHONY: clean web
