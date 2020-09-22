FROM elixir:1.10-alpine as build

# -- Install gosu 1.12

ENV GOSU_VERSION 1.12
RUN set -eux; \
	\
	apk add --no-cache --virtual .gosu-deps \
		ca-certificates \
		dpkg \
		gnupg \
	; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	command -v gpgconf && gpgconf --kill all || :; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
# clean up fetch dependencies
	apk del --no-network .gosu-deps; \
	\
	chmod +x /usr/local/bin/gosu; \
# verify that the binary works
	gosu --version; \
	gosu nobody true


# -- Build pleroma for release 2.1.2

ARG TAG="v2.1.2"
ARG MIX_ENV=prod

RUN apk add git gcc g++ musl-dev make cmake \
&&  git clone -b $TAG --single-branch https://git.pleroma.social/pleroma/pleroma.git /pleroma \
&&  cd /pleroma \
&&  echo "import Mix.Config" > config/prod.secret.exs \
&&  mix local.hex --force \
&&  mix local.rebar --force \
&&  mix deps.get --only prod \
&&  mkdir -p /release \
&&  mix release --path /release

# -------------------------------------------------------------------------------------------------------

#
# elixir 1.10-alpine is built on top of alpine:3.11
#
FROM alpine:3.11

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

RUN apk add --no-cache \
        tini \
	curl \
	ncurses \
	postgresql-client \
	exiftool \
	imagemagick \
&&  addgroup --gid "$GID" pleroma \
&&  adduser --disabled-password --gecos "Pleroma" --home "$HOME" --ingroup pleroma --uid "$UID" pleroma \
&&  mkdir -p ${DATA}/uploads ${DATA}/static \
&&  chown -R pleroma:pleroma ${DATA} \
&&  mkdir -p /etc/pleroma \
&&  chown -R pleroma:root /etc/pleroma

COPY --from=build --chown=0:0 /usr/local/bin/gosu /usr/local/bin
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
