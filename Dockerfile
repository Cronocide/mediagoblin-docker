FROM python:3.9-bullseye as PYTHON
# FROM debian
ENV PROJ_NAME=mediagoblin-docker
ARG DEBIAN_FRONTEND=noninteractive
# RUN apt search python3 && exit 1
# Install dependencies
RUN apt update && apt install -y \
	sudo \
	automake \
	git \
	nodejs \
	npm \
	python3-gst-1.0 \
	python3-psycopg2 \
	python3-lxml \
	python3-pil \
	python3-gi \
	gstreamer1.0-tools \
	gir1.2-gstreamer-1.0 \
	gir1.2-gst-plugins-base-1.0 \
	gstreamer1.0-plugins-base \
	gstreamer1.0-plugins-bad \
	gstreamer1.0-plugins-good \
	gstreamer1.0-plugins-ugly \
	gstreamer1.0-libav python3-gst-1.0 \
	virtualenv \
	rabbitmq-server
# Setup user
ARG USER_UID=999
ARG USER_NAME=mediagoblin
ARG BUILD_BRANCH=stable
RUN useradd \
	--system \
	-u $USER_UID \
	--create-home \
	--home-dir \
	/var/lib/mediagoblin \
	--group www-data \
	--comment 'GNU MediaGoblin system account' \
	$USER_NAME
RUN usermod --append --groups $USER_NAME $USER_NAME
RUN mkdir --parents /srv/mediagoblin
RUN chown --no-dereference --recursive $USER_NAME:www-data /srv/mediagoblin
# Configure sudo permissions for the running user to launch rabbitmq
RUN echo "$USER_NAME ALL=(rabbitmq:rabbitmq) NOPASSWD:ALL" >> /etc/sudoers
USER $USER_NAME
RUN git clone --depth=1 https://git.savannah.gnu.org/git/mediagoblin.git \
	--branch $BUILD_BRANCH \
	--recursive \
	/srv/mediagoblin/mediagoblin
WORKDIR /srv/mediagoblin/mediagoblin
RUN ./bootstrap.sh
RUN ./configure
# Resolve setuptools AttributeError for SQLAlchemy install
ENV SETUPTOOLS_USE_DISTUTILS=stdlib
RUN make

# Install sqlalchemy-migrate for future db updates
RUN /srv/mediagoblin/mediagoblin/bin/pip3 install sqlalchemy-migrate

# Link /data directory
USER root
RUN mkdir /data
RUN ln -s /srv/mediagoblin/mediagoblin/user_dev/ /data/
USER $USER_NAME

# Prepare DB
RUN /srv/mediagoblin/mediagoblin/bin/gmg dbupdate

# Copy project files
ADD ./entrypoint.sh /entrypoint.sh

# Run entrypoint
ENTRYPOINT ["/entrypoint.sh"]

