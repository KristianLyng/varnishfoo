CHAPTERS=chapter-1.rst chapter-2.rst chapter-3.rst appendix-1.rst appendix-n.rst
WEBTARGET=pathfinder.kly.no:public_html/varnishfoo.info/
PICS=img/c3/*png img/c1/*png img/c2/*png
C=control/
MISC=${C}/pdf.style ${B}/version.rst
CTRL=control/headerfooter.rst control/front.rst
WA=${B}/index.html ${B}/chapter-1.html ${B}/chapter-2.html ${B}/chapter-3.html ${B}/appendix-1.html ${B}/appendix-2.html ${B}/appendix-n.html
B=build

web: ${WA} ${B}/varnishfoo.pdf
	@echo " [WEB] Populating ${B}"
	@cp -a img/ ${B}/
	@cp -a bootstrap/* ${B}/

${B}:
	@echo " [BLD] mkdir ${B}"
	@mkdir -p ${B}

dist: web
	@echo " [WEB] rsync"
	@rsync --delete -L -a ${B}/ ${WEBTARGET}
	@echo " [WEB] Purge"
	@GET -d http://kly.no/purgeall

pdf: ${B}/varnishfoo.pdf

${B}/varnishfoo.pdf: varnishfoo.rst ${MISC} ${CHAPTERS} ${PICS} ${CTRL} | ${B}
	@echo " [PDF] $<"
	@FOO=$$(rst2pdf -b2 -s ${C}/pdf.style varnishfoo.rst -o $@ 2>&1); \
		ret=$$? ; \
		echo "$$FOO" | egrep -v 'is too.*frame.*scaling'; \
		exit $$ret


${B}/version.rst: ${CHAPTERS} ${PICS} Makefile .git/index | ${B}
	@echo " [RST] $@"
	@echo ":Version: $$(git describe --always --tags --dirty)" > ${B}/version.rst
	@echo ":Date: $$(date --iso-8601)" >> ${B}/version.rst

${B}/chapter-%.pdf: ${B}/chapter-%-pdf.rst ${PICS} ${MISC}
	@echo " [PDF] $@"
	@FOO=$$(rst2pdf -b2 -s ${C}/pdf.style $< -o $@ 2>&1); \
		ret=$$? ; \
		echo "$$FOO" | egrep -v 'is too.*frame.*scaling'; \
		exit $$ret

${B}/chapter-%-pdf.rst: chapter-%.rst Makefile | ${B}
	@echo " [PDF] Makeing $@"
	@echo ".. include:: control/front.rst" > $@
	@echo >> $@
	@echo ".. include:: control/headerfooter.rst" >> $@
	@echo >> $@
	@echo ".. include:: $<" >> $@
	@echo >> $@

${B}/web-version.rst: ${B}/version.rst | ${B}
	@echo " [RST] $@"
	@echo "This content was generated from source on $$(date --iso-8601)" > ${B}/web-version.rst
	@echo >> ${B}/web-version.rst
	@echo "The git revision used was $$(git describe --always --tags)" >> ${B}/web-version.rst
	@echo >> ${B}/web-version.rst
	@git describe --tags --dirty | egrep -q "dirty$$" && echo "*Warning: This was generated with uncomitted local changes!*" >> ${B}/web-version.rst || true

${B}/chapter-%.html: chapter-%.rst ${C}/template.raw | ${B}
	@echo " [WEB] $@"
	@rst2html --template ${C}/template.raw $< > $@

${B}/appendix-%.html: appendix-%.rst ${C}/template.raw | ${B}
	@echo " [WEB] $@"
	@rst2html --template ${C}/template.raw $< > $@

${B}/index.html: index.rst ${C}/template.raw ${B}/web-version.rst | ${B}
	@echo " [WEB] $@"
	@rst2html --template ${C}/template.raw $< > $@

clean:
	-rm -rf ${B}

.PHONY: clean web pdf
