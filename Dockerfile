FROM elixir:1.13-alpine as build

# -- Build pleroma release

ARG TAG="v2.4.2"
ARG MIX_ENV=prod

RUN apk add git gcc g++ musl-dev make cmake file-dev \
&&  git clone -b $TAG --single-branch https://git.pleroma.social/pleroma/pleroma.git /pleroma \
&&  cd /pleroma \
&&  sed -i -e '/version: version/s/)//' -e '/version: version/s/version(//' mix.exs \
&&  echo "import Mix.Config" > config/prod.secret.exs \
&&  mix local.hex --force \
&&  mix local.rebar --force \
&&  mix deps.get --only prod \
&&  mkdir -p /release \
&&  mix release --path /release

# -------------------------------------------------------------------------------------------------------

FROM alpine:3.14

LABEL maintainer="ken@epenguin.com"

ARG UID=1000
ARG GID=1000
ARG HOME=/opt/pleroma
ARG DATA=/var/lib/pleroma

ENV DOMAIN=localhost \
    INSTANCE_NAME="Pleroma" \
    ADMIN_EMAIL="admin@localhost" \
    NOTIFY_EMAIL="info@localhost" \
    DB_HOST="db" \
    DB_NAME="pleroma" \
    DB_USER="pleroma" \
    DB_PASS="pleroma"

RUN set -eux \
&&  echo "http://nl.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories \
&&  apk --update add --no-cache tini su-exec ncurses postgresql-client imagemagick ffmpeg exiftool libmagic curl \
&&  addgroup --gid "$GID" pleroma \
&&  adduser --disabled-password --gecos "Pleroma" --home "$HOME" --ingroup pleroma --uid "$UID" pleroma \
&&  mkdir -p ${HOME} ${DATA}/uploads ${DATA}/static /etc/pleroma \
&&  chown -R pleroma:pleroma ${HOME} ${DATA} \
&&  chown -R pleroma:0 /etc/pleroma

COPY --from=build --chown=pleroma:0 /release ${HOME}
COPY --from=build --chown=pleroma:0 /pleroma/config/docker.exs /etc/pleroma/config.exs

COPY ./bin/* /usr/local/bin
COPY ./entrypoint.sh /entrypoint.sh

VOLUME $DATA

EXPOSE 4000

STOPSIGNAL SIGTERM

HEALTHCHECK \
    --start-period=10m \
    --interval=1m \ 
    CMD curl --fail http://localhost:4000/api/v1/instance || exit 1

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
