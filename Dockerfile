FROM ruby:3.3.9-alpine

# Setup build variables
ARG RAILS_ENV
ARG APP_HOST=localhost
ARG DERIVATIVES_PATH
ARG UPLOADS_PATH
ARG CACHE_PATH
ARG FITS_VERSION
ARG DOWNLOAD_PATH
ARG REGISTER_VALKYRIE=false
ARG APP_PRODUCTION=/data/
ENV NODE_OPTIONS=--openssl-legacy-provider

# Add backports to apt-get sources
# Install libraries, dependencies, java and fits

# COPY deploy_info_check.sh $APP_PRODUCTION
# COPY deploy_info.json $APP_PRODUCTION
# RUN chmod +x /data/deploy_info_check.sh
# RUN /data/deploy_info_check.sh

RUN apk update && \
    apk upgrade && \
    apk add bash build-base curl curl-dev gcompat imagemagick imagemagick-libs imagemagick-dev libreoffice libjpeg libarchive-tools  \
    libpq-dev libxml2-dev libxslt-dev nodejs openjdk11-jre-headless sqlite-dev tzdata yarn git firefox-esr ghostscript

# install required fonts for testing
RUN apk add --no-cache fontconfig ttf-dejavu ttf-liberation

COPY policy.xml /etc/ImageMagick-7/policy.xml

RUN mkdir -p /fits/fits-$FITS_VERSION \
    && curl --fail --location "https://github.com/harvard-lts/fits/releases/download/$FITS_VERSION/fits-$FITS_VERSION.zip" | bsdtar --extract --directory /fits/fits-$FITS_VERSION \
    && chmod +x "/fits/fits-$FITS_VERSION/fits.sh" "/fits/fits-$FITS_VERSION/fits-env.sh" "/fits/fits-$FITS_VERSION/fits-ngserver.sh"

# copy gemfiles to production folder
COPY Gemfile Gemfile.lock $APP_PRODUCTION

# install gems to system - use flags dependent on RAILS_ENV
RUN cd $APP_PRODUCTION \
    && bundle config build.nokogiri --use-system-libraries \
    && if [ "$RAILS_ENV" = "production" ]; then \
            bundle config set without 'test:development';\
        else \
            bundle config set without production;\
            bundle config set deployment false;\
        fi \
    && bundle install \
    && mv Gemfile.lock Gemfile.lock.built_by_docker

# create a folder to store derivatives, file uploads and cache directory
RUN mkdir -p $DERIVATIVES_PATH
RUN mkdir -p $UPLOADS_PATH
RUN mkdir -p $CACHE_PATH
RUN mkdir -p $DOWNLOAD_PATH

# copy the application
COPY . $APP_PRODUCTION

# use the just built Gemfile.lock, not the one copied into the container and verify the gems are correctly installed
RUN cd $APP_PRODUCTION \
    && mv Gemfile.lock.built_by_docker Gemfile.lock \
    && bundle check

# generate production assets if production environment
RUN cd $APP_PRODUCTION \
    && if [ "$RAILS_ENV" = "production" ]; then \
        SECRET_KEY_BASE_PRODUCTION=0 bundle exec rake assets:clean assets:precompile; \
    fi

COPY docker-entrypoint.sh /bin/

WORKDIR $APP_PRODUCTION

RUN mkdir -p /data-backup/public
RUN if [ "$RAILS_ENV" = "production" ] && [-d $APP_PRODUCTION/public/assets]; then \
      cp -Rp $APP_PRODUCTION/public/assets /data-backup/public/; \
    fi

RUN chmod +x /bin/docker-entrypoint.sh

# RUN find / -name "docker-entrypoint_test.sh"
COPY docker-entrypoint_test.sh /bin/
RUN chmod +x /bin/docker-entrypoint_test.sh
