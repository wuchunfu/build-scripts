#!/bin/sh -e

PKG_NAME=utdnsd
PKG_VERSION=2016-03-09
PKG_SOURCE_VERSION=32e9cd8f8e73541aced4e224d7f72c5a8f5b16a9
PKG_SOURCE="$PKG_NAME-$PKG_VERSION-$PKG_SOURCE_VERSION.tar.gz"
PKG_SOURCE_URL="https://github.com/yousong/utdnsd/archive/$PKG_SOURCE_VERSION.tar.gz"
PKG_SOURCE_UNTAR_FIXUP=1
PKG_CMAKE=1
PKG_DEPENDS='libubox'

. "$PWD/env.sh"
