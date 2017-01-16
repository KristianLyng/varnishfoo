About Varnish Foo
-----------------

.. _Varnish Cache: https://varnish-cache.org/
.. _Kristian Lyngstøl: https://kly.no/
.. _download a PDF: https://varnishfoo.info/varnishfoo.pdf
.. _varnishfoo.info: https://varnishfoo.info

Varnish Foo is the ultimate `Varnish Cache`_ book out there. Or it will be,
when it's done.

The book is being written by `Kristian Lyngstøl`_, a long-time Varnish
hacker. It is being published one chapter at a time, and you can either read it
online at `varnishfoo.info`_ or `download a PDF`_.

This book is not done yet. The individual chapters are meant to stand well
on their own, but many chapters are yet to be written and the content is
likely to evolve over time.

Found something that should be fixed?
-------------------------------------

.. _the github repo: https://github.com/KristianLyng/varnishfoo/

I am very interested in any and all feedback, from pure spelling mistakes
to factual errors or whether the book flows well or not.

The best way to get in contact with me is to jump over to `the github
repo`_ and report an issue. If that doesn't work for you, you can also drop
me a mail at kly@kly.no.

Current status
--------------

Chapter 1 through 3 stand well as they are, all though they might need some
updates here and there.

I am currently progressing through VCL.

Chapter 4, introduction to VCL, can be used as a reference as it is, but I
have not done a thorough review of it yet from a pedagogical point of view.
I expect some parts to require changes to be truly good.

Chapter 5 is currently being developed from scratch. Much has changed since
I was at my peak in the Varnish community, so I intend to update my own
knowledge throughout the development of that chapter (and further
chapters). I do have some really good bits in store for you all, though.

Basically: Read chapter 1 through 4 as "true", but don't assume chapter 5
represents current best practices until further notice.

Building
--------

I build this on Debian (stable and testing). It should build fine on other
distros too.

You will need, at least, "moreutils" (for ``sponge``), make, graphviz,
rst2pdf, rst2html (docutils), pygmentize, Varnish, and probably more.

Since I wrote a VCL lexer for Pygments for this project to get
decent-looking syntax highlighting, you also want to get a new version of
Pygments. As of this writing, there hasn't been a release of Pygments with
the lexer included, but it is merged and seemingly slated for Pygments
2.2.

On Debian, the easiest non-clutter way to go about getting this is cloning
the pygments repo and doing a local (user) install::

        $ hg clone https://bitbucket.org/birkenfeld/pygments-main
        $ cd pygments-main
        $ python setup.py build
        $ python setup.py install --user

This will do a local installation to ~/.local, so if you are like me and
don't want to clutter your install, this is what you want.

This will give you syntax highlighting for any ``VCL`` code-blocks in RST,
not just this book.

Misc
----

.. _Creative Commons Attribution-ShareAlike 4.0 International License:
   LICENSE

.. include:: build/web-version.rst

.. figure:: img/cc-by-sa.png
        :target: appendix-x.html
        :alt: Creative Commons License

        `Varnish Foo` by Kristian Lyngstøl is licensed under a `Creative
        Commons Attribution-ShareAlike 4.0 International License`_.

