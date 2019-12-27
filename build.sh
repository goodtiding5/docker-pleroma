#!/bin/sh
set -e

TAGINFO=alpine-1.1.7
docker build --compress --rm -t epenguincom/pleroma:$TAGINFO -f Dockerfile .
