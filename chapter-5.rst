Intelligent traffic routing
===========================

.. warning::

   I expect this chapter to change significantly throught its creation, and
   possibly throught the creation of the rest of the book. It should be
   seen in context with chapter 4, introduction to VCL.

   I advise against reviewing the pedagogical aspects of the chapter until
   the text is complete (as in: a summary exists). Or until this warning is
   removed.

   As of this writing, I have not done a thorough technical review of the
   details as they relate to Varnish 4.1 or newer. The principles explained
   should all be correct, but some constants and commands might have
   changed.

Now that we've looked at basic VCL, it's time to start talking about how to
direct traffic. While many Varnish installations only have a single
backend, all the big ones have numerous backend servers.

Varnish supports this quite well, and provides a small but powerful set of
tools that will allow you to direct traffic.

There are two terms that are at the core of this chapter. The backend
director, usually just called director, which is a collection of multiple
backend servers, and the health check probe.

Both directors and probes can be either very simple or quite elaborate.
We'll start off looking closely at probes, then move on to directors to tie
it together.

Two often overlooked features is the fact that directors are now dynamic -
you can add and remove (predefined) backends from regular VCL - and that
directors can be nested. We'll look at both these features and what they
offer you.

A closer look at a backend
--------------------------

We've looked at backends only briefly at backends so far. Only specifying
the host and port-options. But backends can have a few more options.


+-----------------------+------------+------------------------------------------------------+
| Option                | Default    | Description                                          |
+=======================+============+======================================================+
| host                  |            | Mandatory host-name or IP of the backend.            |
|                       |            | Has to resolve to max 1 IPv4 address and 1 IPv6      |
|                       |            | address. In other words: Your backends can be        |
|                       |            | dual-stack (both IPv4/IPv6), but not load-balanced   |
|                       |            | with DNS round-robin.                                |
+-----------------------+------------+------------------------------------------------------+
| port                  | 80         | TCP port number to connect to.                       |
|                       |            |                                                      |
+-----------------------+------------+------------------------------------------------------+
| host_header           |            | Optional Host-header to add. This is mainly useful   |
|                       |            | for health probes, if the backend requires a         |
|                       |            | valid or specific Host-header.                       |
+-----------------------+------------+------------------------------------------------------+
| connect_timeout       | From       | Timeout waiting for the TCP connection to be         |
|                       | parameters | established. Should be low, as this is usually       |
|                       |            | handled by the operating system. Factors that are    |
|                       |            | relevant: Geographic distance, virtualization.       |
+-----------------------+------------+------------------------------------------------------+
| first_byte_timeout    | From       | Timeout waiting for the very first byte of a reply.  |
|                       | parameters | This is application-dependant. Typically, an         |
|                       |            | application will send the entire response in one go  |
|                       |            | after generating it, so this is basically            |
|                       |            | how long you expect/allow the application to generate|
|                       |            | a response.                                          |
+-----------------------+------------+------------------------------------------------------+
| between_bytes_timeout | From       | The timeout between individual read-operations after |
|                       | parameters | the backend has started sending data. Should rarely  |
|                       |            | be long, depending on the application. This is       |
|                       |            | essentially a means to detect stalled connections.   |
+-----------------------+------------+------------------------------------------------------+
| max_connections       | unlimited  | The maximum number of connections Varnish will open  |
|                       |            | to a given backend.                                  |
+-----------------------+------------+------------------------------------------------------+
| probe                 |            | Health check definition or reference.                |
|                       |            | Covered in detail in the next sub-chapter.           |
+-----------------------+------------+------------------------------------------------------+

Over a number of years, the default values for various timeouts have been
tweaked frequently to adapt to what has proven to work. This is specially
true for ``connect_timeout``. Every once in a while you might run across
systems with greatly increased timeouts. A few questions you should ask
yourself:

1. How long would a user actually wait.
2. What are you _actually_ waiting for.
3. In what circumstances would you want to send traffic to a backend this
   slow?

If you are working with actual users, a connect_timeout of 600s is just
pointless. First, the connection is usually established by the operating
system, which means that even if the application is heavily loaded, the
actual TCP connection would be fast. Secondly, none of your users will wait
for 10 minutes to get cat-pictures.

If the application is used by non-humans (e.g.: API interface), then
allowing slightly higher timeouts generally make sense.

At the end of the day, timeouts are there to avoid using up resources on
the Varnish-host waiting for backends that will never respond. By timing
out, you might be able to deliver stale content to a user (who would be
none the wiser) instead of waiting until the user leaves.

Basic health probes
-------------------

A health check allows you to test that a backend is working as it should
before you start fetching resources from it. In its simplest form, it is
just a URL on a backend:

.. code:: VCL

   backend foo {
           .host = "192.168.0.1";
           .probe = {
                   .url = "/healthcheck";
           }
   }

This will set up a health check where Varnish will send frequent requests
to ``/healthcheck``. As long as the server responds with ``200 OK`` within
the standard time frame, traffic will go as normal. If it stops responding,
or doesn't respond with ``200 OK``, then Varnish will not send traffic to
it at all, except health checks.

You can also provide more details for the probe.

.. code:: VCL

   backend foo {
           .host = "192.168.0.1";
           .probe = {
                   .request = "GET /healthcheck HTTP/1.1"
                              "Host: example.com";
                   .expected_response = 206;
                   .interval = 10s;
                   .threshold = 5;
                   .window = 15;
           }
   }

This probe definition uses a complete request instead of just a URL, which
can be useful if your health check needs some special headers for example.
It also overrides the expected response code, expecting 206 instead of 200.
None of the probe options are mandatory, however.

+-------------------+-------------+-------------------------------------------+
| Option            | Default     | Description                               |
+===================+=============+===========================================+
| url               | "/"         | The URL to request.                       |
+-------------------+-------------+-------------------------------------------+
| request           |             | The exact request, which overrides the    |
|                   |             | URL if specified. Each string will have   |
|                   |             | \\r\\n added at the end.                  |
+-------------------+-------------+-------------------------------------------+
| expected_response | 200         | Response code that the backend needs to   |
|                   |             | reply with for Varnish to consider it     |
|                   |             | healthy.                                  |
+-------------------+-------------+-------------------------------------------+
| timeout           | 2s          | The timeout for the probe.                |
+-------------------+-------------+-------------------------------------------+
| interval          | 5s          | How often to send a probe.                |
+-------------------+-------------+-------------------------------------------+
| window            | 8           | How many recent probes to consider when   |
|                   |             | determining if a backend is healthy.      |
+-------------------+-------------+-------------------------------------------+
| threshold         | 3           | How many probes within the last window    |
|                   |             | must have been successful to consider the |
|                   |             | backend healthy.                          |
+-------------------+-------------+-------------------------------------------+
| initial           | threshold-1 | When starting up, how polls in the window |
|                   |             | should be considered good. If set to 0,   |
|                   |             | the backend will not get any traffic until|
|                   |             | Varnish has probed it "threshold" amount  |
|                   |             | of times.                                 |
+-------------------+-------------+-------------------------------------------+

Window, threshold and initial are all related. The idea of a window is that
you might not want to disable a backend just because it fails a single
probe. With the default setting, Varnish will evaluate the last 8 probes
sent when checking if a backend is healthy. If at least 3 of them were OK,
then the backend is considered healthy.

One issue with this logic is that when Varnish starts up, there are no
health probes in the history at all. With only "window" and "threshold",
this would require Varnish to send at least 3 probes by default before it
starts sending traffic to a server. That would mean some considerable
downtime if you restarted your Varnish server.

To solve this problem, Varnish has the "initial" value. When there is no
history, Varnish will consider "initial" amount of health probes good. The
default value is relative to "threshold" in such a way that just a single
probe needs to be sent for Varnish to consider the backend healthy.

As you can imagine, if you have to define all these options for all your
backends, you end up with a lot of identical copy-pasted code blocks. This
can be avoided by using named probes instead.

.. code:: VCL

   probe myprobe {
           .url = "/healthcheck";
           .interval = 2s;
           .window = 5;
           .threshold = 2;
   }

   backend one {
           .host = "192.168.2.1";
           .probe = myprobe;
   }

Reviewing health probe status
.............................

There are a few different ways to review health state. Let's start with
``varnishlog``::

        # varnishlog -g raw -i Backend_health
         0 Backend_health - default Still healthy 4--X-RH 8 3 8 0.000425 0.000562 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 8 3 8 0.000345 0.000508 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 8 3 8 0.000401 0.000481 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 8 3 8 0.000437 0.000470 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 8 3 8 0.000381 0.000448 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 8 3 8 0.000334 0.000419 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 8 3 8 0.000298 0.000389 HTTP/1.1 200 OK

This is fairly cryptic, but you get the general idea I suppose. Note the
``-g raw`` which is necessary because the ``Backend_health`` log-tag is not
part of a session, so grouping by session wouldn't work.

You'll see one line like this for each health probe sent.

A closer look at ``4--X-RH`` will tell you how the probe was handled. The
``4`` tells you it's IPv4, the ``X`` says it was sent OK, the ``R`` tells
you a response was read OK and the ``H`` says the health probe was
"healthy": The response was what we expected. In this case, a ``200 OK``.

You can get similar information from ``varnishadm``, in two different ways.
The first is the oldest way, and is "hidden"::

        # varnishadm 
        200        
        -----------------------------
        Varnish Cache CLI 1.0
        -----------------------------
        Linux,4.6.0-0.bpo.1-amd64,x86_64,-smalloc,-smalloc,-hcritbit
        varnish-4.0.2 revision bfe7cd1

        Type 'help' for command list.
        Type 'quit' to close CLI session.

        varnish> help
        200        
        help [command]
        ping [timestamp]
        auth response
        quit
        banner
        status
        start
        stop
        vcl.load <configname> <filename>
        vcl.inline <configname> <quoted_VCLstring>
        vcl.use <configname>
        vcl.discard <configname>
        vcl.list
        param.show [-l] [<param>]
        param.set <param> <value>
        panic.show
        panic.clear
        storage.list
        vcl.show <configname>
        backend.list
        backend.set_health matcher state
        ban <field> <operator> <arg> [&& <field> <oper> <arg>]...
        ban.list

        varnish> help -d
        200        
        debug.panic.master
        debug.sizeof
        debug.panic.worker
        debug.fragfetch
        debug.health
        hcb.dump
        debug.listen_address
        debug.persistent
        debug.vmod
        debug.xid
        debug.srandom

        varnish> debug.health
        200        
        Backend default is Healthy
        Current states  good:  8 threshold:  3 window:  8
        Average responsetime of good probes: 0.000486
        Oldest                                                    Newest
        ================================================================
        4444444444444444444444444444444444444444444444444444444444444444 Good IPv4
        XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX Good Xmit
        RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR Good Recv
        HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH Happy

        varnish> 

The ``debug.health`` command has been around for a long time, but was never
really intended for general use.

It does give you a history, though.

Let's see what happens if we disable our front page, which is what we're
probing::

        # chmod 000 /var/www/html/index.html 
        # varnishlog -g raw -i Backend_health
         0 Backend_health - default Still healthy 4--X-R- 6 3 8 0.000402 0.000408 HTTP/1.1 403 Forbidden
         0 Backend_health - default Still healthy 4--X-R- 5 3 8 0.000323 0.000408 HTTP/1.1 403 Forbidden
         0 Backend_health - default Still healthy 4--X-R- 4 3 8 0.000297 0.000408 HTTP/1.1 403 Forbidden
         0 Backend_health - default Still healthy 4--X-R- 3 3 8 0.000294 0.000408 HTTP/1.1 403 Forbidden
         0 Backend_health - default Went sick 4--X-R- 2 3 8 0.000407 0.000408 HTTP/1.1 403 Forbidden
         0 Backend_health - default Still sick 4--X-R- 1 3 8 0.000307 0.000408 HTTP/1.1 403 Forbidden
         0 Backend_health - default Still sick 4--X-R- 0 3 8 0.000385 0.000408 HTTP/1.1 403 Forbidden
         0 Backend_health - default Still sick 4--X-R- 0 3 8 0.000350 0.000408 HTTP/1.1 403 Forbidden
         0 Backend_health - default Still sick 4--X-R- 0 3 8 0.000290 0.000408 HTTP/1.1 403 Forbidden

First, observe that the ``4--X-RH`` tag has changed to ``4--X-R-`` instead.
This tells you that Varnish is still able to send the probe and it still
receives a valid HTTP response, but it isn't happy about it - it's not a
``200 OK``.

Further, look at the three next numbers. Further up they were ``8 3 8``.
Now they start out at ``6 3 8`` (because I was a bit slow to start the
varnishlog-command).

The first number is the number of good health probes in the window(6), the
next is the threshold(3) the last is the size of the window (8). For each
bad health probe, the number of good health probes we have go down by 1.
Once it breaches the threshold, Varnish reports that the backend "Went
sick". Up until that point, Varnish would still send traffic to that
backend. The number of good health probes goes all the way down to 0.

If we fix our backend, let's see the reverse happening::

        # chmod a+r /var/www/html/index.html ; varnishlog -g raw -i Backend_health
         0 Backend_health - default Still sick 4--X-RH 1 3 8 0.000365 0.000398 HTTP/1.1 200 OK
         0 Backend_health - default Still sick 4--X-RH 2 3 8 0.000330 0.000381 HTTP/1.1 200 OK
         0 Backend_health - default Back healthy 4--X-RH 3 3 8 0.000329 0.000368 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 4 3 8 0.000362 0.000366 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 5 3 8 0.000327 0.000357 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 6 3 8 0.000366 0.000359 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 7 3 8 0.000332 0.000352 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 8 3 8 0.000358 0.000354 HTTP/1.1 200 OK
         0 Backend_health - default Still healthy 4--X-RH 8 3 8 0.000295 0.000339 HTTP/1.1 200 OK

Even though our backend starts behaving well immediately, Varnish will
consider it "sick" until it has reached the threshold for number of health
probes needed.

The other numbers in the log output are timing for sending and receiving
the response.

The threshold and window-mechanism is there to avoid "flapping". But it is
far from perfect.

.. warning::

   You generally do not want to use the debug-commands unless you really
   know what you are doing.  Things such as ``debug.panic.master`` will
   kill Varnish (by design), and is included exclusively for development,
   QA and testing. Similarilly, ``debug.srandom`` will let you forcibly
   set the "random seed", of Varnish, making the random numbers
   predictable. Useful for unit-tests, horrible for production.

.. FIXME: Need to update this for varnish 4.1 and include other states than
   the usual suspects.

Load balancing of backends
--------------------------

Varnish has always offered a few different ways to provide load balancing
of backends. With Varnish 4, this is done through varnish modules. Mostly
through the `directors` vmod.

The idea is simple enough: Provide multiple backends that share the load of
a single application. But it is not always that simple.

In varnish, a load balancing scheme is usually referred to as a backend
director, or just director.

We'll start with the simplest type of load balacning.

Basic round-robin and random load balancing
...........................................

Round-robin load balancing will simply rotate which backend is used. At the
end of the day, all backends will have received the same amount of
requests.

The random-director is almost just as simple. The traffic is randomly
distributed among the backends. At the end of the day, that means each
backend has received the same amount of requests.

The biggest difference between the two is that the random-director also
provides you with a means to adjust the `weight` of the distribution. You
can tell it to send more traffic to a more powerful backend than the rest,
for example.

.. code:: VCL

   import directors;

   backend one {
           .host = "192.168.2.1";
           .port = "80";
   }
   backend two {
           .host = "192.168.2.2";
           .port = "80";
   }
   sub vcl_init {
           new rrdirector = directors.round_robin();
           rrdirector.add_backend(one);
           rrdirector.add_backend(two);
   }

   sub vcl_recv {
           set req.backend_hint = rrdirector.backend();
   }

This example creates a director-object called `rrdirector`, of the
round-robin type. It then adds two backends to it.

In `vcl_recv`, we tell Varnish to use this director as backend.

You can do similar things with the random director.

.. code:: VCL

   import directors;

   backend one {
           .host = "192.168.2.1";
           .port = "80";
   }
   backend two {
           .host = "192.168.2.2";
           .port = "80";
   }
   sub vcl_init {
           new radirector = directors.random();
           radirector.add_backend(one, 5.0);
           radirector.add_backend(two, 1.0);
   }

   sub vcl_recv {
           set req.backend_hint = radirector.backend();
   }

Notice the second argument to `radirector.add_backend()`. This is the
relative weight. You can pick basically any scale you want, as long as it
is relative to the other backends. In this example, the backend called
`one` will get five times as much traffic as the one called `two`.

You can add any number of backends to the same director, and you can use
any number of directors.



