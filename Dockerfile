FROM ruby:3.3.4-alpine

# Linux UID (user id) for the doorkeeper user, change with [--build-arg UID=1234]
ARG UID="991"
# Linux GID (group id) for the doorkeeper user, change with [--build-arg GID=1234]
ARG GID="991"
# Timezone used by the Docker container and runtime, change with [--build-arg TZ=Europe/Berlin]
ARG TZ="Etc/UTC"

# Apply timezone
ENV TZ=${TZ}

RUN addgroup -g "${GID}" doorkeeper; \
  adduser -u "${UID}" -G "doorkeeper" -h /srv doorkeeper; \
  echo "${TZ}" > /etc/localtime;

RUN apk add --no-cache \
  ca-certificates \
  wget \
  openssl \ 
  bash \
  build-base \
  git \
  sqlite-dev \
  tzdata

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /srv

COPY . /srv/

RUN chown -R doorkeeper:doorkeeper /srv

# Set the running user for resulting container
USER doorkeeper

RUN mkdir -p /srv/.local/gem/share
ENV GEM_HOME=/srv/.local/gem/share

ENV BUNDLER_VERSION=2.5.11
RUN gem install bundler -v ${BUNDLER_VERSION}

# This is a fix for sqlite alpine issues
RUN bundle config force_ruby_platform true
RUN bundle install

CMD ["bundle", "exec", "rake"]
