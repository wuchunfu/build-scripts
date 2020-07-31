#!/bin/bash -e
#
# Copyright 2015-2016 (c) Yousong Zhou
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# rtmpdump 2.4 is still in the git repo and contains a lot of features and
# bugfixes not available in 2.3 which was released at 2010-06-30
PKG_NAME=rtmpdump
PKG_VERSION=2019-03-30
PKG_SOURCE_URL="git://git.ffmpeg.org/rtmpdump"
PKG_SOURCE_VERSION=c5f04a58fc2aeea6296ca7c44ee4734c18401aa3
PKG_DEPENDS=gnutls

. "$PWD/env.sh"

do_patch() {
	cd "$PKG_SOURCE_DIR"

	patch -p0 <<"EOF"
--- Makefile.orig	2015-12-23 12:05:04.901000015 +0800
+++ Makefile	2015-12-23 12:05:09.890000016 +0800
@@ -26,7 +26,7 @@ LDFLAGS=-Wall $(XLDFLAGS)
 
 bindir=$(prefix)/bin
 sbindir=$(prefix)/sbin
-mandir=$(prefix)/man
+mandir=$(prefix)/share/man
 
 BINDIR=$(DESTDIR)$(bindir)
 SBINDIR=$(DESTDIR)$(sbindir)
--- librtmp/Makefile.orig	2015-12-23 12:05:04.901000015 +0800
+++ librtmp/Makefile	2015-12-23 12:05:09.890000016 +0800
@@ -5,7 +5,7 @@ LDFLAGS=-Wall $(XLDFLAGS)
 incdir=$(prefix)/include/librtmp
 bindir=$(prefix)/bin
 libdir=$(prefix)/lib
-mandir=$(prefix)/man
+mandir=$(prefix)/share/man
 BINDIR=$(DESTDIR)$(bindir)
 INCDIR=$(DESTDIR)$(incdir)
 LIBDIR=$(DESTDIR)$(libdir)
@@ -115,6 +115,7 @@ LDFLAGS=-Wall $(XLDFLAGS)
 	cp librtmp.3 $(MANDIR)/man3
 
 install_so:	librtmp$(SO_EXT)
+	-mkdir -p $(SODIR)
 	cp librtmp$(SO_EXT) $(SODIR)
	$(INSTALL_IMPLIB)
 	cd $(SODIR); ln -sf librtmp$(SO_EXT) librtmp.$(SOX)
EOF
}

configure() {
	true
}


rtmpdump_init() {
	local sys
	if os_is_darwin; then
		sys=darwin
	else
		sys=posix
	fi
	MAKE_VARS=(
		CRYPTO=GNUTLS
		prefix="$INSTALL_PREFIX"
		SYS="$sys"
		XCFLAGS="${EXTRA_CFLAGS[*]}"
		XLDFLAGS="${EXTRA_LDFLAGS[*]}"
	)
}
rtmpdump_init
