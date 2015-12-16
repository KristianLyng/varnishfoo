WEBTARGET=pathfinder.kly.no:public_html/varnishfoo.info/
PICS=$(wildcard img/*/*png)
CTRL=control/headerfooter.rst control/front.rst
C=control/
B=build

MISC=${C}/pdf.style ${B}/version.rst

bases = $(basename $(wildcard chapter*rst appendix*rst))
CHAPTERS= $(addsuffix .rst,${bases})
WA=${B}/index.html $(addprefix ${B}/,$(addsuffix .html,${bases}))
CHAPTERPDF= $(addprefix ${B}/,$(addsuffix .pdf, ${bases}))

web: ${CHAPTERPDF} ${WA} ${B}/varnishfoo.pdf
	@echo " [WEB] Populating ${B}"
	@cp -a bootstrap/* ${B}/

${B}/img: ${PICS}
	@echo " [BLD] Copying images"
	@cp -a img/ ${B}/

${B}:
	@echo " [BLD] mkdir ${B}"
	@mkdir -p ${B}

dist: web
	@echo " [WEB] rsync"
	@rsync --delete -L -a ${B}/ ${WEBTARGET}
	@echo " [WEB] Purge"
	@GET -d http://kly.no/purgeall

chapterpdf: ${CHAPTERPDF}

pdf: ${B}/varnishfoo.pdf

${B}/version.rst: ${CHAPTERS} ${PICS} Makefile .git/index | ${B}
	@echo " [RST] $@"
	@echo ":Version: $$(git describe --always --tags --dirty)" > ${B}/version.rst
	@echo ":Date: $$(date --iso-8601)" >> ${B}/version.rst

${B}/varnishfoo.pdf: varnishfoo.rst ${MISC} ${CHAPTERS} ${PICS} ${CTRL} | ${B}
	@echo " [PDF] $@"
	@FOO=$$(rst2pdf -b2 -s ${C}/pdf.style varnishfoo.rst -o $@ 2>&1); \
		ret=$$? ; \
		echo -n "$$FOO" | egrep -v 'is too.*frame.*scaling'; \
		exit $$ret

${B}/chapter-%.pdf: ${B}/chapter-%.rst ${PICS} ${MISC} ${B}/img
	@echo " [PDF] $@"
	@FOO=$$(rst2pdf -b2 -s ${C}/pdf.style $< -o $@ 2>&1); \
		ret=$$? ; \
		echo -n "$$FOO" | egrep -v 'is too.*frame.*scaling'; \
		exit $$ret

${B}/appendix-%.pdf: ${B}/appendix-%.rst ${PICS} ${MISC} ${B}/img
	@echo " [PDF] $@"
	@FOO=$$(rst2pdf -b2 -s ${C}/pdf.style $< -o $@ 2>&1); \
		ret=$$? ; \
		echo -n "$$FOO" | egrep -v 'is too.*frame.*scaling'; \
		exit $$ret

${B}/appendix-%.rst: appendix-%.rst Makefile | ${B}
	@echo " [PDF] Making $@"
	@echo ".. include:: ../control/front.rst" > $@
	@echo >> $@
	@echo ".. include:: ../control/headerfooter.rst" >> $@
	@echo >> $@
	@echo ".. include:: ../$<" >> $@
	@echo >> $@

${B}/chapter-%.rst: chapter-%.rst Makefile | ${B}
	@echo " [PDF] Making $@"
	@echo ".. include:: ../control/front.rst" > $@
	@echo >> $@
	@echo ".. include:: ../control/headerfooter.rst" >> $@
	@echo >> $@
	@echo ".. include:: ../$<" >> $@
	@echo >> $@

${B}/web-version.rst: ${B}/version.rst ${C}/* | ${B}
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

${B}/index.html: README.rst ${C}/template.raw ${B}/web-version.rst | ${B}
	@echo " [WEB] $@"
	@rst2html --template ${C}/template.raw $< > $@

clean:
	-rm -rf ${B}

.PHONY: clean web pdf
