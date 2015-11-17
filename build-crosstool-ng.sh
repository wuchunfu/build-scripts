#!/bin/sh -e
#
# crosstool-ng needs gperf and makeinfo
#
#	yum install -y gperf texinfo
#
PKG_NAME=crosstool-ng
PKG_VERSION="1.21.0"
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.bz2"
PKG_SOURCE_URL="http://crosstool-ng.org/download/crosstool-ng/$PKG_SOURCE"
PKG_SOURCE_MD5SUM="436c95ce91a9140fa03ddb32fc0db3f5"

. "$PWD/env.sh"

main
