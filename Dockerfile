FROM nginx:latest
RUN apt-get update && apt-get -y install make docutils-common gawk locales varnish git-core rst2pdf inkscape moreutils
ADD . /vf
WORKDIR /vf
RUN echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
RUN locale-gen
ENV LC_ALL=en_US.utf8
RUN LC_ALL=en_US.utf8 make all -j 4
RUN rm -r /usr/share/nginx/html
RUN cp -a build /usr/share/nginx/html
RUN chmod a+r -R /usr/share/nginx/html
