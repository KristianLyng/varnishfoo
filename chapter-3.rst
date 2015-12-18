Architecture and operation
==========================

If you are working with Varnish, you need to know how to get information
from it, how to start and stop it and how to tweak it a bit.

This chapter explains the architecture of Varnish, how Varnish deals with
logs, best practices for running Varnish and debugging your Varnish
installation.

When you're done reading this chapter, you'll know how to distinguish what
goes into Varnish and what comes out in the other end. You'll have an idea
of what it takes to operate Varnish in the long-term and some very basic
tuning needs.

What you will not learn in this chapter is what every single Varnish
parameter is for. Advanced tuning is a topic for a later chapter, as it's
mostly not relevant for every-day operation. Neither will you see much of
the Varnish Configuration Language (VCL). VCL requires a chapter or two all
by itself.

The Varnish developer use a lot of three letter acronyms for many of the
components and concepts that are covered in this chapter. We will only use
them sparsely and where they make sense. Many of them are ambiguous and
some refer to different things depending on context. An effort is made to
keep a list of the relevant acronyms and their meaning. That list can be
found at https://www.varnish-cache.org/trac/wiki/VTLA, with a copy
attached in Appendix B.

Architecture
------------

Varnish architecture is not just of academic interest. Every single tool
you use is affected by it, and understanding the architecture will
make it easier to understand how to use Varnish.

Varnish operates using two separate processes. The management process and
the child process. The child is where all the work gets done. A simplified
overview:

.. image:: img/c3/architecture.png

The management process, which is also the parent process, handles
initialization, parsing of VCL, interactive administration through the CLI
interface, and basic monitoring of the child process.

Varnish has two different logging mechanisms. The manager process will
typically log to `syslog`, like you would expect, but the child logs to a
shared memory log instead. This shared memory can be accessed by Varnish
itself and any tool that knows where to find the log and how to parse it.

A shared memory log was chosen over a traditional log file for two reasons.
First of all, it is quite fast, and doesn't eat up disk space. The second
reason is that a traditional log file is often limited in information.
Compromises have to be made because it is written to disk and could take up
a great deal of space if everything you might need during a debug session
was always included. With a shared memory log, Varnish can add all
information it has, always. If you are debugging, you can extract
everything you need, but if all you want is statistics, that's all you
extract.

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

An other note-worthy part of the diagram above is how VCL is handled. VCL
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
has no direct impact on the running Varnish instance.

Design principles in Varnish
----------------------------

Varnish is designed to solve real problems and then largely get out of your
way. If the solution to your problem is to buy more RAM, then Varnish isn't
going to try to work around that issue. If you want to use Varnish to proxy
SSH connection, then by all means, go ahead, but your patches to make it
easier are unlikely to be accepted.

Varnish also uses a great deal of ``assert()`` statements and other fail
safes in the code base. An ``assert()`` statement is a very simple
mechanism. ``assert(x == 0);`` means "make sure x is 0". If x is `not` 0,
Varnish will abort. In most cases, that means the entire child process
shuts down, only to have the manager start it back up. You lose all
connections, you lose all cache.

Hopefully, you wont run into assert errors. They are there to handle what
is believed to be the unthinkable. A more realistic example can be:

- Create an object, called `foo`. Set ``foo.magic`` to ``0x123765``.
- Store `foo` in the cache.
- (time passes)
- Read `foo` from the cache.
- Assert that ``foo.magic`` is till ``0x123765``.

This is a simple safe guard against memory corruption, and is used for
almost all data structures that are kept around for a while in Varnish. An
arbitrary `magic` value is picked during development, and whenever the
object is used, that value is read back and checked. If it doesn't match,
your memory was corrupted. Either by something Varnish did or by the host
it's running on.

Assert errors are there to make sure that you don't use a corrupt system.
The theory is that if something so bad that the code doesn't account for it
happens, then it's better to just stop and start up. You might lose some
up-time (usually in the order of a couple of seconds), but at least your
Varnish instance is back up in a predictable state.

If Varnish does hit an assert error, it will (try to) log it to syslog. In
addition to that, it keeps the last `panic` message available through
``varnishadm panic.show``::

        # varnishadm panic.show 
        Child has not panicked or panic has been cleared
        Command failed with error code 300
        #


The different categories of configuration
-----------------------------------------

Varnish has three categories of configuration settings. Certain things
must be configured before Varnish starts and can't be changed during
run-time. These settings are very limited, and are provided on the command
line. Even among command line arguments, several can be changed during run
time to some degree. The working directory to be used and the management
interface are among the settings that are typically provided as command
line arguments.

The second category of configuration Varnish uses is the run-time
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

Command line arguments
----------------------

Command line arguments are rarely entered directly, but usually kept in
``/lib/systemd/system/varnish.service`` or similar startup scripts.
Before we look at startup scripts, we'll look at running
``varnishd`` by hand.

Varnish hasn't got the best track record of verifying arguments. Just
because Varnish starts with the arguments you provided doesn't mean Varnish
actually used them as you expected. Make sure you double check if you
deviate from the standard usage.

Some command line arguments are really just short hands for parameters,
which is why you will some times find parameters that seem to overlap with
command line arguments.

Most command line arguments haven't changed much since their introduction,
but some might have had their more complex variants extended or tweaked a
bit.

``-a`` specifies what port Varnish listens to, and as such, is probably one
of the most important arguments you will use. This argument differs
somewhat between Varnish 4.0 and 4.1 if you try to use multiple listening
sockets, but for most use cases that change is irrelevant.

Most installations simply use ``-a :80``, but it's worth noting that you
can have Varnish listening on multiple sockets. This is especially useful
in Varnish 4.1 where you can have Varnish listen for regular HTTP traffic
on port 80, and SSL-terminated traffic through the PROXY protocol on
127.0.0.1:1443 (for example). In Varnish 4.0, this is accomplished by
having a white-space separated list of ``address:port`` pairs::

        varnishd -b localhost:8080 ... -a "0.0.0.0:80 127.0.0.1:81"

In Varnish 4.1, you can supply multiple ``-a`` options instead.

Be careful. Varnish 4.0 will still accept multiple ``-a`` options, but only
the last one will be used.

Another subtle detail worth noting is that the ``varnishd`` default value
for ``-a`` is listening to port 80. But we have seen in previous
installations that a default Varnish installation listens on port 6081, not
port 80.

This is because port 6081 is a convention specified in startup scripts.
Here's an example from a default Debian Jessie installation's
``/lib/systemd/system/varnish.service``::

        ExecStart=/usr/sbin/varnishd -a :6081 -T localhost:6082 \
                        -f /etc/varnish/default.vcl \
                        -S /etc/varnish/secret \
                        -s malloc,256m

In addition to telling Varnish where to listen, you need to tell it where
to get content. You can achieve this through the ``-b <address[:port]>``
argument, but that is typically limited to testing. In almost all other
cases you will want to specify an ``-f file`` option instead. ``-f file``
tells Varnish where to find the VCL file it should use, and that VCL file
will have to list any backend servers Varnish should use. When you use
``-b``, Varnish generates a simple VCL file for you behind the scenes::

        # varnishd -b pathfinder.kly.no:6085
        # varnishadm vcl.show boot
        vcl 4.0;
        backend default {
            .host = "pathfinder.kly.no:6085";
        }

There are two more important options that all proper Varnish installations use:
``-T`` and ``-S``. The ``-T`` option specifies a listening socket for Varnish's
management CLI. Since its introduction, the convention has been to run the CLI
interface on ``127.0.0.1:6082``, and this is seen in most Varnish
distributions. However the actual default for the ``varnishd`` binary in
Version 4 and newer is a random port and secret file.

The ``-S`` argument lets you specify a file which contains a shared secret
that management tools can use to authenticate to Varnish. This is referred
to as the `secret file` and should contain data, typically 256 bytes randomly
generated at installation. The content is never sent over the network, but
used to verify clients. All tools that are to interact with Varnish must be
able to read the content of this file.

The nice thing about both ``-T`` and ``-S`` is that you don't really have to
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
This is largely for historic reasons, but is a good habit in case you end
up with multiple Varnish instances over multiple machines.

Last, but not least, you almost always want to specify an ``-s`` option. This
is used to set how large Varnish's cache will be, and what underlying method is
used to cache.  This is an extensive topic, but for now, use ``-s
malloc,<size>``, for example ``-s malloc,256M``. For most systems, using ``-s
malloc,<size>``, where ``<size>`` is slightly less than the system memory is a
good practice. Malloc has been a good choice for a decade, and recently ``-s
file`` was formally deprecated.

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

``-s <method,options>``
        Used to control how large the cache can be and the storage engine.
        Alternatives are ``-s persistent,(options)``, ``-s
        file,(options)`` and ``-s malloc,(size)``. ``-s malloc,256m`` (or
        more) is strongly recommended.

Other useful ``varnishd`` arguments
-----------------------------------

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

Startup scripts
---------------

Varnish Cache development focuses on GNU/Linux and FreeBSD, with some
occasional attention directed towards Solaris.

But the vast majority of Varnish Cache operational focus is on GNU/Linux,
more specifically on Fedora-derived systems, such as Red Hat Enterprise
Linux (RHEL), Fedora and CentOS, or on Debian and Ubuntu. These are the
distributions where Varnish packaging is best maintained and they deliver
top-quality Varnish packages.

The startup scripts provided for those distributions are solid, and should
be used whenever possible.

This, combined with Varnish developers' habit of frequently changing Varnish
default behavior to the better means that few changes are needed to get a
basic Varnish installation going.

Since before GNU/Linux existed, System V-styled init scripts have been used
to boot Unix-like machines. This has been the case for GNU/Linux too. Until
recently, when ``upstart`` and ``systemd`` came around. By now, all the
major GNU/Linux use or are preparing to use ``systemd``. That means that if
you have older installations, the specific way Varnish is started will be
different than how it's started on newer installations. In the end, though,
it all boils down to one thing: you have to know into which file you need
to add your ``varnishd`` start-up arguments, and what commands to use to
start and stop it.

Where your distribution keeps its configuration will vary, but in short:

- They all keep VCL and secret files in ``/etc/varnish`` by default.
- With systemd, startup arguments are kept in
  ``/lib/systemd/system/varnish.service`` for both distribution families.
  That file should be copied to ``/etc/systemd/system/varnish.service`` if
  you mean to modify it.
- Recent RHEL/Fedora packages use ``/etc/varnish/varnish.params``. A
  similar strategy is expected for other distributions too in the future.
- Before systemd, Debian/Ubuntu kept startup arguments in
  ``/etc/default/varnish``.
- Before systemd, Red Had Enterprise Linux/CentOS/Fedora kept startup
  arguments in ``/etc/sysconfig/varnish``.

For starting and stopping, it's a little simpler:

- If you have systemd, use ``systemctl
  <start|stop|reload|restart> varnish.service``.
- If have System V scripts, use ``service varnish
  <stop|start|reload|restart>``.

To enable or disable starting Varnish at boot, you can use ``systemctl
<enable|disable> varnish.service`` on Systemd-systems.

The biggest benefit of using the distribution-provided startup script,
beyond not having to write one yourself, is that all the little details are
handled correctly according to your distribution. The most common mistake
seen on systems using custom-scripts is to not issue ``ulimit -n``, which
has often limited Varnish to only 1024 file descriptors. This will directly
influence how many concurrent connections and threads Varnish can handle.
The distribution-provided scripts handle this for you, and more.

Parameters
----------

Run-time parameters in Varnish allow you to modify aspects of Varnish that
should normally be left alone. The default values are meant to suite the
vast majority of installations, and usually do. However, parameters exist
for a reason.

Varnish 4.0 has 93 parameters, which can be seen using ``varnishadm`` on a
running Varnish server::

        # varnishadm param.show
        acceptor_sleep_decay       0.9 (default)
        acceptor_sleep_incr        0.001 [s] (default)
        acceptor_sleep_max         0.050 [s] (default)
        auto_restart               on [bool] (default)
        ban_dups                   on [bool] (default)
        ban_lurker_age             60.000 [s] (default)
        ban_lurker_batch           1000 (default)
        ban_lurker_sleep           0.010 [s] (default)
        between_bytes_timeout      60.000 [s] (default)
        (...)

You can also get detailed information on individual parameters::

        # varnishadm param.show default_ttl
        default_ttl
                Value is: 120.000 [seconds] (default)
                Default is: 120.000
                Minimum is: 0.000

                The TTL assigned to objects if neither the backend nor the VCL
                code assigns one.

                NB: This parameter is evaluated only when objects are
                created.To change it for all objects, restart or ban
                everything.

Changing a parameter takes effect immediately, but is not always
immediately visible, as the above `default_ttl` demonstrates. Changing
`default_ttl` will affect any new object entered into the cache, but not
what is already there.

Many of the parameters Varnish exposes are meant for tweaking very
complicated parts of Varnish, and even the developers may not know the
exact consequence of modifying it, this is usually demonstrated through a
warning, e.g.::

        # varnishadm param.show timeout_linger
        timeout_linger
                Value is: 0.050 [seconds] (default)
                Default is: 0.050
                Minimum is: 0.000

                How long time the workerthread lingers on an idle session
                before handing it over to the waiter.
                When sessions are reused, as much as half of all reuses happen
                within the first 100 msec of the previous request completing.
                Setting this too high results in worker threads not doing
                anything for their keep, setting it too low just means that
                more sessions take a detour around the waiter.

                NB: We do not know yet if it is a good idea to change this
                parameter, or if the default value is even sensible.  Caution
                is advised, and feedback is most welcome.

Heeding this warning is usually a good idea.

You can change parameters using ``varnishadm param.set``::

        # varnishadm param.set default_ttl 15

        # varnishadm param.show default_ttl  
        default_ttl
                Value is: 15.000 [seconds]
                Default is: 120.000
                Minimum is: 0.000

                The TTL assigned to objects if neither the backend nor the VCL
                code assigns one.

                NB: This parameter is evaluated only when objects are
                created.To change it for all objects, restart or ban
                everything.

However, this is stored exclusively in the memory of the running Varnish
instance, if you want to make it permanent, you need to add it to the
``varnishd`` command line as a ``-p`` argument. E.g.::

        # varnishd -b localhost:1111 -p default_ttl=10 -p prefer_ipv6=on

Most parameters can and should be left alone, but reading over the list is
a good idea. The relevant parameters are referenced when we run across the
functionality.

Tools: ``varnishadm``
---------------------

You've already seen ``varnishadm`` demonstrated numerous times. There isn't
much to it.

You can run ``varnishadm`` in two different modes: interactive, or with the
CLI command you wish to issue as part of the ``varnishadm`` command line.
The examples have so far used the latter form, e.g.::

        # varnishadm status
        Child in state running

This is very useful for scripting and one-off commands.

If you just type ``varnishadm``, you enter the interactive mode::

        # varnishadm 
        200        
        -----------------------------
        Varnish Cache CLI 1.0
        -----------------------------
        Linux,4.2.0-0.bpo.1-amd64,x86_64,-smalloc,-smalloc,-hcritbit
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
        
        varnish> quit
        500        
        Closing CLI connection
        # 

Both modes are functionally identical. The biggest benefit of using the
interactive mode might be that you don't have to worry about yet an other
level of quotation marks once you start dealing with more complex commands
than ``vcl.load`` and ``param.list``. For now, it's just a matter of style.
An other difference is that ``varnishadm`` in interactive mode also offer
rudimentary command line completion, something your shell might not.

The CLI, and ``varnishadm`` by extension, uses HTTP-like status codes.
If a command is issued successfully, you will get a ``200`` in return.
These are just similar to HTTP, though, and do not match fully.

When you are using ``varnishadm``, you are communicating with Varnish
through the management process, over a regular TCP connection. It is
possible to run ``varnishadm`` from a remote host, even if it is not
generally advised. To accomplish this, you must:

- Use a ``-T`` option that binds the CLI to an externally-available port.
  E.g.: Not ``-T localhost:6082``.
- Copy the `secret file` from the Varnish host to the one you wish to run
  ``varnishadm`` from.
- Make sure all firewalls etc are open.
- Issue ``varnishadm`` with ``-T`` and ``-S``.

However, be advised: CLI communication is NOT encrypted. The authentication
is reasonably secure, in that it is not directly vulnerable to replay
attacks (the shared secret is never transmitted), but after authentication,
the connection can be hijacked. Never run ``varnishadm`` over an untrusted
network. In fact, the best practice is to keep it bound to localhost.

Tools: ``varnishstat``
----------------------

``varnishstat`` is the simplest of all the log-related tools, yet also one
of the most useful tools. In its simplest form, it opens a real-time view
of Varnish-counters::

        Uptime mgt:   6+17:40:49              Hitrate n:       10       38       38
        Uptime child: 6+17:40:49                 avg(n):   0.9943   0.9727   0.9727

          NAME                        CURRENT       CHANGE      AVERAGE            
        MAIN.uptime                    582049         1.00         1.00
        MAIN.sess_conn               11321763        25.96        19.00
        MAIN.client_req              11492571        25.96        19.00
        MAIN.cache_hit               11278670        25.96        19.00
        MAIN.cache_miss                 15614         0.00          .
        MAIN.backend_conn                3851         0.00          .
        MAIN.backend_reuse             568470         1.00          .
        MAIN.backend_toolate             3832         0.00          .
        MAIN.backend_recycle           572307         1.00          .
        MAIN.fetch_length              567578         1.00          .
        MAIN.fetch_chunked               4423         0.00          .
        MAIN.fetch_304                    320         0.00          .
        MAIN.pools                          2         0.00          .
        MAIN.threads                      200         0.00          .
        MAIN.threads_created              200         0.00          .
        MAIN.busy_sleep                     3         0.00          .
        ↓ MAIN.uptime                                                          INFO
        Child process uptime:
        How long the child process has been running.

``varnishstat`` reads counters from the shmlog and makes sense of them, is
the simple explanation. It can also be accessed in manners better suited
for scripting, either ``varnishstat -1`` (plain text), ``varnishstat -j``
(JSON) or ``varnishstat -x`` (XML). The real-time mode collects data over
time, to provide you with meaningful interpretation. Knowing that you have
had 11278670 cache hits over the last six and a half days might be
interesting, but knowing that you have 25.96 cache hits per seconds right
now is far more useful. The same can be achieved through ``varnishtat -1``
and similar by simply executing the command twice and comparing the values.

The interactive variant requires a slightly bigger window than shown above
to expose all the information though.

.. image:: img/c3/varnishstat-1.png

Starting in the upper left, you'll see some durations:

.. image:: img/c3/varnishstat-3.png

This tells you the uptime of the management and child process. Every once
in a while, these numbers might differ. That could happen if you manually
issue a ``stop`` command followed by a ``start`` command through
``varnishadm``, or if Varnish is hitting a bug and throwing an ``assert()``
error.

Looking closer at the upper right corner, you will see six numbers:

.. image:: img/c3/varnishstat-2.png

The first line tells you the time frame of the second. It will start at "1
1   1" and grow to eventually read "10  100  1000". When you start
``varnishstat``, it only has one second of data, but it collects up to a
thousand seconds.

The ``avg(n)`` line tells you the cache hit rate during the last ``(n)``
seconds, where, `n` refers to the line above. In this example, we have a
cache hit rate of 1.0 (aka: 100%) for the last 10 seconds, 0.9969 (99.69%)
for the last 100 seconds and 0.9951 (99.51%) for the last 236 seconds.
Getting a high cache hit rate is almost always good, but it can be a bit
tricky. It reports how many client requests were served by cache hits, but
it doesn't say anything about how many backend requests were triggered. If
you are using grace mode, cache hit rate can easily be 100% while you are
issuing requests to the web server.

The main area shows 7 columns:

``NAME``
        This one should be obvious. The name of the counter.

``CURRENT``
        The actual value. This is the only value seen in ``varnishstat -j``
        and similar.

``CHANGE``
        "Change per second". Or put an other way: The difference between
        the current value and the value read a second earlier. Can be read
        as "cache hit per second" or "client reuqests per second".

``AVERAGE``
        Average change of the counter, since start-up. The above example
        has had 19 client requests per second on average. It's basically
        ``CURRENT`` divided by ``MAIN.uptime``.

``AVERAGE_n``
        Similar the cache hit rate, this is the average over the last `n`
        seconds. Note that the header says ``AVERAGE_1000`` immediately,
        but the actual time period is the same as the ``Hitrate n:`` line,
        so it depends on how long ``varnishstat`` has been running.

An other note on the interactive ``varnishstat`` is that it does not
display all counters by default. By default, it will hide any counter with
a value of 0, in the interest of saving screen real-estate. In addition to
hiding counters without a value, Varnish now has a concept of verbosity
levels (new in Version 4.0). By default, it only displays informational
counters.

A few key bindings are worth mentioning:

``<UP>``/``<DOWN>``/``<Page UP>``/``<Page Down>``
        Scroll the list of counters.

``<d>``
        Toggle displaying unseen counters.
``<v>``
        Similar to ``<d>``, but only cycles through verbosity levels
        instead of toggling everything.
``<q>``
        Quit.

A note on threads
-----------------

Traditionally there was an exception to this rule. Varnish used to ship
with an extremely conservative value for ``thread_pool_min`` and
``thread_pool_max``, which are the parameters that govern how many `worker
threads` Varnish uses. On Varnish 3, you would typically have 10 threads by
default. Varnish would spin up more on demand, but 10 threads is extremely
low, even for very low-traffic sites.

Varnish uses one `worker thread` per active TCP connection. A typical user
can easily set up 5 or more concurrent TCP sessions, depending on the
content and browser, so with just 10 threads, your site is tuned for
roughly 2-3 concurrent users. Again, Varnish will spin up more threads on
demand, but this is still not ideal.

With Varnish 4.0, this default value was finally brought up to where it
needs to be. Varnish 4.0 (and newer) defaults to starting up 200 threads,
with a maximum value of 10000. This is suitable for the vast majority of
web sites out there.

FIXME: not done

