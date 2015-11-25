Caching in HTTP
===============

Before we dig into the inner workings of Varnish, it's important to
establish the right context we're working with.

HTTP caching is both simple and complex. In this chapter, we will look at
how HTTP caching works on multiple points in the HTTP delivery chain, and
how these mechanisms work together.

There are a multitude of tools to chose from when you are working with
Varnish. We will focus on two different types of tools: The command line
tool and your browser.

Caching since RFC2616
---------------------

.. _RFC2616: https://www.ietf.org/rfc/rfc2616.txt

HTTP version 1.1 was defined in `RFC2616`_, released in 1999. It's worth a
read, as it's quite informative. If you are ever curious as to what the
correct interpretation of an HTTP header is, this is the place to go.

The important part for us, is to realize that caching is already there. It
deals mainly with two types of caches: Client side caches and intermediary
caches. One weakness of the protocol specification is that it does not
distinguish between an intermediary cache in the control of the web site
administrator, (like Varnish) and the traditional proxies that are still
found all over the world.

It does, however, give us a lot of the tools we need to get things done.
Most of what relates to caching is about response- and request-headers and
which HTTP methods and return codes can be cached. Varnish generally tries
to be a good HTTP-citizen, but largely ignores clients' attempts to
override cache mechanisms, like ``Cache-Control: no-cache`` HTTP headers.

Tools: The browser
------------------

You wont understand modern until you learn how to use your browser to
debug. If you are reading this, there's a good chance you already know a
lot of what is to come, but there's also a good chance you don't know some
of the details.

Most browsers have a "developer console" or "debug console" today, and we
will focus on Chromium and Firefox (or Iceweasel, for the Debian-users out
there). For the uninitiated, Chromium is the Open Source variant of the
Google Chrome browser, and for our purposes they are identical.

Both Firefox and Chromium will open the debug console if you hit ``<F12>``.
It's a good habit to test and experiment with more than one browser, and
luckily these consoles are very similar. A strong case in favor of Chromium
is the existence of `Incognito Mode`, activated through
``<Ctrl>+<Shit>+N``. This is an advantage for us both because it gives us a
clean slate with regards to cookies, and because it generally doesn't run
any extensions you might have running.

An argument for Firefox is that it's fairly easy to operate with
multiple profiles. One of these profiles could be used to run Firefox
through a SOCKS proxy for example to test a HTTP service that's not yet put
in production for example, or otherwise behind a firewall. You can achieve
this by running Firefox with ``--no-remote --ProfileManager`` (FIXME:
Windows?).

The importance of Incognito Mode can be easily demonstrated. The following
is a test with a typical Chromium session:

.. image:: img/chromium-dev-plugins.png

Notice the multiple extensions that are active, one of them is inserting a
bogus call to socialwidgets.css. The exact same test in Incognito Mode:

.. image:: img/chromium-dev-incognito.png

Now the extra reuest is gone.

You will also quickly learn that a refresh isn't always just a refresh.
In both Firefox and Chromium, a refresh triggered by ``<F5>`` or
``<ctrl>+r`` will be "cache aware". What does that mean?

Look closer on the screenshots above, specially the return code. The return
code is a ``304 Not Modified``, not a ``200 OK``. This means our browser
actually had the image in cache already and issued what is known as a
`conditional GET request`. A closer inspection:

.. image:: img/chromium-dev-304-1.png

Our browser is sending ``Cache-Control: max-age=0`` and an
``If-Modified-Since``-header, and the web server correctly responds with
``304 Not Modified``.  We'll shortly look closer at those, but for now,
let's use a different type of refresh: ``<Shift>+<F5>``:

.. image:: img/chromium-dev-304-2.png

Our cache-related headers have changed somewhat, and our browser is no
longer sending a ``If-Modified-Since`` header. The result is a ``200 OK``
with the actual content instead of an empty ``304 Not Modified``.


Tools: The command line tool
----------------------------

As we just saw, the browser does a lot more than just issue HTTP requests,
specially with regards to cache. It's important to have a good grip on at
least one tool to issue custom HTTP requests to a web server. There are
many of these, and it's also possible to hand-craft HTTP requests with
``telnet`` or ``netcat``, but today that's usually a bit tricky due to
various timeouts that tend to hit you before you finish the request - just
in case it wasn't just impractical in general.

FIXME: Windows.

While tools such as ``wget`` and ``curl`` can be used, they are designed to
be HTTP clients, not HTTP debugging tools. The ``lwp-request`` tool has
been somewhat popular in the Varnish-community, but has some shortcomings
(notably that it inserts fake headers in the response and doesn't support
gzip), so we will focus on `httpie`. On a Debian or Ubuntu system this is
easily installed with ``apt-get install httpie``. Testing httpie is
simple::

        $ http http://kly.no/misc/dummy.png
        HTTP/1.1 200 OK
        Accept-Ranges: bytes
        Age: 0
        Connection: keep-alive
        Content-Length: 178
        Content-Type: image/png
        Date: Wed, 25 Nov 2015 18:49:33 GMT
        Last-Modified: Wed, 02 Sep 2015 06:46:21 GMT
        Server: Really new stuff so people don't complain
        Via: 1.1 varnish-v4
        X-Cache: MISS from access-gateway.hospitality.swisscom.com
        X-Varnish: 15849590



        +-----------------------------------------+
        | NOTE: binary data not shown in terminal |
        +-----------------------------------------+

In our case, the actual data is often not that interesting, while a full
set of request headers are very interesting, so let's try that one again::

        $ http -p Hh http://kly.no/misc/dummy.png
        GET /misc/dummy.png HTTP/1.1
        Accept: */*
        Accept-Encoding: gzip, deflate
        Connection: keep-alive
        Host: kly.no
        User-Agent: HTTPie/0.8.0

        HTTP/1.1 200 OK
        Accept-Ranges: bytes
        Age: 81
        Connection: keep-alive
        Content-Length: 178
        Content-Type: image/png
        Date: Wed, 25 Nov 2015 18:49:33 GMT
        Last-Modified: Wed, 02 Sep 2015 06:46:21 GMT
        Server: Really new stuff so people don't complain
        Via: 1.1 varnish-v4
        X-Cache: HIT from access-gateway.hospitality.swisscom.com
        X-Varnish: 15849590

We now see the original request headers and full response headers. This
example happens to take place behind a transparent HTTP proxy at a hotel,
which creates some mildly interesting results for us. We won't dive to much
into them right now, but you'll notice the obvious reference in
``X-Cache``, but the advanced reader might also notice that ``Age`` has a
value of 81 despite Varnish reporting a cache miss, revealed by the
``X-Varnish`` header having just one number. For now, just make a mental
note of this - we'll cover the ``Age`` header later in this chapter.

The ``http`` command provided by `httpie` has multiple options. One thing
you'll want to do is use a fake ``Host``-header. If you are setting up a
Varnish server - or any other Web server - it's useful to test it properly
without pointing the real DNS name at the developmentserver. Here's an
example of how to do that::

        $ http -p Hh http://kly.no/ "Host: example.com"
        GET / HTTP/1.1
        Accept: */*
        Accept-Encoding: gzip, deflate
        Connection: keep-alive
        Host:  example.com
        User-Agent: HTTPie/0.8.0

        HTTP/1.1 200 OK
        Accept-Ranges: bytes
        Age: 0
        Connection: keep-alive
        Content-Encoding: gzip
        Content-Type: text/html
        Date: Wed, 25 Nov 2015 18:58:10 GMT
        Last-Modified: Tue, 24 Nov 2015 20:51:14 GMT
        Server: Really new stuff so people don't complain
        Transfer-Encoding: chunked
        Via: 1.1 varnish-v4
        X-Cache: MISS from access-gateway.hospitality.swisscom.com
        X-Varnish: 15577233

We can also add some other headers too. Let's make it interesting::

        $ http -p Hh http://kly.no/ "If-Modified-Since: Tue, 24 Nov 2015 20:51:14 GMT"
        GET / HTTP/1.1
        Accept: */*
        Accept-Encoding: gzip, deflate
        Connection: keep-alive
        Host: kly.no
        If-Modified-Since:  Tue, 24 Nov 2015 20:51:14 GMT
        User-Agent: HTTPie/0.8.0

        HTTP/1.1 304 Not Modified
        Age: 5
        Connection: keep-alive
        Content-Encoding: gzip
        Content-Type: text/html
        Date: Wed, 25 Nov 2015 18:59:28 GMT
        Last-Modified: Tue, 24 Nov 2015 20:51:14 GMT
        Server: Really new stuff so people don't complain
        Via: 1.1 varnish-v4
        X-Cache: MISS from access-gateway.hospitality.swisscom.com
        X-Varnish: 15880392 15904200

We just simulated what our browser did, and verified that it really was the
``If-Modified-Since`` header that made the difference earlier. You can have
multiple headers by just listing them after each other::

        $ http -p Hh http://kly.no/ "Host: example.com" "User-Agent: foo" "X-demo: bar"
        GET / HTTP/1.1
        Accept: */*
        Accept-Encoding: gzip, deflate
        Connection: keep-alive
        Host:  example.com
        User-Agent:  foo
        X-demo:  bar

        HTTP/1.1 200 OK
        Accept-Ranges: bytes
        Age: 10
        Connection: keep-alive
        Content-Encoding: gzip
        Content-Length: 24681
        Content-Type: text/html
        Date: Wed, 25 Nov 2015 19:01:08 GMT
        Last-Modified: Tue, 24 Nov 2015 20:51:14 GMT
        Server: Really new stuff so people don't complain
        Via: 1.1 varnish-v4
        X-Cache: MISS from access-gateway.hospitality.swisscom.com
        X-Varnish: 15759349 15809060

