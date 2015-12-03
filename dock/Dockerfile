FROM devboks

RUN apt-get -y install varnish apache2
RUN sed -i 's/80/8080/g' /etc/apache2/ports.conf /etc/apache2/sites-enabled/0*
ADD .vimrc /root/.vimrc
ADD foo.sh /usr/lib/cgi-bin/foo.sh
RUN chmod a+x /usr/lib/cgi-bin/foo.sh
RUN a2enmod cgi
CMD ["/bin/bash"]
