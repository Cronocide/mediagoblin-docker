#!/bin/bash
# Mediagoblin launcher
# v1.0 August 2023 by Cronocide

# Global constants
PORT_REGEX='^[0-9]{1,5}$'

__set_defaults() {
	export BROKER_URL="$RABBIT_AMQP_URL"
	[ -z "$BIND_PORT" ] && export BIND_PORT=8080
#	[ -z "$POSTGRES_DB" ] && export POSTGRES_DB=mediagoblin
#	[ -z "$POSTGRES_USER" ] && export POSTGRES_USER=mediagoblin
#	[ -z "$POSTGRES_HOST" ] && export POSTGRES_HOST=127.0.0.1
#	[ -z "$POSTGRES_PORT" ] && export POSTGRES_HOST=5432
	[ -z "$BROKER_URL" ] && export BROKER_URL="amqp://guest:**@localhost:5672/"
	# Configured defaults from deploy guide
	export CELERY_CONFIG_MODULE=mediagoblin.init.celery.from_celery
}

# Verify environment variables
__verify_env() {
	# Check for required files
	! [ -e /srv/mediagoblin/mediagoblin/mediagoblin.ini ] && echo "Missing mediagoblin.ini, aborting." && exit 1
	# Check for required vars
	REQUIRED_ENV_VARS="BIND_PORT SERVER_NAME ADMIN_USERNAME ADMIN_EMAIL ADMIN_PASSWORD"
	for REQUIRED_VAR in $(echo "$REQUIRED_ENV_VARS"); do
		[ -z "${!REQUIRED_VAR}" ] && echo "Missing required ENV variable $REQUIRED_VAR, aborting." && exit 1
	done
	# Check for rational ports
#	PORT_VARS="POSTGRES_PORT"
#	for PORT_VAR in $(echo "$PORT_VARS"); do
#	[[ $(echo "${!PORT_VAR}" | egrep "$PORT_REGEX") == "" ]] && \
#		echo "Unable to parse encryption port ${!PORT_VAR}, should be 1-65535" && exit 1
#	done
	# Populate Nginx config
	for TEMPLATE_VAR in $(echo "BIND_PORT SERVER_NAME PROXY_PREFIX"); do
			sed -i "s%\$$TEMPLATE_VAR%${!TEMPLATE_VAR}%" /etc/nginx/conf.d/nginx.conf
	done
}

__verify_services() {
	curl "$BROKER_URL" || echo "Unable to contact rabbitmq server at $BROKER_URL" && return 1
}

# Create admin user
__create_user() {
	/srv/mediagoblin/mediagoblin/bin/gmg adduser --username "$ADMIN_USERNAME" --email "$ADMIN_EMAIL"
}

# Main run loop
__run_main() {
	# Link user (media) directories
	ln /srv/mediagoblin/mediagoblin/user_dev/ /data/
	# Verify required services are running
	__verify_services && echo "Missing required services, aborting." && exit 1
	# Run rabbitmq
	sudo -u rabbitmq rabbitmq-server &
	# Run nginx
	nginx &
	# Run MediaGoblin
	/srv/mediagoblin/mediagoblin/lazyserver.sh &
	# Run Celery
	/srv/mediagoblin/mediagoblin/lazycelery.sh &
	# Create user
	sleep 3
	__create_user
}

# Optional variables
# POSTGRES_HOST
# POSTGRES_PORT
# RABBITMQ_HOST
# RABBITMQ_PORT
# RABBITMQ_USER
# RABBITMQ_PASS

# Main functions

__set_defaults && __verify_env
__run_main
