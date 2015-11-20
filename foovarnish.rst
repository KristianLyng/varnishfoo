===========
Foo Varnish
===========

The personal introduction
-------------------------

This is the only chapter written in first person.

I've worked on Varnish since the of autumn 2008, first for Redpill Linpro,
then Varnish Software, then, after a brief pause, for Redpill Linpro again.
Over the years I've written code, written Varnish modules and blog posts,
held more training courses than most, written most of the training
material, and, I hope helped shape the Varnish community in a positive way.

I love writing. Educating. But today I find myself in a position where the
training material is out of my hands - I no longer work for Varnish
Software. And besides, writing training material only gets you so far.

This is my solution. I will write a book (again). Because I can't imagine
that I'll ever finish it if I actually try to write a whole book in one go,
I will publish one chapter at a time on my blog. This is the first chapter
of that book. At the time of this writing, I don't have a name. So I'm
calling it "Foo Varnish", at least for now. I call everything else foo* so
I might as well keep that tradition.

You will find the source on https://github.com/KristianLyng/foovarnish.
I accept pull requests (Before you ask, no, not blindly). Even though a
chapter might be published on my blog - or on paper, it's never finished.

I intend to cover as much Varnish-related content as possible, from
administration to web development and infrastructure. And my hope is that
one day, this will be good enough that it will be worth printing as more
than just a leaflet.

What is Varnish
---------------

Varnish is a web server.

Unlike most web servers, Varnish does not read content from a hard drive,
or run programs that generates content from SQL databases. Varnish acquires
the content from other web servers. Usually it will keep a copy of that
content around in memory for a while to avoid fetching the same content
multiple times, but not necessarily.

There are numerous reasons you might want Varnish:

1. Your web server/application is a beastly nightmare where performance is
   measured in page views per hour - on a good day.
2. Your content needs to be available from multiple geographically diverse
   locations.
3. Your web site consists of numerous different little parts that you need
   to glue together in a sensible manner.
4. Your boss bought a service subscription and now has to justify the
   budget post.
5. You like Varnish.
6. ???

Varnish is designed around two simple concepts: Give you the means to fix
or work around technical issues. And speed. Speed was largely handled very
early on, and Varnish is quite simply fast. This is achieved by being, at
the core, simple. The less you have to do for each request, the more
requests you can handle.

In this book, you'll learn how Varnish works, how, when and why to use
Varnish, and more.

History
-------

.. _VG: http://www.vg.no

The Varnish project begun in 2005. The issue to be solved was that of
`VG`_,  a large Norwegian news site (or alternatively a tiny international
site). The first release came in 2006, and worked flawlessly for exactly
one site: www.vg.no. In 2008, Varnish 2.0 came, which opened Varnish up to
sites that looked and behaved like www.vg.no. As time progressed and more
people started using Varnish, Varnish has been adapted to a large and
varied set of use cases.

From the beginning, the project was administered through Redpill Linpro,
with the majority of development being done by Poul-Henning Kamp through
his own company. In 2010, Varnish Software sprung out from Redpill Linpro.
Varnish Cache has always been a free software project, and while Varnish
Software has been custodians of the infrastructure and large contributors
of code and cash, the project is independent.

Varnish Plus came around some time during 2011, depending on how you count.
It was the result of somewhat conflicting interests. Varnish Software had
customer obligations that required features, and the development power to
implement them, but they did not necessarily align with the goals and time
frames of Varnish Cache. Varnish Plus became a commercial test-bed for
features that were not /yet/ in Varnish Cache for various reasons. Some of
the features have since trickled into Varnish Cache proper in one way or an
other (streaming, surrogate keys, and more), and some have still to make
it. Some may never make it. This book will focus on Varnish Cache proper,
but will reference Varnish Plus where it makes sense.

With Varnish 3.0, released in 2011, varnish modules started becoming a
big thing. These are modules that are not part of the Varnish Cache code
base, but are loaded at run-time to add features such as cryptographic hash
functions (vmod-digest) and memcached. The number of vmods available grew
quickly, but even with Varnish 4.1, the biggest issue with them were that
they required source-compilation for use. That, however, is being fixed
almost as I am writing this sentence.

Today, Varnish is used by too many sites to mention. From CDNs (plural), to
tiny blogs and everything in-between.

More than just cache
--------------------

Varnish caches content, but can do so much more. In 2008, it was used to
rewrite URLs, normalize HTTP headers and similar things. Today, it is used
to implement paywalls (whether you like them or not), API metering, load
balancing, CDNs, and more.

Varnish has a powerful configuration language, the Varnish Configuration
Language (VCL). This isn't parsed the traditional way a configuration file
is, but is translated to C code, compiled and linked into the running
Varnish. From the beginning, it was possible to bypass the entire
translation process and provide C code directly, which was never
recommended. With Varnish modules, it's possible to write proper modules to
replace the in-line C code that was used in the past.

There is also a often overlooked Varnish agent that provides a HTTP REST
interface to managing Varnish. This can be used to extract metrics, review
or optionally change configuration, stop and start Varnish, and more. The
agent lives on https://github.com/varnish/vagent2, and is packaged for most
distributions today. There's also a commercial administration console that
builds further on the agent.
