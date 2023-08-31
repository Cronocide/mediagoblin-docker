#!/bin/bash
# Mediagoblin launcher
# v1.0 August 2023 by Cronocide

__set_defaults() {
	[ -z "$BIND_PORT" ] && export BIND_PORT=6543
	[ -z "$MEDIAGOBLIN_CONFIG" ] && export MEDIAGOBLIN_CONFIG="/data/mediagoblin.ini"
}

# Verify environment variables
__verify_env() {
	# Install template if neccessary
	[ -e /data/mediagoblin.ini ] || (echo "[WARN] : Missing /data/mediagoblin.ini, copying template for use." && cp /srv/mediagoblin/mediagoblin/mediagoblin.ini /data/mediagoblin.ini)
	[ -e /data/mediagoblin.db ] || (echo "[INFO] : Missing /data/mediagoblin.db. Creating it just in case we're not going to use postgres." && touch /data/mediagoblin.db)
	# Check for required vars
	REQUIRED_ENV_VARS="BIND_PORT ADMIN_USERNAME ADMIN_EMAIL ADMIN_PASSWORD MEDIAGOBLIN_CONFIG"
	for REQUIRED_VAR in $(echo "$REQUIRED_ENV_VARS"); do
		[ -z "${!REQUIRED_VAR}" ] && echo "Missing required ENV variable $REQUIRED_VAR, aborting." && exit 1
	done
}

# Verify and update database
__update_db() {
	echo "Running \`gmg dbupdate\`"
	/srv/mediagoblin/mediagoblin/bin/gmg --conf_file "$MEDIAGOBLIN_CONFIG" dbupdate
}

# Create admin user
__create_user() {
	/srv/mediagoblin/mediagoblin/bin/gmg --conf_file "$MEDIAGOBLIN_CONFIG" adduser --username "$ADMIN_USERNAME" --email "$ADMIN_EMAIL" --password "$ADMIN_PASSWORD"
	/srv/mediagoblin/mediagoblin/bin/gmg --conf_file "$MEDIAGOBLIN_CONFIG" makeadmin "$ADMIN_USERNAME"
}

# Fix the dumb baked stuff
__fix_paste() {
	# Fix binding
	sed -i "s#host = 127.0.0.1#host = 0.0.0.0#" /srv/mediagoblin/mediagoblin/paste.ini
	sed -i "s#port = 6543#port = $BIND_PORT#" /srv/mediagoblin/mediagoblin/paste.ini
	# Hard set the config to the path the user specified
	sed -i "s@config = %(here)s/mediagoblin_local.ini %(here)s/mediagoblin.ini@config = $MEDIAGOBLIN_CONFIG@" /srv/mediagoblin/mediagoblin/paste.ini
	# Change media relative paths to `/data`
	sed -i "s#%(here)s#/data#" /srv/mediagoblin/mediagoblin/paste.ini
	sed -i "s#/user_dev##" /srv/mediagoblin/mediagoblin/paste.ini
}

# Main run loop
__run_main() {
	echo "Using config at path $MEDIAGOBLIN_CONFIG"
	echo "Database URL:"
	grep sql_engine "$MEDIAGOBLIN_CONFIG" | grep -v "#"
	__fix_paste
	__update_db
	__create_user
	# Run rabbitmq
	sudo -u rabbitmq rabbitmq-server & disown
	# Run MediaGoblin
	/srv/mediagoblin/mediagoblin/bin/paster serve paste.ini --reload &
	# Run Celery
	export CELERY_ALWAYS_EAGER=true
	export CELERY_CONFIG_MODULE=mediagoblin.init.celery.from_celery
	/srv/mediagoblin/mediagoblin/bin/celery worker -B &
	while true; do
		sleep 10
		[[ $(ps aux | grep rabbitmq-server | grep -v grep) == "" ]] && echo "Restarting rabbitmq-server..." && sudo -u rabbitmq rabbitmq-server & disown
		[[ $(ps aux | grep "celery worker -B" | grep -v grep) == "" ]] && echo "Restarting celery worker..." && /srv/mediagoblin/mediagoblin/bin/celery worker -B &
		[[ $(ps aux | grep "paster serve" | grep -v grep) == "" ]] && echo "Restarting paster..." && /srv/mediagoblin/mediagoblin/bin/paster serve paste.ini --reload &
	done
	sleep infinity
}

# Main functions
__set_defaults && __verify_env
__run_main
