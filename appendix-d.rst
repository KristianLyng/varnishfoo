Appendix D: Regular expression cheat sheet
==========================================

Varnish uses Perl-style regular expressions, or "pcre". There are books
written about the subject, but here's a small list of common tasks that you
may want with Varnish.

.. code:: VCL

   sub vcl_recv {
           # Regular matching. Use ^ to anchor it to the beginning of the line.
           if (req.url ~ "^/html") { 
                   # ...
           }

           # Or $ to match the end of the line
           if (req.url ~ ".gif$") {
                   # ...
           }

           # . matches any single character, * means "zero or more of the previous
           # character"
           # Combined, .* matches everything or nothing.

           if (req.url ~ "^/content/.*txt$") {
                   # Matches /content/txt, /content/asfasftxt, /content/foo.txt,
                   # but not /content/txt?foo=bar.
           }
           
           # \ can be used to "escape" the next character.
           if (req.url ~ ".html") {
                # This matches /foo.html, but also /html/blatti
                # because . is a wildcard.
           }
           if (req.url ~ "\.html") {
                # Matches /foo.html, but not /html/blatti, but does match
                # /html/blatti.html and /foo.html?foo=bar
           }

           # regsub(string,regex,replacement) to replace the content of a
           # string.
           # This creates a "X-Url" request-header that is identical to the
           # URL, but changes upper-case HTML to lowercase html.
           # The URL itself is unchanged.
           set req.http.x-url = regsub(req.url, "HTML","html");

           # Remove redundant leading www
           set req.http.host = regsub(req.http.host,"^www\.","");

           # regsuball() is identical to regsub(), but replaces ALL
           # occurences of the regular expression, not just the first.
           # This changes /foo/bar/foo/blatti to /bar/bar/bar/blatti.
           set req.url = regsuball(req.url, "foo","bar");
        
           # Parentheses can be used to group logic, and | as a logical
           # "or" operator.
           if (req.url ~ "^/(html|css|img)") {
                   # Matches /html, /css and /img
           }
        
           # You can also reference groups in regsub(), and use [] as
           # character-classes. A character class is a list of characters.
           # If it starts with ^, it matches any characters EXCEPT the ones
           # listed.

           # The following extracts the "magic" get-argument from a URL and
           # puts it into a request header called "x-magic".
           # It does this by first ensuring we've passed the question-mark,
           # then skipping all characters up until "magic=", then starting
           # a group using parentheses. The content of the group is one or
           # more of any character except &.
           # + acts just like * , but where * means "0 or more", + means "1
           # or more"
           set req.http.x-magic = regsub(req.url, "\?.*magic=([^&]+)","\1");
   }
