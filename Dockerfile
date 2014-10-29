FROM phusion/baseimage:0.9.10

MAINTAINER Open Knowledge

# Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

ENV DEBIAN_FRONTEND noninteractive 

ENV HOME /root
ENV CKAN_HOME /usr/lib/ckan/default
ENV CKAN_CONFIG /etc/ckan/default
ENV CKAN_DATA /var/lib/ckan

# Install required packages
RUN apt-get -y update && \
     apt-get -y install python-minimal python-dev python-virtualenv && \
     apt-get -y install libevent-dev libpq-dev nginx-light && \
     apt-get -y install apache2 libapache2-mod-wsgi && \
     apt-get -y install postfix libxml2-dev libxslt1-dev libgeos-c1 && \
     apt-get -y install build-essential git wget curl 

# Install CKAN
RUN virtualenv $CKAN_HOME
RUN mkdir -p $CKAN_HOME $CKAN_CONFIG $CKAN_DATA
RUN chown www-data:www-data $CKAN_DATA

ADD ./requirements.txt $CKAN_HOME/src/ckan/requirements.txt
RUN $CKAN_HOME/bin/pip install -r $CKAN_HOME/src/ckan/requirements.txt
ADD . $CKAN_HOME/src/ckan/
RUN $CKAN_HOME/bin/pip install -e $CKAN_HOME/src/ckan/
RUN ln -s $CKAN_HOME/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini
ADD ./contrib/docker/apache.wsgi $CKAN_CONFIG/apache.wsgi

# Configure apache
ADD ./contrib/docker/apache.conf /etc/apache2/sites-available/ckan_default.conf
RUN echo "Listen 8080" > /etc/apache2/ports.conf
RUN a2ensite ckan_default
RUN a2dissite 000-default

# Configure nginx
ADD ./contrib/docker/nginx.conf /etc/nginx/nginx.conf
RUN mkdir /var/cache/nginx

# Configure postfix
ADD ./contrib/docker/main.cf /etc/postfix/main.cf


#custom
ADD ./contrib/docker/htpasswd $CKAN_CONFIG/htpasswd
RUN chown www-data:www-data $CKAN_CONFIG/htpasswd
ADD ./contrib/docker/ckan.ini $CKAN_CONFIG/ckan.ini

RUN \
    mkdir -p /var/log/ckan && \
    touch /var/log/ckan/ckan_ext.log&& \
    chmod -R 777 /var/log/ckan
#custom plugins 
ADD contrib/docker/ckanext-pages $CKAN_HOME/src/ckanext-pages
RUN $CKAN_HOME/bin/pip install $CKAN_HOME/src/ckanext-pages
RUN cd $CKAN_HOME/src/ckanext-pages && python setup.py develop


ADD contrib/docker/ckanext-sparql $CKAN_HOME/src/ckanext-sparql
RUN $CKAN_HOME/bin/pip install $CKAN_HOME/src/ckanext-sparql
RUN cd $CKAN_HOME/src/ckanext-sparql && python setup.py develop

#ADD contrib/docker/ckanext-spatial $CKAN_HOME/src/ckanext-spatial
#RUN $CKAN_HOME/bin/pip install $CKAN_HOME/src/ckanext-spatial

# Configure runit
ADD ./contrib/docker/my_init.d /etc/my_init.d
ADD ./contrib/docker/svc /etc/service
CMD ["/sbin/my_init"]

VOLUME ["/var/lib/ckan"]
EXPOSE 80

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
