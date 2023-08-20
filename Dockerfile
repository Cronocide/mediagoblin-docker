FROM debian
ENV PROJ_NAME=mediagoblin-docker
ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && apt install -y \
	automake \
	git \
	nodejs \
	npm \
	python3-dev \
	python3-gst-1.0 \
	python3-psycopg2 \
	python3-lxml \
	python3-pil \
	python3-setuptools \
	virtualenv \
	nginx \
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
RUN chown --recursive $USER_NAME:www-data /etc/nginx
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

# Copy project files
ADD ./entrypoint.sh /entrypoint.sh
ADD ./nginx.conf /etc/nginx/conf.d/

# Run entrypoint
ENTRYPOINT ["/entrypoint.sh"]

