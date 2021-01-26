# Build for 'pleroma'
#   Fetch OTP instead

FROM alpine:3 as build

ARG FLAVOUR=amd64-musl

RUN set -eux \
&&  apk add --no-cache unzip \
&&  mkdir -p /build \
&&  wget -q -O /tmp/pleroma.zip "https://git.pleroma.social/api/v4/projects/2/jobs/artifacts/stable/download?job=$FLAVOUR" \
&&  unzip -q /tmp/pleroma.zip -d /build/ \
&&  wget -q -O /build/docker.exs "https://git.pleroma.social/pleroma/pleroma/-/raw/stable/config/docker.exs"

FROM alpine:3

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
&&  apk --update add --no-cache tini su-exec ncurses postgresql-client imagemagick ffmpeg exiftool libmagic \
&&  addgroup --gid "$GID" pleroma \
&&  adduser --disabled-password --gecos "Pleroma" --home "$HOME" --ingroup pleroma --uid "$UID" pleroma \
&&  mkdir -p ${DATA}/uploads ${DATA}/static \
&&  chown -R pleroma:pleroma ${DATA}

COPY --from=build --chown=pleroma:pleroma /build/release $HOME
COPY --from=build --chown=pleroma:0 /build/docker.exs /etc/pleroma/config.exs
COPY ./bin /usr/local/bin
COPY ./entrypoint.sh /entrypoint.sh

VOLUME $DATA

EXPOSE 4000

STOPSIGNAL SIGTERM

HEALTHCHECK \
    --start-period=10m \
    --interval=5m \ 
    CMD curl --fail http://localhost:4000/api/v1/instance || exit 1

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
