WEBTARGET=pathfinder.kly.no:public_html/varnishfoo.info/
C=control/
B=build

bases = $(basename $(wildcard chapter*rst appendix*rst))
CHAPTERS= $(addsuffix .rst,${bases})
HTML=${B}/index.html $(addprefix ${B}/,$(addsuffix .html,${bases}))
CHAPTERPDF= $(addprefix ${B}/,$(addsuffix .pdf, ${bases}))

define ok =
"\033[32m$@\033[0m"
endef

define run-rst2pdf = 
	@FOO=$$(rst2pdf -b2 -s ${C}/pdf.style $(firstword $^) -o $@ 2>&1); \
		ret=$$? ; \
		echo -n "$$FOO" | egrep -v 'is too.*frame.*scaling'; \
		exit $$ret
	@echo " [rst2pdf] "$(ok)
endef

web: ${B}/varnishfoo.pdf ${CHAPTERPDF} ${HTML} | ${B}/css ${B}/fonts ${B}/js
	@echo " [WEB] "$(ok)

dist: web
	@echo " [WEB] rsync"
	@rsync --delete -L -a ${B}/ ${WEBTARGET}
	@echo " [WEB] Purge"
	@GET -d http://kly.no/purgeall

${B}/css ${B}/fonts ${B}/js: ${B}/%: bootstrap/% | ${B}
	@cp -a $< ${B}
	@echo " [cp] "$(ok)

${B}/img: $(wildcard img/*/*) | ${B}
	@cp -a img ${B}
	@echo " [cp] "$(ok)

${B}:
	@mkdir -p ${B}
	@echo " [mkdir] "$(ok)

${B}/version.rst: $(wildcard *rst Makefile .git/* control/* img/* img/*/*) | ${B}
	@echo ":Version: $$(git describe --always --tags --dirty)" > ${B}/version.rst
	@echo ":Date: $$(date --iso-8601)" >> ${B}/version.rst
	@echo " [RST] "$(ok)

${B}/web-version.rst: $(wildcard *rst Makefile .git/* control/* img/* img/*/*) | ${B}
	@echo "This content was generated from source on $$(date --iso-8601)" > ${B}/web-version.rst
	@echo >> ${B}/web-version.rst
	@echo "The git revision used was $$(git describe --always --tags)" >> ${B}/web-version.rst
	@echo >> ${B}/web-version.rst
	@git describe --tags --dirty | egrep -q "dirty$$" && echo "*Warning: This was generated with uncomitted local changes!*" >> ${B}/web-version.rst || true
	@echo " [RST] "$(ok)

${B}/varnishfoo.pdf: varnishfoo.rst $(wildcard *rst Makefile .git/* control/* img/* img/*/*) ${B}/version.rst | ${B}
	$(run-rst2pdf)

$(addprefix ${B}/,$(addsuffix .pdf,${bases})): ${B}/%.pdf: ${B}/%.rst ${B}/img ${B}/version.rst Makefile
	$(run-rst2pdf)

$(addprefix ${B}/,$(addsuffix .rst,${bases})): ${B}/%.rst: %.rst Makefile ${B}
	@echo ".. include:: ../control/front.rst" > $@
	@echo >> $@
	@echo ".. include:: ../control/headerfooter.rst" >> $@
	@echo >> $@
	@echo ".. include:: ../$<" >> $@
	@echo >> $@
	@echo " [RST] "$(ok)

$(addprefix ${B}/,$(addsuffix .html,${bases})): ${B}/%.html: %.rst Makefile ${C}/template.raw | ${B}/img ${B}
	@rst2html --template ${C}/template.raw $< > $@
	@echo " [rst2html] "$(ok)

${B}/index.html: README.rst ${B}/web-version.rst | ${B}
	@rst2html --template ${C}/template.raw $< > $@
	@echo " [rst2html] "$(ok)

clean:
	-rm -rf ${B}

.PHONY: clean web dist

.SECONDARY: $(addprefix ${B}/,$(addsuffix .rst,${base}))
