FROM alpine:3 AS alpine

ARG RAILS_ROOT=/usr/src/app
ENV RAILS_ROOT=${RAILS_ROOT}

USER root
WORKDIR $RAILS_ROOT

FROM alpine AS base
RUN apk add --no-cache \
    libpq \
    libxml2 \
    libxslt \
    libstdc++ \
    ruby \
    ruby-bigdecimal \
    ruby-bundler \
    ruby-rake \
    ruby-dev \
    nodejs npm yarn \
    tini \
    tzdata \
    gettext \
    imagemagick \
    shared-mime-info

FROM base AS builder
RUN apk add --update --no-cache \
    build-base \
    libxml2-dev \
    libxslt-dev \
    libffi-dev \
    pkgconf \
    postgresql-dev \
    yaml-dev \
    zlib-dev \
    curl-dev git \
    && ( echo 'install: --no-document' ; echo 'update: --no-document' ) >>/etc/gemrc
COPY . ./
RUN bundle config build.nokogiri --use-system-libraries \
    && bundle config set --local deployment 'true' \
    && bundle config set --local without 'development:test' \
    && bundle config set frozen false
RUN bundle install -j4 \
    && rm -rf vendor/bundle/ruby/*/cache \
    && find vendor/bundle/ruby/*/gems/ \( -name '*.c' -o -name '*.o' \) -delete
RUN yarn install --check-files

FROM base AS application
RUN apk add --no-cache \
    bash \
    postgresql-client
ARG RAILS_ENV
ENV RAILS_ENV=${RAILS_ENV:-production}
ARG BUILD_NUMBER
ENV BUILD_NUMBER=${BUILD_NUMBER}
COPY --from=builder /usr/src/app ./

FROM application
ARG PORT
ENV PORT=${PORT:-3000}
EXPOSE ${PORT}

# Precompile assets
RUN SECRET_KEY_BASE=1 RAILS_ENV=${RAILS_ENV:-production} RELATIVE_URL_ROOT=${RELATIVE_URL_ROOT:-lti} bundle exec rake assets:precompile --trace

# Run startup command
CMD ["scripts/start.sh"]
