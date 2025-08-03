# Use the official Ruby 3.4.2 slim image from Docker Hub
ARG RUBY_VERSION=3.4.2
FROM ruby:${RUBY_VERSION}-slim

# Set the environment to development by default
ENV RAILS_ENV=${RAILS_ENV:-development} \
    RAILS_LOG_TO_STDOUT=true

# Install system dependencies required for the app
# - build-essential: for compiling native gem extensions
# - libsqlite3-dev: for the sqlite3 gem
# - nodejs: for the asset pipeline (if using JavaScript)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libsqlite3-dev nodejs libyaml-dev libcurl4-openssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /rails

# Copy Gemfile and Gemfile.lock to leverage Docker cache
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy the rest of the application code into the container
COPY . .

# Expose the port the app runs on
EXPOSE 3000

# Add an entrypoint script to prepare the database
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# The main command that runs when the container starts
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
