#!/usr/bin/bash
# Author : QLI @ 2024.07
# Please change followning variables' values regarding to your context.
# Copy this file to the folder containing Dockerfile and execute from there 

if [ ! -f "Dockerfile" ]; then
  echo "You must cd to the folder containning the Dockerfile"
  echo "Exit as Dockerfile is not found in the current folder"
  exit 1
fi
export CONTAINER_NAME="fgn-docker-example"
export HTTPS_PORT=8443
export HTTP_PORT=8088
export FLASK_APP_PATH="./flask_app"
export CONFIG_PATH="./config"
export NGINX_CONFIG="./config/nginx.conf"
export NGINX_LOG_PATH="./logs/nginx"
export GUNICORN_LOG_PATH="./logs/gunicorn"
export SSL_CERT_PATH="./certificates"

# used in setup_fgn.sh
export APP_USER=$USER
export APP_GROUP=$USER 
export GUINCORN_LOGROTATE_DAYS=30
export NGINX_LOGROTATE_DAYS=30

echo "Remove the container..."
podman rm -if ${CONTAINER_NAME}

echo "Build the image"
podman build -t "fgn-docker" .

echo "Create a container to registrer its name"
podman create \
    --name ${CONTAINER_NAME} \
    -e APP_USER=${APP_USER} \
    -e APP_GROUP=${APP_GROUP} \
    -e GUINCORN_LOGROTATE_DAYS=${GUINCORN_LOGROTATE_DAYS} \
    -e NGINX_LOGROTATE_DAYS=${NGINX_LOGROTATE_DAYS} \
    -p $HTTPS_PORT:8443 \
    -p $HTTP_PORT:8088 \
    -v $FLASK_APP_PATH:/flask_app:Z \
    -v $CONFIG_PATH:/config:Z \
    -v $NGINX_CONFIG:/etc/nginx/conf.d/default.conf:Z \
    -v $NGINX_LOG_PATH:/var/log/nginx:Z \
    -v $GUNICORN_LOG_PATH:/var/log/gunicorn:Z \
    -v $SSL_CERT_PATH:/etc/nginx/ssl:Z \
    fgn-docker

echo "Backup this script..."
mkdir -p "../install_logs/"
cp build-image.sh "../install_logs/build-image.sh.$(date +%Y%m%d_%H%M%S).bak"
echo "Backup env..."
env > "../install_logs/build-image.sh.$(date +%Y%m%d_%H%M%S).env"

echo "From now you can run the container with the command:"
echo "podman start ${CONTAINER_NAME}"
echo "To test it, run:"
echo "curl --insecure https://localhost:${HTTPS_PORT}"
echo "curl http://localhost:${HTTP_PORT}"
echo "To stop the container, run: podman stop ${CONTAINER_NAME}"
echo "To remove the container, run: podman rm -if ${CONTAINER_NAME}"
podman ps -a | grep ${CONTAINER_NAME}

exit 0
