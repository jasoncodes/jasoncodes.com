FROM ruby:2.7.5 AS ruby
FROM node:14.16.0 AS node

FROM ruby AS build
COPY --from=node /usr/local /usr/local
COPY --from=node /opt /opt

WORKDIR /app

COPY Gemfile* ./
RUN gem install bundler:$(tail -n1 Gemfile.lock | awk '{print $1}')
RUN bundle config --global frozen 1 && bundle install

COPY . /app
RUN bundle exec rake build

FROM httpd:2.4 AS server
RUN sed -i -E -e 's/AllowOverride None/AllowOverride All/i' -e 's/^#(LoadModule (expires|rewrite)_module)/\1/' /usr/local/apache2/conf/httpd.conf
COPY --from=build /app/_site /usr/local/apache2/htdocs
