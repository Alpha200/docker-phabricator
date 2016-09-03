#!/bin/sh

if [ ! -d /var/run/sshd ]; then
   mkdir /var/run/sshd
   chmod 0755 /var/run/sshd
fi

until netcat -z -w 2 database 3306; do sleep 1; done

exec bash -c "/opt/phabricator/bin/storage upgrade --force; /opt/phabricator/bin/phd start; source /etc/apache2/envvars; /usr/sbin/sshd -f /etc/ssh/sshd_config.phabricator; /usr/sbin/apache2 -DFOREGROUND"

