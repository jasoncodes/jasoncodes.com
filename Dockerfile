FROM ruby:3.4.9 AS ruby
FROM node:14.16.0 AS node

FROM ruby AS build
COPY --from=node /usr/local /usr/local
COPY --from=node /opt /opt

WORKDIR /app

COPY Gemfile* ./

RUN \
  --mount=type=cache,id=bundle-cache,target=/var/cache/bundle \
  <<SH
  set -euo pipefail
  export GEM_HOME="/var/cache/bundle/debian-$(cat /etc/debian_version)-ruby-$RUBY_VERSION"
  export BUNDLE_FROZEN=true
  gem install --conservative "bundler:$(tail -n1 Gemfile.lock | awk '{print $1}')"
  bundle install --no-clean
  echo "Copying bundle cache to target..."
  tar c -C "$GEM_HOME" --anchored --no-wildcards-match-slash --exclude=./cache . | tar x -C /usr/local/bundle
  bundle clean --force
SH

COPY . /app
RUN bundle exec rake build

FROM httpd:2.4 AS server
RUN sed -i -E -e 's/AllowOverride None/AllowOverride All/i' -e 's/^#(LoadModule (expires|rewrite)_module)/\1/' /usr/local/apache2/conf/httpd.conf
COPY --from=build /app/_site /usr/local/apache2/htdocs
