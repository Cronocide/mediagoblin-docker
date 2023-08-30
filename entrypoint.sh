#!/bin/bash
# Mediagoblin launcher
# v1.0 August 2023 by Cronocide

__set_defaults() {
	export BROKER_URL="$RABBIT_AMQP_URL"
	[ -z "$BIND_PORT" ] && export BIND_PORT=6543
	[ -z "$BROKER_URL" ] && export BROKER_URL="amqp://guest:**@localhost:5672/"
	[ -z "$MEDIAGOBLIN_CONFIG" ] && export MEDIAGOBLIN_CONFIG="/data/mediagoblin.ini"
}

# Verify environment variables
__verify_env() {
	# Install template if neccessary
	[ -e /data/mediagoblin.ini ] || echo "[WARN] : Missing /data/mediagoblin.ini, copying template for use." && cp /srv/mediagoblin/mediagoblin/mediagoblin.ini /data/mediagoblin.ini
	[ -e /data/mediagoblin.db ] || echo "[INFO] : Missing /data/mediagoblin.db. Creating it just in case we're not going to use postgres." && touch /srv/mediagoblin/mediagoblin/mediagoblin.db
	# Check for required vars
	REQUIRED_ENV_VARS="BIND_PORT ADMIN_USERNAME ADMIN_EMAIL ADMIN_PASSWORD MEDIAGOBLIN_CONFIG"
	for REQUIRED_VAR in $(echo "$REQUIRED_ENV_VARS"); do
		[ -z "${!REQUIRED_VAR}" ] && echo "Missing required ENV variable $REQUIRED_VAR, aborting." && exit 1
	done
}

# Verify and update database
__update_db() {
	echo "Running \`gmg dbupdate\`"
	/srv/mediagoblin/mediagoblin/bin/gmg dbupdate
}

# Create admin user
__create_user() {
	/srv/mediagoblin/mediagoblin/bin/gmg adduser --username "$ADMIN_USERNAME" --email "$ADMIN_EMAIL" --password "$ADMIN_PASSWORD"
	/srv/mediagoblin/mediagoblin/bin/gmg makeadmin "$ADMIN_USERNAME"
}

# Fix the dumb baked bind
__fix_bind() {
	sed -i "s#host = 127.0.0.1#host = 0.0.0.0#" /srv/mediagoblin/mediagoblin/paste.ini
	sed -i "s#port = 6543#port = $BIND_PORT#" /srv/mediagoblin/mediagoblin/paste.ini
}

# Main run loop
__run_main() {
	__fix_bind
	__update_db
	__create_user
	# Run rabbitmq
	sudo -u rabbitmq rabbitmq-server & disown
	# Run MediaGoblin
	/srv/mediagoblin/mediagoblin/bin/paster serve paste.ini --reload &
	# Run Celery
	export CELERY_ALWAYS_EAGER=true
	export CELERY_CONFIG_MODULE=mediagoblin.init.celery.from_celery
#	export MEDIAGOBLIN_CONFIG="$MEDIAGOBLIN_INI_PATH"
	/srv/mediagoblin/mediagoblin/bin/celery worker -B &
	sleep infinity
}

# Main functions
__set_defaults && __verify_env
__run_main
