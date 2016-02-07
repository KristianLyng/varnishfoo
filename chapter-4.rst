Introducing VCL
===============

.. warning::

   I expect this chapter to change significantly throught its creation, and
   possibly throught the creation of the rest of the book.

   I advise against reviewing the pedagogical aspects of the chapter until
   the text is complete (as in: a summary exists). Or until this warning is
   removed.

The Varnish Configuration Language is a small custom programming language
that gives you the chance to hook into Varnish's request handling state
engine at various crucial stages.

Mastering VCL is a matter of learning the language itself, understanding
what the different states mean and how you can exploit the tools that are
you at your disposal.

This chapter focuses on the language itself and a small subset of the
states you can affect. The goal is to give you the skills needed to write
robust VCL that allows Varnish to cache efficiently.

VCL is officially documented in the `vcl` manual page (``man vcl``), but
you would do well if you revisit the state diagrams provided in appendix A.

What you will not find in this chapter is an extensive list of every
keyword and operator available. That is precisely what the manual page is
for.

Hello World
-----------

Let's just start. You know what an ``if()``-sentence is and I'm sure you
can figure out that ``{`` starts a new scope.

.. code:: C

        vcl 4.0;

        backend foo {
                .host = "127.0.0.1";
                .port = "8080";
        }

        sub vcl_deliver {
                set resp.http.X-hello = "Hello, world";
        }

Let's take it from the top.

The first line is a VCL version string. Right now, there is only one valid
VCL version. Even for Varnish 4.1, the VCL version is 4.0. This is intended
to make transitions to newer versions of Varnish simpler. Every VCL file
starts with ``vcl 4.0;`` for now.

Next up, we define a backend server named `foo`. We set the IP of the
backend and port. You can have multiple backends, as long as they have
different names. As long as you only define a single backend, you don't
need to explicitly reference it anywhere, but if you have multiple backends
you need to be explicit about which to use when.

Last, but not least, we provide some code for the ``vcl_deliver`` state. If
you look at the ``cache_req_fsm.svg`` in appendix A, you will find
``vcl_deliver`` at the bottom left. It is the last VCL before the request
is delivered back to the client.

.. image:: img/c4/vcl_deliver.png

The ``set resp.http.X-hello = "Hello, world";`` line demonstrates how you
can alter variables. ``set <variable> = <value>;`` is the general syntax
here. Each VCL state has access to different variables. The different
variables are split up in families: ``req``, ``bereq``, ``beresp``,
``resp``, ``obj``, ``client`` and ``server``.

In the state diagram (again, see Appendix A), looking closer at the box
where ``vcl_deliver`` is listed, you will find ``resp.*`` and ``req.*``
listed, suggesting that those families of variables are available to us in
``vcl_deliver``.

In our specific example, ``resp.http.X-hello`` refers to the artificial
response header ``X-hello`` which we just invented. You can set any
response header you want, but as general rule (and per RFC), prefixing
custom-headers with ``X-`` is the safest choice to avoid conflicts with
other potential intermediaries that are out of your control.

Let's see how it looks::

        # http -p h localhost
        HTTP/1.1 200 OK
        Accept-Ranges: bytes
        Age: 0
        Connection: keep-alive
        Content-Encoding: gzip
        Content-Type: text/html
        Date: Sat, 06 Feb 2016 22:26:04 GMT
        ETag: "2b60-52b20c692a380-gzip"
        Last-Modified: Sat, 06 Feb 2016 21:37:34 GMT
        Server: Apache/2.4.10 (Debian)
        Transfer-Encoding: chunked
        Vary: Accept-Encoding
        Via: 1.1 varnish-v4
        X-Varnish: 2
        X-hello: Hello, world

And there you are, a custom VCL header.

Working with VCL
----------------






