# Listen to all IP
bind = "0.0.0.0:8000"

# This number should generally be between 2-4 workers per core in the server
# import multiprocessing
# workers = multiprocessing.cpu_count() * 2 + 1
# But in a docker container, often only one core is allocated. 
# So set it to 3 in case of one core docker image
workers = 3

# Logging configuration
# To disable a log, set it to '-' (include "'")
accesslog = '/var/log/gunicorn/access.log'
errorlog = '/var/log/gunicorn/error.log'
loglevel = 'info'
