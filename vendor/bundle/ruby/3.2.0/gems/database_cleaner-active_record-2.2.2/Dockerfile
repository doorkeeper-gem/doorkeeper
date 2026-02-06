ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
# This is copied so we can bundle the application, but it's replaced
# by a mounted volume with the current code when executed with docker compose
COPY . /app

ARG BUNDLE_GEMFILE=Gemfile
ENV BUNDLE_GEMFILE=${BUNDLE_GEMFILE}

# Install any needed packages specified in Gemfile
RUN ./bin/setup

# Command to run the application
CMD ["bash"]