FROM nginx:latest
RUN apt-get update && apt-get -y install make docutils-common gawk locales varnish git-core
ADD . /usr/share/nginx/html
WORKDIR /usr/share/nginx/html
RUN echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
RUN locale-gen
ENV LC_ALL=en_US.utf8
RUN LC_ALL=en_US.utf8 make all -j 1
