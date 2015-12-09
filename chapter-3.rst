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

The chapter starts off with some theory, before digging into the more
practical aspects of Varnish.

Architecture
------------

Varnish architecture is not just of academic interest. Every single tool
you use is affected by it, and understanding the architecture will
hopefully help you understand why things work the way they do.

Varnish operates using two separate processes. The management process and
the child process. The child is where all the work gets done. A simplified
overview:

.. image:: img/c3/architecture.png

FIXME: New graphics.

The management process, which is also the parent process, handles
initialization, parsing of VCL, interactive administration through the CLI
interface, and basic monitoring of the child process.

You will notice that the log file lives right on the edge of the child
process. Varnish has two different logging mechanisms. The manager process
will typically log to `syslog`, like you would expect, but the child logs
to a shared memory log instead. This saves Varnish the trouble of worrying
about file locks and generally speeds things up greatly.

The shared memory log, abbreviated shmlog, is a round-robin style log file
which is usually a little less than 100MB large. It is split in two parts.
The smallest bit is the part for counters, used to keep track of any part
of Varnish that could be covered by a number, e.g. number of cache hits,
number of objects, and so forth. This part of the shmlog is named the VSM
and is 1MB by default.

FIXME: VTLA.

The biggest part of the shmlog is reserved for fifo-tyle VSL log entries,
directly related to requests typically. This is 80MB by default. Once those
80MB are filled, Varnish will continue writing to the log from the top. If
you wish to preserve any of the data, you need to extract it before it's
overwritten. Luckily for us, there are numerous tools designed to do just
this.

The other note-worthy part of the diagram above is how VCL is handled. VCL
is not a traditionally parsed configuration format, but a shim layer on top
of C and the varnish run time library (VRT). You are not so much
configuring Varnish with VCL as programming it. Once you've written your
VCL file, Varnish will translate it to C and compile it, then link it
directly into the child process.



