FROM debian
ENV PROJ_NAME=mediagoblin-docker

# Copy project files
ADD ./entrypoint.sh /entrypoint.sh

# Run entrypoint
ENTRYPOINT ["/entrypoint.sh"]
