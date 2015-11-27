FROM debian:jessie

RUN systemctl set-default basic.target
RUN apt-get update && apt-get -y install	\
	 wget					\
	 vim					\
	 man					\
	 build-essential			\
	 net-tools				\
	 bash-completion			\
	 git-core				\
	 autoconf				\
	 netcat					\
	 libwww-perl				\
	 libmicrohttpd-dev			\
	 libcurl4-gnutls-dev			\
	 libedit-dev				\
	 libpcre3-dev				\
	 libncurses5-dev			\
	 python-demjson				\
	 python-docutils			\
	 libtool				\
	 nodejs					\
	 httpie					\
	 apache2				\
	 pkg-config	

RUN apt-get -y install varnish
RUN sed -i 's/80/8080/g' /etc/apache2/ports.conf /etc/apache2/sites-enabled/0*
ADD .vimrc /root/.vimrc
ADD foo.sh /usr/lib/cgi-bin/foo.sh
RUN chmod a+x /usr/lib/cgi-bin/foo.sh
RUN a2enmod cgi
CMD ["/bin/bash"]
