Appendix A: State machine graphs
================================

See chapter 1 for information on how to generate these for yourself. They
are included for your convenience.

These graphs are generated with::

        # git clone http://github.com/varnish/Varnish-Cache/
        Cloning into 'Varnish-Cache'...
        (...)
        # cd Varnish-Cache/
        # cd doc/graphviz/
        # for a in *dot; do dot -Tsvg $a > $(echo $a | sed s/.dot/.svg/); done
        # ls *svg

A PNG version of each is also available at:

* https://varnishfoo.info/img/c1/cache_req_fsm.png
* https://varnishfoo.info/img/c1/cache_fetch.png
* https://varnishfoo.info/img/c1/cache_http1_fsm.png

.. _cache_req_fsm: img/c1/cache_req_fsm.png

.. _cache_fetch: img/c1/cache_fetch.png

.. _cache_http1_fsm: img/c1/cache_http1_fsm.png

cache_req_fsm.svg
-----------------

.. image:: img/c1/cache_req_fsm.svg

`cache_req_fsm`_ details the client-specific part of the VCL state engine.
And can be used when writing VCL. You want to look for the blocks that
read ``vcl_`` to identify VCL functions. The lines tell you how a
return-statement in VCL will affect the VCL state engine at large, and
which return statements are available where. You can also see which objects
are available where.


cache_fetch.svg
---------------

.. image:: img/c1/cache_fetch.svg

`cache_fetch`_ has the same format as the ``cache_req_fsm.svg``, but
from the perspective of a backend request.

cache_http1_fsm.svg
-------------------

.. image:: img/c1/cache_http1_fsm.svg

Of the three, `cache_http1_fsm`_ is the least practical flow chart, mainly
included for completeness. It does not document much related to VCL or
practical Varnish usage, but the internal state engine of an HTTP request
in Varnish. It can sometimes be helpful for debugging internal Varnish
issues.
