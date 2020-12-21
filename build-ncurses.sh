#!/bin/bash -e
#
# Copyright 2016 (c) Yousong Zhou
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# - See section "Growth of the feature set",
#   http://invisible-island.net/ncurses/ncurses.faq.html
#
PKG_NAME=ncurses
PKG_VERSION=6.2
PKG_SOURCE="$PKG_NAME-$PKG_VERSION.tar.gz"
PKG_SOURCE_URL="http://ftp.gnu.org/gnu/ncurses/$PKG_SOURCE"
PKG_SOURCE_MD5SUM=e812da327b1c2214ac1aed440ea3ae8d

. "$PWD/env.sh"

# We don't want to be affected by ncurses libraries of the build system
EXTRA_CPPFLAGS=()
EXTRA_CFLAGS=()
EXTRA_LDFLAGS=(
	-L"$INSTALL_PREFIX/lib"
	-Wl,-rpath,"$INSTALL_PREFIX/lib"
)
CONFIGURE_VARS+=(
	PKG_CONFIG_LIBDIR="$INSTALL_PREFIX/lib/pkgconfig"
)
# - enable building shared libraries
# - suppress check for ada95
# - dont generate debug-libraries (those ending with _g)
# - compile with wide-char/UTF-8 code
# - --enable-overwrite,
# - compile in termcap fallback support
# - compile with SIGWINCH handler
CONFIGURE_ARGS+=(
	--with-shared
	--with-cxx-shared
	--with-normal
	--with-manpage-format=normal
	--without-ada
	--without-debug
	--enable-widec
	--enable-overwrite
	--enable-termcap
	--enable-sigwinch
	--enable-pc-files
	--mandir="$INSTALL_PREFIX/share/man"
	--with-pkg-config-libdir="$INSTALL_PREFIX/lib/pkgconfig"
)
# we cannot do autoreconf because AC_DIVERT_HELP may not be universally
# available

staging_post() {
	local major="${PKG_VERSION%%.*}"
	local f based="$PKG_STAGING_DIR$INSTALL_PREFIX"
	local suf sufm

	staging_post_default

	if os_is_linux; then
		suf=so
		sufm="so.${major}"
	else
		suf=dylib
		sufm="${major}.dylib"
	fi

	# link from normal version to the wchar version.  and the name ncurses++w
	# is just right, not the ncursesw++
	mkdir -p "$based/lib/pkgconfig"
	for f in form menu panel ncurses ncurses++; do
		if [ "$f" != "ncurses++" ]; then
			ln -s "lib${f}w.$sufm" "$based/lib/lib${f}.$suf"
			ln -s "lib${f}w.$sufm" "$based/lib/lib${f}.$sufm"
		fi
		ln -s "lib${f}w.a" "$based/lib/lib${f}.a"
		ln -s "${f}w.pc" "$based/lib/pkgconfig/${f}.pc"
	done
	# link from curses version to ncurses with wchar support version
	for f in curses curses++; do
		# or we can make a lib${f}.$suf with content INPUT(libn${f}w.$suf)
		if [ "$f" != "curses++" ]; then
			ln -s "libn${f}w.$suf" "$based/lib/lib${f}.$suf"
		fi
		ln -s "libn${f}w.a" "$based/lib/lib${f}.a"
		ln -s "n${f}w.pc" "$based/lib/pkgconfig/${f}.pc"
	done
	ln -s "libncurses.$sufm" $based/lib/libtermcap.$suf
	ln -s "ncursesw${major}-config" "$based/bin/ncurses${major}-config"
}
