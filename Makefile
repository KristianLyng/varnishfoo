CHAPTERS=chapter-1.rst
foovarnish.pdf: foovarnish.rst ${CHAPTERS}
	rst2pdf -b2 foovarnish.rst -o $@
