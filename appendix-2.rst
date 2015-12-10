Appendix B: ``varnishd`` arguments
==================================

This is a copy of ``varnishd -h`` from Varnish 4.1. Ironically, this is not
a valid argument, and there is no argument to explicitly print help output
for ``varnishd``, but any invalid argument will do the trick::

        /usr/local/sbin/varnishd: option requires an argument -- 'h'
        usage: varnishd [options]
            -a address[:port][,proto]    # HTTP listen address and port (default: *:80)
                                         #   address: defaults to loopback
                                         #   port: port or service (default: 80)
                                         #   proto: HTTP/1 (default), PROXY
            -b address[:port]            # backend address and port
                                         #   address: hostname or IP
                                         #   port: port or service (default: 80)
            -C                           # print VCL code compiled to C language
            -d                           # debug
            -F                           # Run in foreground
            -f file                      # VCL script
            -h kind[,hashoptions]        # Hash specification
                                         #   -h critbit [default]
                                         #   -h simple_list
                                         #   -h classic
                                         #   -h classic,<buckets>
            -i identity                  # Identity of varnish instance
            -j jail[,jailoptions]        # Jail specification
                                         #   -j unix[,user=<user>][,ccgroup=<group>]
                                         #   -j none
            -l vsl[,vsm]                 # Size of shared memory file
                                         #   vsl: space for VSL records [80m]
                                         #   vsm: space for stats counters [1m]
            -M address:port              # Reverse CLI destination
            -n dir                       # varnishd working directory
            -P file                      # PID file
            -p param=value               # set parameter
            -r param[,param...]          # make parameter read-only
            -S secret-file               # Secret file for CLI authentication
            -s [name=]kind[,options]     # Backend storage specification
                                         #   -s malloc[,<size>]
                                         #   -s file,<dir_or_file>
                                         #   -s file,<dir_or_file>,<size>
                                         #   -s file,<dir_or_file>,<size>,<granularity>
                                         #   -s persistent (experimental)
            -T address:port              # Telnet listen address and port
            -t TTL                       # Default TTL
            -V                           # version
            -W waiter                    # Waiter implementation
                                         #   -W epoll
                                         #   -W poll
