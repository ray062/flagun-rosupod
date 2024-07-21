#!/bin/bash

# Define the logrotate configuration
GUNICORN_LR_FILE="/etc/logrotate.d/gunicorn_rotate_logs"
NGINX_LR_FILE="/etc/logrotate.d/nginx_rotate_logs"

# Create logrotate configuration file with variable substitution
cat <<EOF > $GUNICORN_LR_FILE
/var/log/gunicorn/*.log {
    daily
    missingok
    rotate ${GUINCORN_LOGROTATE_DAYS}
    compress
    delaycompress
    notifempty
    create 0640 ${APP_USER} ${APP_GROUP}
    sharedscripts
    postrotate
        [ -f /var/run/gunicorn.pid ] && kill -HUP \$(cat /var/run/gunicorn.pid)
    endscript
}
EOF

# Create logrotate configuration file with variable substitution
cat <<EOF > $NGINX_LR_FILE
/var/log/nginx/*.log {
    daily
    missingok
    rotate ${NGINX_LOGROTATE_DAYS}
    compress
    delaycompress
    notifempty
    create 0640 ${APP_USER} ${APP_GROUP}
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 \$(cat /var/run/nginx.pid)
    endscript
}
EOF

# Print environment variables
env

# Start cron in foreground
cron -f &



# Print gunicorn version
gunicorn --version

# Print nginx version
nginx -v

# Print Flask version
flask --version 

# Start gunicorn
gunicorn -c /config/gunicorn.conf.py main:flask_app &

# Start nginx
nginx -g "daemon off;"

# exec "$@"
