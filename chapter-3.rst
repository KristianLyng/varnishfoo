Varnish programs and operation
==============================

If you are working with Varnish, you need to know how to get information
from it, how to start and stop it and how to tweak it a bit.

This chapter will cover the basic architecture of Varnish, how Varnish
deals with logs, best practices for running Varnish and debugging your own
issues.

One of the biggest challenges with writing a book about any server-side
software on GNU/Linux in late 2015/early 2016 is that it's a moving target.
Depending on what distribution you are using, and what version, you may or
may not be using Systemd, upstart or System V init scripts. Even within
these categories, things vary. Advise that held true two year ago are
quickly becoming irrelevant.

The upside to all this is that this chapter is - out of necessity - very
clear on what is a Varnish-derived default or tool, and what is related to
packaging. Examples include tools such as ``varnishlog`` which is not
related to ``/var/log`` or ``journald`` at all, while default arguments
specified in ``/etc/default/varnish`` is highly distribution-dependent.
Then ``/etc/varnish/default.vcl`` falls somewhere in between.

When you're done reading this chapter, you'll know how to distinguish what
goes into Varnish and what comes out in the other end. You'll have an idea
of what it takes to operate Varnish in the long-term and some very basic
tuning needs.

What you will not learn in this chapter is what every single Varnish
parameter is for. Advanced tuning is a topic for a later chapter, as it's
mostly not relevant for every-day operation. Neither will you see much of
the Varnish Configuration Language (VCL). VCL requires a chapter or two all
by itself.

It's worth taking a look at Appendix A, or go directly to
https://www.varnish-cache.org/trac/wiki/VTLA and review some of the three
letter acronyms that are all too common in Varnish. They are used
extensively in the Varnish community, but are often ambiguous and
miss-leading. Because of this, we will use them sparsely.

Architecture
------------

Varnish architecture is not just of academic interest. Every single tool
you use is affected by it, and understanding the architecture will
hopefully help you understand why things work the way they do.

Varnish operates using two separate processes. The management process and
the child process. The child is where all the work gets done. A simplified
overview:

.. image:: img/c3/architecture.png

The management process, which is also the parent process, handles
initialization, parsing of VCL, interactive administration through the CLI
interface, and basic monitoring of the child process.

You will notice that the log file is drawn with a dotted line next to the
child process. It might be more correct to draw it directly into the child.
Varnish has two different logging mechanisms. The manager process will
typically log to `syslog`, like you would expect, but the child logs to a
shared memory log instead. This saves Varnish the trouble of worrying
about file locks and generally speeds things up greatly.

The shared memory log, abbreviated shmlog, is a round-robin style log file
which is usually a little less than 100MB large. It is split in two parts.
The smallest bit is the part for counters, used to keep track of any part
of Varnish that could be covered by a number, e.g. number of cache hits,
number of objects, and so forth. This part of the shmlog is 1MB by default.

The biggest part of the shmlog is reserved for fifo-style log entries,
directly related to requests typically. This is 80MB by default. Once those
80MB are filled, Varnish will continue writing to the log from the top. If
you wish to preserve any of the data, you need to extract it before it's
overwritten. Luckily for us, there are numerous tools designed to do just
this.

The other note-worthy part of the diagram above is how VCL is handled. VCL
is not a traditionally parsed configuration format, but a shim layer on top
of C and the Varnish run time library (VRT). You are not so much
configuring Varnish with VCL as programming it. Once you've written your
VCL file, Varnish will translate it to C and compile it, then link it
directly into the child process.

The observant reader will have noticed that ``varnish-agent`` is listed
twice. That is because the Varnish agent both reads the logs and
communicates with Varnish over the CLI protocol. Both ``varnishadm`` and
``varnish-agent`` are tools that can influence a running Varnish instance,
while any tool that only works on the shmlog is purely informational and
has no impact on the running Varnish instance. We will look at the agent
shortly.

Design principles in Varnish
----------------------------

Varnish changes frequently. Perhaps more frequently than a system
administrator would like. This is part of the design principles of Varnish.

Varnish is designed to work optimally for the most sensible use cases out
there, with as little configuration as possible. It's designed to be fast
and well behaving. But it is not designed to work for all scenarios
perfectly.

One of the consequences of this was that Varnish was designed with
multi-core 64-bit processes from day one. In 2015 this is not particularly
controversial, but it was not quite as easy to justify poor 32-bit support
in 2006. Using potentially thousands of threads was also not very common
back then.

The good news for you is that there is little in Varnish which is the way
it is because it was written once and can't be changed for fear of breaking
configurations. The down side happens to be the same. With most upgrades,
default values will change.

Practical consequences of this is that you generally don't have to worry
too much about explicitly turning on new features that just make sense. You
don't have to fiddle with every tunable parameter because the defaults are
changed as the Varnish community builds new knowledge on what constitute
good defaults.

If you have a normal computer, Varnish is built for that. If you wish to
run Varnish on a Pentium 4 with a CF card as storage, then Varnish is not
built for that. Patches to make it run better on platforms like that are
rejected if they make a mess for the primary use case: Proper
POSIX-operating systems (GNU/Linux, FreeBSD) running on proper hardware
(or in a VM with proper specs).

The different types of configuration
------------------------------------

Varnish uses three different configuration types. Certain things
must be configured before Varnish starts and can't be changed during
run-time. These settings are very limited, and are provided on the command
line. Even among command line arguments, several can be changed during run
time to some degree. Examples of command line arguments are things like
which working directory to use and how the management interface should be
configured.

The second type configuration primitive Varnish uses is run-time
parameters. These can be changed after Varnish has started, but depending
on the nature of the parameter it could take some time before the change is
visible. Parameters can be changed through the CLI, but need to be added as
a command line argument in a startup script to be permanent.

Parameters usually change some purely operational aspect of Varnish, not
policy. Default values for Varnish parameters are frequently tuned between
Varnish releases as feedback from real-world use reaches developers. As
such, most parameters can be left to the default values. Some examples of
what parameters can modify is the number of threads Varnish can use, the
size of the shared memory log, what user to run as and default timeout
values.

It's worth mentioning that many of the command line arguments passed to
``varnishd`` are really just short-hands for their respective parameters.

The third type of configuration primitive is the Varnish Configuration
Language script, usually just referred to as your VCL or VCL file. This is
where you will specify caching policies, what backends you have and how to
pick a backend. VCL can be changed at run-time with little or no penalty to
performance, but are not retroactive. If your VCL says "cache this for 5
years" and the content is cached, then changing your VCL to "cache
this for 1 minute" isn't going to alter the content that has already been
cached.

VCL is easily the most complex part of Varnish, but you can get a lot done
with very basic knowledge and a few tools. In this chapter, VCL is not a
focus, but is only briefly mentioned and used to avoid building bad habits.

To summarize:

Command line arguments
        Stored in startup-scripts. Takes effect on (re)starting Varnish.
        Some can be modified after startup, some can not. Often just a
        short-hand for setting default values for parameters. Examples:
        "how much memory should Varnish use", "what port should the
        management interface use", "what are the initial values for
        parameters"

Parameters
        Stored in startup-scripts, but can be changed at run-time. Upon
        re-start, the values from the startup scripts are used. Changes
        operational aspects of Varnish, often in great detail. Examples:
        "how large should the stack for a thread be", "what are the default
        values for cache duration", "what is the maximum amount of headers
        Varnish supports".

Varnish Configuration Language
        Stored in a separate VCL file, usually in ``/etc/varnish/``. Can be
        changed on-the-fly. Uses a custom-made configuration language to
        define caching policies. Examples: "Retrieve content for
        www.example.com from backend server at prod01.example.net", "Strip
        Cookie headers for these requests", "Output an error message for
        this URL".

Basic pre-runtime configuration
-------------------------------

Most aspects of Varnish can be changed during run-time, but there are a
handful of settings that need to be sorted out before you start
``varnishd`` up. Then there are those that are just better to get sorted
out right away.

FIXME: Systemd.

All of these options are handled by command line arguments to ``varnishd``.
These are rarely entered directly, but usually kept in
``/etc/default/varnish``, ``/etc/sysconfig/varnish`` or the systemd
equivalent. Before we look at those files, we'll look at running
``varnishd`` by hand. Whenever one of these files are referenced, remember
that they have different names on different platforms, and we'll get back
to the individual platforms later.

Before we look at the individual options, a few things are worth
mentioning: Varnish hasn't got the best track record of verifying
arguments. Just because Varnish starts with the arguments you provided
doesn't mean Varnish actually used them as you expected. Make sure you
double check if you deviate from the standard usage. Many arguments are
also short-hands for parameters, which we'll investigate in detail.

We'll start with the most important ones, instead of trying an alphabetical
listing. The examples listed here are from Varnish 4.1, which is slightly
changed from Varnish 4.0, notably adding `PROXY` support, which we will
investigate in later chapters.

The most important option is probably ``-a``, as it specifies what port
Varnish listens to. This argument differs somewhat between Varnish 4.0 and
4.1, but for most use cases that change is irrelevant.

For most practical purposes, you will just use ``-a :80``, but it's worth
noting that you can have Varnish listening on multiple sockets. This is
especially useful in Varnish 4.1 where you can have Varnish listen for
regular HTTP traffic on port 80, and SSL-terminated traffic through the
PROXY protocol on 127.0.0.1:1443 (for example). In Varnish 4.0, this was
accomplished by having a white-space separated list of ``address:port``
pairs::

        varnishd -b localhost:8080 ... -a "0.0.0.0:80 127.0.0.1:81"

In Varnish 4.1, you can supply multiple ``-a`` options instead.

Be careful. Varnish 4.0 will still accept multiple ``-a`` options, but only
the last one will be used.

Another subtle detail worth noting is that the ``varnishd`` default value
for ``-a`` is listening to port 80. But we have seen in previous
installations that a default Varnish installation listens on port 6081, not
port 80.

This is because port 6081 is a convention specified in
``/etc/default/varnish`` and similar. Here's an example from a default
Debian Jessie installation's ``/lib/systemd/system/varnish.service``::

        ExecStart=/usr/sbin/varnishd -a :6081 -T localhost:6082 \
                        -f /etc/varnish/default.vcl \
                        -S /etc/varnish/secret \
                        -s malloc,256m

The Varnish community tries to keep roughly the same defaults across
different platforms, so you will most likely find similar default values on
your own platform, whatever it may be.

In addition to telling Varnish where to listen, you need to tell it where
to get content. You can achieve this through the ``-b <address[:port]>``
argument, but that is typically limited to testing. In almost all other
cases you will want to specify an ``-f file`` option instead. ``-f file``
tells Varnish where to find the VCL file it should use, and that VCL file
will have to list any backend servers Varnish should use. When you use
``-b``, Varnish generates a simple VCL file for you behind the scenes::

        # varnishd -b pathfinder.kly.no:6085 -d
        Platform: Linux,4.2.0-0.bpo.1-amd64,x86_64,-smalloc,-smalloc,-hcritbit
        200 278     
        -----------------------------
        Varnish Cache CLI 1.0
        -----------------------------
        Linux,4.2.0-0.bpo.1-amd64,x86_64,-smalloc,-smalloc,-hcritbit
        varnish-4.0.2 revision bfe7cd1

        Type 'help' for command list.
        Type 'quit' to close CLI session.
        Type 'start' to launch worker process.

        start
        child (1443) Started
        200 0       

        Child (1443) said Child starts
        vcl.show boot
        200 67      
        vcl 4.0;
        backend default {
                    .host = "pathfinder.kly.no:6085";
        }

There are two more rather trivial, but important, options that all proper
Varnish installations use: ``-T`` and ``-S``. The ``-T`` option specifies a
listening socket for Varnish's management CLI. Since its introduction, the
convention has been to run the CLI interface on ``127.0.0.1:6082``, and
this is seen in most Varnish distributions. However the actual default for
the ``varnishd`` binary in Version 4 and newer is a random port and secret
file.

The ``-S`` argument lets you specify a file which contains a shared secret
that management tools can use to authenticate to Varnish. This is referred
to as the `secret file` and should contain random data, typically 256 bytes
worth. The content is never sent over the network, but used to verify
clients. All tools that are to interact with Varnish must be able to read
the content of this file.

The best part about both ``-T`` and ``-S`` is that you don't really have to
think too much about them. ``varnishadm`` and other tools that use the
management port can read those arguments directly from the ``shmlog``.
Example::

        # varnishd -b localhost:8080
        # netstat -nlpt
        Active Internet connections (only servers)
        Proto Recv-Q Send-Q Local Address      Foreign Address  State PID/Program name
        tcp        0      0 127.0.0.1:37860    0.0.0.0:*        LISTEN 2172/varnishd   
        tcp        0      0 0.0.0.0:80         0.0.0.0:*        LISTEN -               
        tcp6       0      0 :::80              :::*             LISTEN -               
        tcp6       0      0 ::1:35863          :::*             LISTEN 2172/varnishd   
        # varnishadm status
        Child in state running
        # varnishadm -T localhost:37860 status
        Authentication required
        # varnishadm -T localhost:37860 -S /var/lib/varnish/c496eeac1030/_.secret status
        Child in state running

Notice how ``varnishadm`` works with zero arguments, but if you start
adding ``-T`` you also have to specify the ``-S``. ``varnishadm`` and
``varnish-agent`` can re-use multiple options from ``varnishd`` (``-T``,
``-S``, ``-n``).

Many Varnish installations default to using ``-S /etc/varnish/secret``.
This is largely for historic reasons, but is a useful habit in case you end
up with multiple Varnish instances over multiple machines.

To summarize:

``-a <listen address>``
        Listen address. Typically set to :80. Format for specifying multiple listening
        sockets varies between Varnish 4.0 and 4.1.

``-b <address[:port]>``
        Specify backend address. Mostly for testing, mutually exclusive
        with ``-f`` (VCL).

``-f <vclfile>``
        Specify path to VCL file to use at startup.

``-T address:port``
        Set management/CLI listening address. Used for controlling Varnish.
        ``varnishd`` default is random, but ``127.0.0.1:6082`` is a common
        value used in default installations.

``-S <secret file>``
        Used to secure the management CLI. Points to a file with random
        data that both ``varnishd`` and management clients like
        ``varnishadm`` must have access to. Often set to
        ``/etc/varnish/secret``. Shouldn't matter where it is as long as
        ``varnishadm`` can read it and the shmlog.


Other useful ``varnishd`` arguments
-----------------------------------

You almost always want to specify an ``-s`` option. This is used to set how
large Varnish's cache will be, and what underlying method is used to cache.
This is an extensive topic, but for now, use ``-s malloc,<size>``, for
example ``-s malloc,256M``. For most systems, using ``-s malloc,<size>``,
where ``<size>`` is slightly less than the system memory is a good
practice. We will come back to this in later chapters.

You've seen ``varnishd -d`` in examples, and ``varnishd -F`` is similar in
that it runs ``varnishd`` in the foreground.  ``-d`` can be used to test as
it will connect your terminal to the Varnish CLI. ``-F`` is less useful, as
you wont be able to control Varnish without running ``varnishadm`` in a
different shell. In normal use, both ``-d`` and ``-F`` are considered
rather exotic.

``-n dir`` is used to control the Varnish working directory and name. The
directory argument can either just be a simple name, like ``-n
frontserver``, in which case Varnish will use a working directory named
``frontserver``  in its default path, typically
``/var/lib/varnish/frontserver/``. You can also provide a full path
instead. Whenever you alter ``-n``, you need to provide that same ``-n``
argument to any Varnish-tool you want to use. There are two use cases for
``-n``:

1. Running multiple Varnish instances on the same machine. Give each a
   different ``-n`` to make this work.
2. Run ``varnishd`` as a user that doesn't have access to the default
   working directory. This can be handy during development or testing to
   avoid having to start Varnish as the root user.

If you look in the working directory, you can see your shmlog file and the
compiled VCL, among other things::

        # ls /var/lib/varnish/
        # varnishd -b localhost:8080
        # ls /var/lib/varnish/
        3da4db675c6b
        # ls /var/lib/varnish/3da4db675c6b/
        _.secret  _.vsm  vcl.QakoKN_T.so
        # varnishd -b localhost:8110 -a :81 -n test
        # ls /var/lib/varnish/
        3da4db675c6b  test
        # ls /var/lib/varnish/test/
        _.secret  _.vsm  vcl.Lnayret_.so
        # netstat -nlpt
        Active Internet connections (only servers)
        Proto Recv-Q Send-Q Local Address    Foreign Address   State    PID/Program name
        tcp        0      0 127.0.0.1:34504  0.0.0.0:*         LISTEN   502/varnishd    
        tcp        0      0 127.0.0.1:42797  0.0.0.0:*         LISTEN   262/varnishd    
        tcp        0      0 0.0.0.0:80       0.0.0.0:*         LISTEN   -               
        tcp        0      0 0.0.0.0:81       0.0.0.0:*         LISTEN   -               
        tcp6       0      0 ::1:39843        :::*              LISTEN   262/varnishd    
        tcp6       0      0 :::80            :::*              LISTEN   -               
        tcp6       0      0 :::81            :::*              LISTEN   -               
        tcp6       0      0 ::1:43220        :::*              LISTEN   502/varnishd    

A common task you have is to verify that your VCL is correct before you try
loading it. This can be done implicitly with the ``-C`` option. It will
either give you a syntax error for your VCL or a whole lot of C code, which
happens to be your VCL translated to C::

        # cat /etc/varnish/test.vcl 
        vcl 4.0;

        broken VCL backend localhost {
                .host = "localhost";
                .port = "8080";
        }
        # varnishd -C -f /etc/varnish/test.vcl 
        Message from VCC-compiler:
        Expected one of
                'acl', 'sub', 'backend', 'director', 'probe', 'import',  or 'vcl'
        Found: 'broken' at
        ('input' Line 3 Pos 1)
        broken VCL backend localhost {
        ######------------------------

        Running VCC-compiler failed, exited with 2

        VCL compilation failed
        # echo $?
        2

Note that the return-code of ``varnishd -C -f vcl`` is false if the VCL
fails to compile. Fixing the VCL::

        # cat /etc/varnish/test-ok.vcl 
        vcl 4.0;

        backend localhost {
                .host = "localhost";
                .port = "8080";
        }
        # varnishd -C -f /etc/varnish/test-ok.vcl
        /* ---===### include/vcl.h ###===--- */

        /*
         * NB:  This file is machine generated, DO NOT EDIT!
         *
         * Edit and run generate.py instead
         */

        struct vrt_ctx;
        struct req;
        (......)

        # echo $?
        0

A more useful example::

        # varnishd -C -f /etc/varnish/test.vcl >/dev/null && echo "VCL OK" || echo "VCL NOT OK" 
        Message from VCC-compiler:
        Expected one of
                'acl', 'sub', 'backend', 'director', 'probe', 'import',  or 'vcl'
        Found: 'broken' at
        ('input' Line 3 Pos 1)
        broken VCL backend localhost {
        ######------------------------

        Running VCC-compiler failed, exited with 2

        VCL compilation failed
        VCL NOT OK
        # varnishd -C -f /etc/varnish/test-ok.vcl >/dev/null && echo "VCL OK" || echo "VCL NOT OK" 
        VCL OK

Perhaps not the prettiest syntax check, but it gets the job done.

There are other options, but they are quite advanced and generally best
left alone. We will cover them in more advanced chapters.

