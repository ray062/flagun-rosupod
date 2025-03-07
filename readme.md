# Intro #
This project is to build a Podman images to run **Flask-Gunicorn-Nginx** web server.<br>
Then make the service auto-start and ran by a rootless, system user. This architecture is for **robustess** and strong **security** for a **production** server. <br>
1 - You don't need to rebuild the image when you change the web app's code. Because the web application code is set as a attached volume under the folder flask_app.<br>
2 - This image enables a self-signed certificate for HTTPS which is also configured in a external volume.<br>
3 - This image takes care about logs rotation.<br>
4 - You can configure the path of code, config, certificates at the moment of creating the image and a container instance by using build-image.sh<p>

# Quick start #
## (re)build and start the image ##
```sh
cd certificates
./create_certificates.sh
cd ..
mkdir -p logs/nginx logs/gunicorn
cp examples/build-image.sh ./build-image.sh
chmod +x build-image.sh
./build-image.sh
podman start fgn-docker-example
```
It will create and run the container with default values.<br>
By default, the certificates, logs and configs are in this project's directory.And it's fine for a testing usage.<br>
For a production usage, please change configure (in build-image.sh) to put these path outside of this project's directory.

## Test ##
https://localhost:8443

# Run as rootless user in an auto start systemd service #
Inspired by : https://blog.christophersmart.com/2021/02/20/rootless-podman-containers-under-system-accounts-managed-and-enabled-at-boot-with-systemd/ <p>
Tested with 
- Podman 4.9.3
- Ubuntu 24.04 (6.8.0-38-generic)
- Flask 
- Gunicorn
- Nginx

## Prepare installation files ##
It's recommand to have configs, logs, certificates and flask app code outside of the project folder. Then, update build-image.sh with the new values.<br>
This is an example:
```sh
export REPO_PATH="/path/to/flagun-rosupod/"
export INSTALL_PATH="/path/to/mywebservice/"
export LOG_PATH="/var/log/mywebservice/"

mkdir $INSTALL_PATH
cp -r ${REPO_PATH} ${INSTALL_PATH}
cp -r "${INSTALL_PATH}flagun-rosupod/flask_app" "${INSTALL_PATH}flask_app"
cp -r "${INSTALL_PATH}flagun-rosupod/config" "${INSTALL_PATH}config"
cp -r "${INSTALL_PATH}flagun-rosupod/certificates" "${INSTALL_PATH}certificates"
mkdir -p "${LOG_PATH}nginx" "${LOG_PATH}gunicorn"
cp "${INSTALL_PATH}flagun-rosupod/examples/build-image.sh" "${INSTALL_PATH}flagun-rosupod/"
chmod +x "${INSTALL_PATH}flagun-rosupod/build-image.sh"

# Change env var values in the build-image.sh
nano "${INSTALL_PATH}flagun-rosupod/build-image.sh"

# Generate certificates. For testing purpose, you can leave default for every prompt.
cd "${INSTALL_PATH}/certificates"
chmod +x create_certificate.sh
./create_certificate.sh
```
**Attention**: `${INSTALL_PATH}flask_app` is the path to your web application code. Do change it to your Flask application path.

## Create and configure a system user ##
The system user should:
- have a home directory
- have no shell
- have an open session when the server starts (enable-linger).
- have its subuid and subgid (usermod).<p>

You need to have sudo access.
```sh
export SYSUSER="mysysuser"

sudo useradd -r -m -d /opt/${SYSUSER} -s /usr/sbin/nologin ${SYSUSER}

sudo loginctl enable-linger ${SYSUSER}

sudo chown -R ${SYSUSER}:${SYSUSER} ${INSTALL_PATH}
sudo chown -R ${SYSUSER}:${SYSUSER} ${LOG_PATH}

NEW_SUBUID=$(($(tail -1 /etc/subuid | awk -F ":" '{print $2}')+65536))
NEW_SUBGID=$(($(tail -1 /etc/subgid | awk -F ":" '{print $2}')+65536))
sudo usermod --add-subuids ${NEW_SUBUID}-$((${NEW_SUBUID}+65535)) "${SYSUSER}"
sudo usermod --add-subgids ${NEW_SUBGID}-$((${NEW_SUBGID}+65535)) "${SYSUSER}"
```
## Build the image and create a container in the system user ##
- At first, switch to the system user at first (sudo bash).
- Set manually the env var XDG_RUNTIME_DIR as we switched to the user. (instead of logging in with ssh, but it's not possible as the user does not have shell)
- run build-image.sh to build an image and a container instance.
```sh
sudo -H -u "${SYSUSER}" bash -c 'cd; bash'

# Below should be ran under SYSUSER's session
export XDG_RUNTIME_DIR=/run/user/"$(id -u)"

# cd to the installaton folder containing the configured build-image.sh
export CONTAINER_NAME="fgn-docker-mywebservice"
export INSTALL_PATH="/path/to/mywebservice/"
cd ${INSTALL_PATH}/flagun-rosupod
./build-image.sh

# Test the container
podman start "${CONTAINER_NAME}"

# Do some tests

# Stop the container after tests
podman stop "${CONTAINER_NAME}"
```
Keep this session. It will be used in the next step.<br>
**Attention** : You may need to re-execute this step each time there is a new version of the image. Other steps are not necessary to be re-executed.

## Setup user service in systemd ##
You need to create a user systemd folder and generate the service configuration file.
```sh
export SERVICE_NAME="mywebservice"
export SERVICE_CONFIG_FOLDER="${HOME}/.config/systemd/user/"
export SERVICE_CONFIG_PATH="${SERVICE_CONFIG_FOLDER}${SERVICE_NAME}.service"

mkdir -p "${SERVICE_CONFIG_FOLDER}"
podman generate systemd --restart-policy no --name "${CONTAINER_NAME}" > "${SERVICE_CONFIG_PATH}"
sed -i s/^KillMode=.*/KillMode=control-group/ "${SERVICE_CONFIG_PATH}"

podman stop ${CONTAINER_NAME}
systemctl --user daemon-reload
systemctl --user enable --now "${SERVICE_NAME}"
systemctl --user status "${SERVICE_NAME}"
```
You should be able to connect to the web service.
The default URL is https://localhost:8443
But you may have set anohter port number in build-image.sh
You can restart the server. The service should be started after the reboot.

## Monitoring ##
As it's not possible to ssh to log in the system user, we need to use machinectl to run command as of the system user.<br>
Example :
```sh
machinectl shell ${SYSUSER} /bin/bash -c "podman ps -a"
machinectl shell ${SYSUSER} /bin/bash -c "systemctl --user ${SERVICE_NAME}"
``` 

# Uninstall #
Just in case if you want to remove the system user and its ressources.
## Stop & disable systemd user services ##
In the user's session:
```sh
# From an admin session switch to the user
export SYSUSER="mysysuser"
sudo -H -u "${SYSUSER}" bash -c 'cd; bash'

export SYSUSER="mysysuser"
export SERVICE_NAME="mywebservice"
export CONTAINER_NAME="fgn-docker-mywebservice"
export XDG_RUNTIME_DIR=/run/user/"$(id -u)"

systemctl --user stop ${SERVICE_NAME}.service
systemctl --user disable ${SERVICE_NAME}.service
rm ~/.config/systemd/user/${SERVICE_NAME}.service

# Remove the container, the image
podman rm -if ${CONTAINER_NAME}
podman rmi -f "fgn-docker"

# Exit back to the admin session
exit
```

## Delete the user ##
In admin's session:
```sh
export SYSUSER="mysysuser"
sudo pkill -u $SYSUSER
sudo userdel -r $SYSUSER

# Search if any file belongs to $SYSUSER
find / -user $SYSUSER

# Make sure there is no line for the $SYSUSER
sudo nano /etc/subuid 
sudo nano /etc/subgid
```

# On changes #
- Flask app code : restart the service.
- Certificates : restart the service
- Configs : rerun build-image.sh & restart the service
- Dockerfile : rerun build-image.sh & restart the service
- build-image.sh : rerun build-image.sh & restart the service

# On new releases #
When there is a new release, you normally only need to rebuild the image. It's possible that some modifications would need to be done on config (check release note). There should be no reason to have changes on certificates and logs. A new release will never make changes on (your) flask_app because it's your web application code.



# Folders #
## config ##
These config are used by the container inside of its runtime.<br>
So they are not impacted by the host's settings (The server on which run the container).<br>
  - `gunicorn.conf.py` setup to 
    - listen from all IP on port 8000
    - create 3 workers as it's to run a simple web site on one core
    - logs' path (in the container) and log level
  - `nginx.conf` sets to .
    - redirect 8088 to 8443
    - when it's 8443, use ssl set in certificate path
    - logs' path (in the container)
    - proxy_pass : pass the inbound request to localhost:8000
    - Other params : I don't know yet...
  - `requirements.txt` : python modules for flask-Gunicorn-wsgi-server image
  - cron_fgn : cron scheduled jobs for log rotating. It's used by the command crontab in setup_fgn.sh which is an entry point and which is executed when the container starts.


## flask_app ##
 is a sample "Hello world" web site. When you put your code, pay attention to keep the name of "flask-app" and the "main.py" file name. They will be used after in the gunicorn command in Dockerfile. *main* is the module name, *flask_app* is the variable name of the flask instance.<p>

## entrypoint ##
 Scripts to setup dynamically the containers when the container starts.
 - setup_fgn : it creates logrotate config files for each image

## certificates ## 
It contains a shell script to generate self signed certificates. When run this command, set CN to "localhost" when it's asked.<br>
To change the certificates, just execute the script or copy your certificates here and then restart the docker image.<br>
It's recommanded to copy the generated cert files into another folder and update in build-image.sh the certificates path.

## root ##
- Dockerfile : the docker file to build the image containing Flask, Gunicorn and Nginx. And also cron andd logrotate for logrotation.
- docker-compose.yml : starts flask-Gunicorn-wsgi-server and Nginx server to build the infra

## examples ##
They are example files that are useful to build the image, to configure a service etc. You need to open them and setup them regarding to your context.
- build-image.sh : script to build the image and registrer a container with Podman
- cleanup.sh : script to cleanup data (logs) to facilitate tests.
- systemd.service : an example of systemd service file.


# Howto #
## Possible modifications ##
- In `Dockerfile`, it's possible to modify the name of the module (in gunicorn command)
- In `gunicorn.conf.py` : worker number and IP listening
- In `requirements.txt` : python modules and versions
- In `nginx.config` : port redirect and proxy setting.

# Reminder #
Don't over optimize it. When it's good enough, extra optimization would cost a lot of effort for little improvements. If in dealm with options which no one is clearly the best, then probably it's not worth. 

# TODO #
## Reduce in-container config files ##
So that in case of change of config, it's not necessary to rebuild the image. Actual ones to be moved out are :
- logrotate config
