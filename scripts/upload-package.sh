#!/bin/bash -ex

source scripts/defaults

PKG="socorro-${BUILD_VERSION}-1.x86_64.rpm"

curl -T $PKG \
    -ubramwelt:${BINTRAY_API_KEY} \
    https://api.bintray.com/content/bramwelt/rpm/socorro/${BUILD_VERSION}/${PKG}
