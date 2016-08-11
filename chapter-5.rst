Intelligent traffic routing
===========================

.. warning::

   I expect this chapter to change significantly throught its creation, and
   possibly throught the creation of the rest of the book. It should be
   seen in context with chapter 4, introduction to VCL.

   I advise against reviewing the pedagogical aspects of the chapter until
   the text is complete (as in: a summary exists). Or until this warning is
   removed.

   That said, the content itself is correct and you are welcome to read it
   and coment.

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

.. FIXME: Varnishlog output and varnishstat and vanrishadm

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



