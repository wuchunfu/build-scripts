#!/bin/bash -e
#
# Copyright 2015-2017 (c) Yousong Zhou
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# On building kernel module
#
#  - Build on CentOS 7 will not work.  CentOS 7 already ships a
#    openvswitch.ko module with GRE and VXLAN support (kernel 3.10).
#  - Build on Debian requires to install
#
#       sudo apt-get install "linux-headers-$(uname -r)"
#
#    OVS has checks to determine if the vxlan module has required features
#    available.  If all rquired features are in the module then only OVS
#    uses it.
#
#    Search for `USE_KERNEL_TUNNEL_API` in the source code.
#
#    - [ovs-discuss] VxLAN kernel module.
#      http://openvswitch.org/pipermail/discuss/2015-March/016947.html
#
#    You may need to upgrade the kernel
#
#    - skb_copy_ubufs() not exported by the Debian Linux kernel 3.2.57-3,
#      https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=746602
#
#  - See INSTALL in openvswtich source tree for details.
#
# On hot upgrade and ovs-ctl
#
#     sudo apt-get install uuid-runtime
#     /usr/local/share/openvswitch/scripts/ovs-ctl force-reload-kmod --system-id=random
#
PKG_NAME=openvswitch
PKG_VERSION=2.10.2
PKG_SOURCE="$PKG_NAME-$PKG_VERSION.tar.gz"
PKG_SOURCE_URL="http://openvswitch.org/releases/$PKG_SOURCE"
PKG_SOURCE_MD5SUM=bdb0a97aac6dc95ea77e12a89df184d8
PKG_DEPENDS=openssl
PKG_PLATFORM=linux

. "$PWD/env.sh"
STRIP=()

do_patch() {
	cd "$PKG_SOURCE_DIR"

	# no autostart on boot
	patch -p1 <<"EOF"
--- a/rhel/openvswitch.spec.orig	2019-10-11 14:27:23.562611813 +0000
+++ b/rhel/openvswitch.spec	2019-10-11 14:37:58.857525470 +0000
@@ -170,7 +170,7 @@ fi
 
 # Ensure all required services are set to run
 /sbin/chkconfig --add openvswitch
-/sbin/chkconfig openvswitch on
+/sbin/chkconfig openvswitch off
 
 %post selinux-policy
 /usr/sbin/semodule -i %{_datadir}/selinux/packages/%{name}/openvswitch-custom.pp &> /dev/null || :

EOF

	patch -p0 <<"EOF"
--- rhel/openvswitch-kmod-fedora.spec.orig	2019-12-02 09:03:51.707248599 +0000
+++ rhel/openvswitch-kmod-fedora.spec	2019-12-02 09:03:57.601258652 +0000
@@ -10,8 +10,6 @@
 
 %global debug_package %{nil}
 
-#%define kernel 3.1.5-1.fc16.x86_64
-#define kernel %{kernel_source}
 %{?kversion:%define kernel %kversion}
 
 Name: openvswitch-kmod
@@ -25,6 +25,7 @@ Version: 2.9.6
 License: GPLv2
 Release: 1%{?dist}
 Source: openvswitch-%{version}.tar.gz
+Patch0: 0001-compat-Fix-compilation-error-on-CentOS-7.6.patch
 #Source1: openvswitch-init
 Buildroot: /tmp/openvswitch-xen-rpm
 
@@ -35,6 +36,7 @@ traffic. This package contains the kerne
 
 %prep
-%setup -q -n openvswitch-%{version}
+%autosetup -p1 -n openvswitch-%{version}
+autoreconf --verbose --force --install
 
 %build
 %configure --with-linux=/lib/modules/%{kernel}/build --enable-ssl
--- rhel/openvswitch-fedora.spec.orig	2019-12-02 09:03:49.824245387 +0000
+++ rhel/openvswitch-fedora.spec	2019-12-02 09:04:03.224268244 +0000
@@ -66,6 +66,7 @@ Version: 2.9.6
 License: ASL 2.0 and LGPLv2+ and SISSL
 Release: 1%{?dist}
 Source: http://openvswitch.org/releases/%{name}-%{version}.tar.gz
+Patch0: 0001-compat-Fix-compilation-error-on-CentOS-7.6.patch
 
 BuildRequires: autoconf automake libtool
 BuildRequires: systemd-units openssl openssl-devel
@@ -215,6 +216,7 @@ Docker network plugins for OVN.
 
 %prep
-%setup -q
+%autosetup -p1
+autoreconf --verbose --force --install
 
 %build
 %configure \
EOF

	cat >rhel/0001-compat-Fix-compilation-error-on-CentOS-7.6.patch <<"EOF"
From 17292e9189fef0e58c590861a125b986b1f50727 Mon Sep 17 00:00:00 2001
From: Yi-Hung Wei <yihung.wei@gmail.com>
Date: Tue, 25 Jun 2019 11:09:07 -0700
Subject: [PATCH] compat: Fix compilation error on CentOS 7.6

This fix the compilation issue on CentOS 7.6 kernel
(3.10.0-957.21.3.el7.x86_64).

Reported-at: https://mail.openvswitch.org/pipermail/ovs-dev/2019-June/360013.html
Reported-by: Fred Neubauer <fred.neubauer@gmail.com>
Fixes: 6660a9597a49 ("datapath: compat: Introduce static key support")
Signed-off-by: Yi-Hung Wei <yihung.wei@gmail.com>
Signed-off-by: Ben Pfaff <blp@ovn.org>
---
 datapath/linux/compat/include/linux/static_key.h | 1 +
 1 file changed, 1 insertion(+)

diff --git a/datapath/linux/compat/include/linux/static_key.h b/datapath/linux/compat/include/linux/static_key.h
index 01c6a93f0..7e43a49e8 100644
--- a/datapath/linux/compat/include/linux/static_key.h
+++ b/datapath/linux/compat/include/linux/static_key.h
@@ -1,6 +1,7 @@
 #ifndef _STATIC_KEY_WRAPPER_H
 #define _STATIC_KEY_WRAPPER_H
 
+#include <linux/atomic.h>
 #include_next <linux/static_key.h>
 #ifndef HAVE_UPSTREAM_STATIC_KEY
 /*
EOF
}

# to disable building python-related code
#CONFIGURE_VARS+=(
#	ovs_cv_python=no
#)

# --enable-ndebug, disable debugging features for max performance
# --with-debug, only takes effect for msvc by passing -O0
#
CONFIGURE_ARGS+=(
	--enable-shared
	--enable-ndebug
)

# EXTRA_CFLAGS+=(-g)

# - What Linux kernel versions does each Open vSwitch release work with?
# - Are all features available with all datapaths?
#   https://github.com/openvswitch/ovs/blob/master/Documentation/faq/releases.rst
# - where most checks are located,
#   https://github.com/openvswitch/ovs/blob/master/acinclude.m4
#   https://github.com/openvswitch/ovs/blob/master/m4/openvswitch.m4
#
# Configure options
#
#	--with-linux, the Linux kernel build directory
#	--with-linux-source, the Linux kernel source directory
#	--with-dpdk, the DPDK build directory
#
# With DPDK 17.05.1, it's possible that both ovs-vswitchd and libopenvswitch.so
# links to libdpdk.so and constructors were called multiple times at dynamic
# link stage causing the program fail early
#
#	EAL: VFIO_RESOURCE_LIST tailq is already registered
#	PANIC in tailqinitfn_rte_vfio_tailq():
#	Cannot initialize tailq: VFIO_RESOURCE_LIST
#	6: [ovs-vswitchd() [0x4284d1]]
#	5: [/lib/x86_64-linux-gnu/libc.so.6(__libc_start_main+0x90) [0x7f93a666ce40]]
#
ovs_enable_dpdk=0
ovs_enable_kmod=1
ovs_kversion="3.10.0-1062.4.3.el7.yn20191203.x86_64"
if [ -z "$ovs_kversion" ]; then
	ovs_kversion="$(uname -r)"
fi
ovs_kbuild_dir=

if [ "$ovs_enable_kmod" -gt 0 ]; then
	ovs_with_kmod="/lib/modules/$ovs_kversion/build"
	if [ -d "$ovs_with_kmod" ]; then
		ovs_kbuild_dir="$ovs_with_kmod"
	else
		ovs_kbuild_dir="/usr/src/kernels/$ovs_kversion"
		if [ ! -d "$ovs_kbuild_dir" ]; then
			__errmsg "openvswitch: cannot find kernel build dir $ovs_kbuild_dir, or $ovs_with_kmod"
			false
		fi
	fi
	CONFIGURE_ARGS+=(
		--with-linux="$ovs_kbuild_dir"
	)
	MAKE_ENVS+=(
		INSTALL_MOD_PATH=""$PKG_STAGING_DIR$INSTALL_PREFIX""
	)
fi

if [ "$ovs_enable_dpdk" -gt 0 ]; then
	ovs_with_dpdk="$("$TOPDIR/build-dpdk.sh" dpdk_prefix)"
	if [ ! -d "$ovs_with_dpdk" ]; then
		__errmsg "openvswitch: cannot find dpdk dir dir $ovs_with_dpdk"
		false
	fi
	CONFIGURE_ARGS+=(
		--with-dpdk="$ovs_with_dpdk"
	)
	PKG_DEPENDS="$PKG_DEPENDS dpdk"
fi

staging() {
	local d0="$PKG_STAGING_DIR$INSTALL_PREFIX"
	local d1="$INSTALL_PREFIX"
	local ds0="$d0/share/openvswitch/scripts"
	local ds1="$d1/share/openvswitch/scripts"

	build_staging 'install'
	if [ "$ovs_enable_kmod" -gt 0 ]; then
		build_staging modules_install
	fi
	cat >"$ds0/ovs-wrapper" <<-EOF
		#/usr/bin/env bash
		case "\$0" in
		    *ovs-ctl) "$ds1/ovs-ctl" "\$@" ;;
		    *ovs-kmod-ctl) "$ds1/ovs-kmod-ctl" "\$@" ;;
		    *ovn-ctl) "$ds1/ovn-ctl" "\$@" ;;
		esac
	EOF
	chmod a+x "$ds0/ovs-wrapper"
	ln -sf "../share/openvswitch/scripts/ovs-wrapper" "$d0/bin/ovs-ctl"
	ln -sf "../share/openvswitch/scripts/ovs-wrapper" "$d0/bin/ovs-kmod-ctl"
	ln -sf "../share/openvswitch/scripts/ovs-wrapper" "$d0/bin/ovn-ctl"
}

build_rpm() {
	local topdir="$PKG_BUILD_DIR/rpmbuild"
	local bn="$PKG_NAME-$PKG_VERSION"

	unset PKG_CONFIG_PATH

	cd "$PKG_SOURCE_DIR/.."
	mkdir -p "$topdir/SOURCES"
	tar czf "$topdir/SOURCES/$PKG_SOURCE" \
		--exclude "$bn/rpmbuild" \
		"$bn" >"$topdir/SOURCES/$bn.tar.gz"
	find "$PKG_SOURCE_DIR/rhel" -name '*.patch' | while read f; do
		cp "$f" "$topdir/SOURCES"
	done

	cpdir "$PKG_SOURCE_DIR/rhel" "$topdir/SPECS"
	cd "$topdir/SPECS"
	# Use openvswitch-fedora as suggested by
	# http://docs.openvswitch.org/en/latest/intro/install/fedora/
	#
	#sudo yum-builddep openvswitch-fedora.spec
	rpmbuild \
		--without check \
		-bb \
		-D "%_topdir $topdir" \
		openvswitch-fedora.spec

	# Setting %kernel based on value of %kversion at the top of spec file
	# can get reverted when applying patches.  That's way we set %kernel
	# explicitly
	#
	# Also it's important that we remove the comment lines placed ahead of
	# setting %kernel in the spec file, otherwise %kernel can always take
	# value 3.1.5-1.fc16.x86_64
	sed -i -e 's/openvswitch-kmod/kmod-openvswitch/g' \
		openvswitch-kmod-fedora.spec
	sed -i -e "s:=/lib/modules/%{kernel}/build:=${ovs_kbuild_dir}:g" \
		openvswitch-kmod-fedora.spec
	rpmbuild \
		-bb \
		-D "%_topdir $topdir" \
		-D "kversion $ovs_kversion" \
		-D "kernel $ovs_kversion" \
		openvswitch-kmod-fedora.spec
}

install_post() {
	if [ -d "$ovs_with_kmod" ]; then
		__errmsg "
Note that different builds of openvswitch may have different --prefix hardcoded
in.  You may not want to invoke 'ovs-ctl force-reload-kmod' against a running
instance configured with different --prefix setting
"
	fi
}
