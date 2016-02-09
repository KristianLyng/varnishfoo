Introducing VCL
===============

.. role:: vcl(code)
      :language: VCLSnippet

.. default-role:: vcl

.. warning::

   I expect this chapter to change significantly throught its creation, and
   possibly throught the creation of the rest of the book.

   I advise against reviewing the pedagogical aspects of the chapter until
   the text is complete (as in: a summary exists). Or until this warning is
   removed.

   That said, the content itself is correct and you are welcome to read it
   and coment.

The Varnish Configuration Language is a small custom programming language
that gives you the mechanism to hook into Varnish's request handling state
engine at various crucial stages.

Mastering VCL is a matter of learning the language itself, understanding
what the different states mean and how you can utilize the tools that are
you at your disposal.

This chapter focuses on the language itself and a small subset of the
states you can affect. The goal is to give you the skills needed to write
robust VCL that allows Varnish to cache efficiently.

VCL is officially documented in the :title:`vcl` manual page (``man vcl``),
but you would do well if you revisit the state diagrams provided in
appendix A.  Throughout this chapter, those state diagrams will be used as
reference and you will learn how to read them.

What you will not find in this chapter is an extensive description of every
keyword and operator available. That is precisely what the manual page is
for.

Since VCL leans heavily on regular expressions, there is also a small
cheat sheet towards the end, including VCL snippets.

Working with VCL
----------------

VCL is normally stored in ``/etc/varnish/``. Most startup-scripts usually
refer to ``/etc/varnish/default.vcl``, but you are free to call it whatever
you want, as long as your startup scripts refer to them.

To use new VCL, you have two choices:

1. Restart Varnish, losing all cache
2. Reload the VCL without restarting Varnish

During development of entirely new VCL, the first option is usually the
best. Reloading VCL without dropping the cache is a benefit in production,
but when you are testing your VCL, old (potentially "wrong") objects can
add a level of confusion that is best avoided. An example of this is if you
are trying to fix re-write rules. You might end up caching content
incorrectly due to re-write rules, then fix your rules but find the old
content due to the previously wrong VCL.

Reloading VCL is always done through the CLI, but most startup scripts
provide shorthands that does the job for you. You can do it manually using
``varnishadm``::

        # varnishadm vcl.list
        active          0 boot

        # varnishadm vcl.load foo-1 /etc/varnish/default.vcl 
        VCL compiled.
        # varnishadm vcl.list
        active          0 boot
        available       0 foo-1

        # varnishadm vcl.use foo-1
        VCL 'foo-1' now active
        # varnishadm vcl.list
        available       0 boot
        active          0 foo-1

This also demonstrates that Varnish operates with multiple loaded VCLs, but
only one can be active at a time. The VCL needs a run-time name, which can
be anything. The ``boot`` name refers to the VCL varnish booted up with
initially.

Compiling and loading the VCL is done with ``vcl.load <name> <file>``, and
this is where any syntax errors would be detected. After it is loaded, you
need to call ``vcl.use`` to make it the active VCL. You can also switch
back to the previous one with ``vcl.use`` if you like.

A more practical way is to use your startup scripts. E.g::

        # systemctl reload varnish
        # varnishadm vcl.list
        available       0 boot
        available       0 foo-1
        active          0 4ca9d8e9-25d0-4b52-b4b1-247f038061a6

This example from Debian demonstrates that the startup script will pick a
random VCL name, load it and then issue ``vcl.use`` for you.

Over time, VCL files might "pile up" in Varnish, taking up some resources.
This is specially true for backends, where even unused VCL will have active
health checks if health checks are defined in the relevant VCL. You can
explicitly discard old VCL with ``vcl.discard``::

        # varnishadm vcl.list
        available       0 boot
        available       0 foo-1
        active          0 4ca9d8e9-25d0-4b52-b4b1-247f038061a6

        # varnishadm vcl.discard boot

        # varnishadm vcl.list
        available       0 foo-1
        active          0 4ca9d8e9-25d0-4b52-b4b1-247f038061a6

This is not necessary if you restart Varnish instead of reloading.

As of Varnish 4.1.1, Varnish also has a concept of cooldown time, where old
VCL will be set in a "cold" state after a period of time. While "cold",
health checks are not active.

Hello World
-----------

VCL can be split into three groups:

1. Global declarations. Backends and ACLs fit into this category.
2. Initialization functions. This almost exclusively about setting up
   Varnish Modules.
3. Request handling.

Of the three, the third one is by far the biggest part of most VCL files.
In this mode, VCL deals with a single request. Either as seen as a client
request or a soon-to-be-executed backend request.

The following is a minimal VCL that defines a backend and sets a custom
response header:

.. sourcecode:: VCL

        vcl 4.0;

        backend foo {
                .host = "127.0.0.1";
                .port = "8080";
        }

        sub vcl_deliver {
                set resp.http.X-hello = "Hello, world";
        }

The first line is a VCL version string. Right now, there is only one valid
VCL version. Even for Varnish 4.1, the VCL version is 4.0. This is intended
to make transitions to newer versions of Varnish simpler. Every VCL file
starts with `vcl 4.0;` for now.

Next up, we define a backend server named ``foo``. We set the IP of the
backend and port. You can have multiple backends, as long as they have
different names. As long as you only define a single backend, you don't
need to explicitly reference it anywhere, but if you have multiple backends
you need to be explicit about which to use when.

Last, but not least, we provide some code for the `vcl_deliver` state.  If
you look at the ``cache_req_fsm.svg`` in appendix A, you will find
`vcl_deliver` at the bottom left. It is the last VCL before the request is
delivered back to the client.

.. image:: img/c4/vcl_deliver.png

The `set resp.http.X-hello = "Hello, world";` line demonstrates how you
can alter variables. `set <variable> = <value>;` is the general syntax
here. Each VCL state has access to different variables. The different
variables are split up in families: `req`, `bereq`, `beresp`, `resp`,
`obj`, `client` and `server`.

In the state diagram (again, see Appendix A), looking closer at the box
where `vcl_deliver` is listed, you will find `resp.*` and `req.*` listed,
suggesting that those families of variables are
available to us in `vcl_deliver`.

In our specific example, `resp.http.X-hello` refers to the artificial
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

And there you are, a custom VCL header. You can also use `unset variable;`
to remove headers, and overwrite existing headers.

.. code:: VCL

        vcl 4.0;

        backend foo {
                .host = "127.0.0.1";
                .port = "8080";
        }

        sub vcl_deliver {
                set resp.http.X-hello = "Hello, world";
                unset resp.http.X-Varnish;
                unset resp.http.Via;
                unset resp.http.Age;
                set resp.http.Server = "Generic Webserver 1.0";
        }

The result would be::

        # systemctl restart varnish
        # http -p h localhost:6081
        HTTP/1.1 200 OK
        Accept-Ranges: bytes
        Connection: keep-alive
        Content-Encoding: gzip
        Content-Type: text/html
        Date: Sun, 07 Feb 2016 12:24:36 GMT
        ETag: "2b60-52b20c692a380-gzip"
        Last-Modified: Sat, 06 Feb 2016 21:37:34 GMT
        Server: Generic Webserver 1.0
        Transfer-Encoding: chunked
        Vary: Accept-Encoding
        X-hello: Hello, world

Basic language constructs
-------------------------

Grab a rain coat, you are about to get a bucket full of information thrown
at you. Many of the concepts in the following example will be expanded upon
greatly.

.. code:: VCL
        
        # Comments start with hash
        // Or C++ style //
        /* Or
         * multi-line C-style comments
         * like this.*/
        vcl 4.0;
       
        # White space is largely optional
        backend foo{.host="localhost";.port="80";}

        # vcl_recv is an other VCL state you can modify. It is the first
        # one in the request chain, and we will discuss it in great detail
        # shortly.
        sub vcl_recv {
                # You can use tilde (~) to do regular expression matching
                # text strings, or various other "logical" matchings on
                # things suchs as IP addresses
                if (req.url ~ "^/foo") {
                        set req.http.x-test = "foo";
                } elsif (req.url ~ "^/bar") {
                        set req.http.x-test = "bar";
                }
        }

        # You can define the same VCL function as many times as you want.
        # Varnish will concatenate them together into one big function.
        sub vcl_recv {
                # Use regsub() to do regular expression substitution.
                # regsub() returns a string and takes the format of
                # regsub(<input>,<expression>,<substitution>)
                set req.url = regsub(req.url, "cat","dog");

                # The input of regsub() doesn't have to match where you
                # are storing it, even if it is the most common form.
                set req.http.x-base-url = regsub(req.url, "\?.*$","");

                # Be warned: regsub() only does a single substitution. If
                # you want to substitute all occurences of the pattern, you
                # need to use regsuball() instead. So regsuball() is
                # equivalent to the "/g" option you might have seen in
                # other languages.
                set req.http.X-foo = regsuball(req.url,"foo","bar");
        }

        # You can define your own sub routines, but they can't start with
        # vcl_. Varnish reserves all VCL function names that start with
        # vcl_ for it self.
        sub check_request_method {
                # Custom sub routines can be accessed anywhere, as long as
                # the variables and return methods used are valid where the
                # subroutine is called.
                if (req.method == "POST" || req.method == "PUT") {
                        # The "return" statement is a terminating statement
                        # and serves to exit the VCL processing entirely,
                        # until the next state is reached.
                        #
                        # Different VCL states have different return
                        # statements available to them. A return statement
                        # tells varnish what to do next.
                        #
                        # In this specific example, return (pass); tells
                        # varnish to bypass the cache for this request.
                        return (pass);
                }
        }

        sub vcl_recv {
                # Calling the custom-sub is simple.
                # There are no arguments or return values, because under
                # the hood, "call" just copies the VCL into where the call
                # was made. It is not a true function call.
                call check_request_method;

                # As a consequence, you can not write recursive custom
                # functions.

                # You can use == to check for exact matches. Both for
                # strings and numbers. Varnish either does the right thing
                # or throws a syntax error at you.
                if (req.method == "POST") {
                        # This will never execute. The 'check_request_method'
                        # already checked the request method and if it was
                        # POST, it would have issued "return(pass);"
                        # already, thereby terminating the VCL state and
                        # never reaching this code.
                        set req.http.x-post = "yes";
                }

                # The Host header contains the verbatim Host header, as
                # supplied by the client. Some times, that includes a port
                # number, but typically only if it is user-visible (e.g.:
                # the user entered http://www.example.com:8080/)
                if (req.http.host == "www.example.com" && req.url == "/login") {
                        # return (pass) is an other return statement. It
                        # instructs Varnish to by-pass the cache for this
                        # request.
                        return (pass);
                }
        }

        # Last but not least: You do not have to specify all VCL functions.
        # Varnish provides a built-in which is always appended to your own
        # VCL, and it is designed to be sensible and safe.

.. note::

   All VCL code examples are tested for syntax errors against Varnish
   4.1.1, and are provided in complete form, with the only exception beng
   that smaller examples will leave out the `backend` and `vcl 4.0;` lines
   to preserve brevity.

More on return-statements
-------------------------

A central mechanism of VCL is the return-statement, some times referred to
as a terminating statement. It is important to understand just what this
means.

All states end with a return-statement. If you do not provide one, VCL
execution will "fall through" to the built-in VCL, which always provides a
return-statement.

Similarly, if you provide multiple definitions of `vcl_recv` or some
other function, they will all be glued together as a single block of code.
Any `call foo;` statement will be in-lined (copied into the code). In other
words, the following two examples produce the same C code:

With custom function:

.. code:: VCL

   sub clean_host_header {
           # Strip leading www in host header to avoid caching the same
           # content twice if it is accessed both with and without a
           # leading wwww.
           set req.http.Host = regsub(req.http.Host, "^www\.","");
   }

   sub vcl_recv {
           call clean_host_header;
   }

Without:

.. code:: VCL

   sub vcl_recv {
           set req.http.Host = regsub(req.http.Host, "^www\.","");
   }

Which form you chose is a matter of style. However, it is usually helpful
to split logical bits of code into separate custom functions. This lets you
split cleaning of Host header into a single block of code that doesn't get
mixed with device detection (for example).

But because the custom functions are in-lined, a `return (pass);` issued in
a custom-function would mean that the custom function never returned - that
VCL state was terminated and Varnish would move on to the next phase of
request handling.

Each state has different return methods available. You can see these in the
request flow chart, at the bottom of each box.

Built-in VCL
------------

Varnish works out of the box with no VCL, as long as a back-end is
provided. This is because Varnish provides built-in VCL, sometimes
confusingly referred to as the default VCL for historic reasons.

This VCL can never be removed or overwritten, but it can be bypassed. You
can find it in ``/usr/share/doc/varnish/builtin.vcl`` or similar for your
distribution. It is included in Appendix C for your convenience.

The built-in VCL is designed to make Varnish behave safely on any site. It
is a good habit to let it execute whenever possible. Chapter 1 already
demonstrated how you can influence the cache with no VCL at all, and it
should be a goal to provide as simple VCL as possible.

Each of the built-in VCL functions will be covered individually when we are
dealing with the individual states.



