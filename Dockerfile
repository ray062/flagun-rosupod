# Use the official Python image as the base image
FROM python:3.11.9-slim-bookworm

# Set environment variables to ensure non-interactive installations
ENV DEBIAN_FRONTEND=noninteractive

# Set the working directory in the container
WORKDIR /config

# Install dependencies
RUN apt-get update && \
    apt-get install -y nginx logrotate cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY ./config/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create a non-root user
# RUN useradd -m flaskuser

# Set up cron job for logrotate
COPY ./config/cron_fgn /etc/cron.d/cron_fgn
RUN chmod 0644 /etc/cron.d/cron_fgn
RUN crontab /etc/cron.d/cron_fgn
RUN mkdir -p /var/log/gunicorn
RUN mkdir -p /var/log/nginx

# Gunicorn setting and startup
# Copy Gunicorn config file
COPY ./config/gunicorn.conf.py .
# Expose the port for the Nginx server
EXPOSE 8088 8443
# CD to /flask_app to be ready for WSGI server execution.
WORKDIR /flask_app

# Ensure the log directory exists
RUN mkdir -p /var/log/nginx

# Copy setup script
COPY ./entrypoint/setup_fgn.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

# Executed at podman run, start
ENTRYPOINT [ "/usr/local/bin/setup.sh" ]

