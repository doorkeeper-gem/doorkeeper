FROM ruby:3.3.4-alpine

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

ENV BUNDLER_VERSION=2.5.11
RUN gem install bundler -v ${BUNDLER_VERSION} -i /usr/local/lib/ruby/gems/$(ls /usr/local/lib/ruby/gems) --force

WORKDIR /srv

COPY Gemfile doorkeeper.gemspec /srv/
COPY lib/doorkeeper/version.rb /srv/lib/doorkeeper/version.rb

RUN bundle install

COPY . /srv/

CMD ["rake"]
