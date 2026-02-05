# Guidelines for contributing

## 1. Fork & Clone

Since you probably don't have rights to the main repo, you should Fork it (big
button up top). After that, clone your fork locally and optionally add an
upstream:

    git remote add upstream git@github.com:DatabaseCleaner/database_cleaner-active_record.git

## 2. Make sure the tests run fine

The gem uses Appraisal to configure different Gemfiles to test different Rails versions.

### Run tests without Docker (or using Docker only for the databases)

- You can run all the databases through docker if needed with `docker compose -f docker-compose.db.yml up` (you can also have them running on your system, just comment out the ones you don't need from the `docker-compose.db.yml` file)
- Copy `spec/support/sample.config.yml` to `spec/support/config.yml` and edit it as needed
- `BUNDLE_GEMFILE=gemfiles/rails_6.1.gemfile bundle install` (change `6.1` with any version from the `gemfiles` directory)
- `BUNDLE_GEMFILE=gemfiles/rails_6.1.gemfile bundle exec rake`

Note that if you don't have all the supported databases installed and running,
some tests will fail.

> Check the `.github/workflows/ci.yml` file for different combinations of Ruby and Rails that are expected to work

### Run tests with Docker

- Open `docker-compose.yml` and configure the Ruby version and Gemfile file to use
- Copy `spec/support/sample.docker.config.yml` to `spec/support/config.yml` (not this config file is specific for the Docker setup)
- Run `docker compose up` to start the container, run the tests, and exit
- Run `docker compose run ruby bash` to open `bash` inside the container for more control, run `rake` to run the tests

> Note that the code is mounted inside the docker container, so changes in the container will reflect in the code. There's no need to re-build the container for code changes, but changing the Ruby version or Gemfile in the docker-compose.yml will require a container re-build with `docker compose build --no-cache`

> Check the `.github/workflows/ci.yml` file for different combinations of Ruby and Rails that are expected to work

## 3. Prepare your contribution

This is all up to you but a few points should be kept in mind:

- Please write tests for your contribution
- Make sure that previous tests still pass
- Push it to a branch of your fork
- Submit a pull request
