FROM debian:jessie

MAINTAINER  Daniel Sendzik <d.sendzik@gmail.com>

ENV DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true

RUN     apt-get clean && apt-get update && apt-get install -y \
	        git \
          apache2 \
          curl \
          libapache2-mod-php5 \
          libmysqlclient18 \
          mercurial \
          mysql-client \
          php-apc \
          php5 \
          php5-apcu \
          php5-cli \
          php5-curl \
          php5-gd \
          php5-json \
          php5-ldap \
          php5-mysql \
          python-pygments \
          sendmail \
          tar \
          sudo \
          openssh-server \
          netcat-openbsd \
        && apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup ssh server
ADD    sshd_config /etc/ssh/sshd_config.phabricator
VOLUME /opt/ssh-keys
ADD 	 phabricator-ssh-hook.sh /opt/phabricator-ssh-hook.sh
RUN    chmod 755 /opt/phabricator-ssh-hook.sh
RUN    useradd -M -d / -s /bin/bash git
RUN    sed -e 's/git:!:/git:NP:/' -i /etc/shadow

# For some reason phabricator doesn't have tagged releases. To support
# repeatable builds use the latest SHA
ADD     download.sh /opt/download.sh

ARG PHABRICATOR_COMMIT=ca30df847e4e99aec46dd97c7bd9b4f7d8542cab
ARG ARCANIST_COMMIT=10e5194752901959507223c01e0878e6b8312cc5
ARG LIBPHUTIL_COMMIT=f748cdbc8d08175375f4c4c87fc679de3145c620

WORKDIR /opt
RUN     bash download.sh phabricator $PHABRICATOR_COMMIT
RUN     bash download.sh arcanist    $ARCANIST_COMMIT
RUN     bash download.sh libphutil   $LIBPHUTIL_COMMIT

# Setup apache
RUN     a2enmod rewrite
ADD     phabricator.conf /etc/apache2/sites-available/phabricator.conf
RUN     ln -s /etc/apache2/sites-available/phabricator.conf \
            /etc/apache2/sites-enabled/phabricator.conf && \
        rm -f /etc/apache2/sites-enabled/000-default.conf

# Setup phabricator
VOLUME  /var/repo
RUN     mkdir -p /opt/phabricator/conf/local
ADD     local.json /opt/phabricator/conf/local/local.json
RUN     sed -e 's/post_max_size =.*/post_max_size = 32M/' \
          -e 's/upload_max_filesize =.*/upload_max_filesize = 32M/' \
          -e 's/;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/' \
          -e 's/;*date.timezone =.*/date.timezone = Europe\/Berlin/' \
          -e 's/;*always_populate_raw_post_data =.*/always_populate_raw_post_data = -1/' \
          -i /etc/php5/apache2/php.ini
#RUN     /opt/phabricator/bin/config set phd.user "root"
#RUN     /opt/phabricator/bin/config set diffusion.ssh-user "git"
RUN     echo "git ALL=(root) SETENV: NOPASSWD: /usr/bin/git-receive-pack, /usr/bin/git-upload-pack /usr/bin/git" >> /etc/sudoers

EXPOSE  80
EXPOSE  22
ADD     entrypoint.sh /entrypoint.sh
CMD     /entrypoint.sh
