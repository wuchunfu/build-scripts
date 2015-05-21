#!/bin/sh -e

# Vim on Debian Wheezy 7 has version 7.3.547 (Fetched with command "vim --version")
#
#       sudo apt-get build-dep vim-nox
#

# 7.3 is the release version.
# 547 is the number of applied patches provided by vim.org.
VER="7.4"
VER_ND="$(echo $VER | tr -d .)"

# where to install
INSTALL_PREFIX="$PWD/_vim-install"
NJOBS=32

# If we have git repo present, extract sources from there
# rather than downloading them over the network.
TOPDIR="$PWD"
SOURCE_DIR="$PWD/vim$VER_ND"
PATCH_DIR="$PWD/vim$VER_ND-patches"
BUILD_DIR="$PWD/vim$VER_ND"

__errmsg() {
    echo "$1" >&2
}

prepare_from_tarball() {
    local ver="$VER"
    local fn="vim-$ver.tar.bz2"
    local url="ftp://ftp.vim.org/pub/vim/unix/$fn"

    [ -x "$SOURCE_DIR/configure" ] && {
        __errmsg "$SOURCE_DIR/configure already exists, skip preparing."
        return 0
    } || {
        wget -c -O "$fn" "$url"
        tar -xjf "$fn"
    }
}

fetch_patches() {
    local ver="$VER"
    local num_patches
    local num_process
    local i

    mkdir -p "$PATCH_DIR"
    cd "$PATCH_DIR"

    [ -s ".listing" ] && {
        num_patches="$(cat .listing | awk '{ print $9 }' | grep -F "$ver." | wc -l)"
        num_patches_0="$(ls | wc -l)"
        [ "$num_patches" -eq "$num_patches_0" ] && {
            __errmsg "All fetched, skip fetching patches."
            return 0
        } || true
    } || true

    wget --no-remove-listing --spider "ftp://ftp.vim.org/pub/vim/patches/$ver/"
    num_patches="$(cat .listing | awk '{ print $9 }' | grep -F "$ver." | wc -l)"
    num_process="$(($num_patches / 100))"
    for i in $(seq 0 $num_process); do
        # Each wget fetches at most 100 patches.
        cat .listing | \
            awk " \$9 ~ /$ver\.$i[0-9]{2}/ { print \"ftp://ftp.vim.org/pub/vim/patches/$ver/\"\$9 } " | \
            wget --no-verbose -c -i - &
    done
    wait
    cd -
}

apply_patches() {
    local f

    cd "$SOURCE_DIR"

    [ -f ".patched" ] && {
        __errmsg "$SOURCE_DIR/.patched exists, skip patching."
        return 0
    } || true

    for f in $(ls "$PATCH_DIR"); do
        patch -p0 -i "$PATCH_DIR/$f"
    done
    touch .patched

    cd -
}

build_vim() {
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # re-prepare $SOURCE_DIR if configure failed due to cache problems.
    "$SOURCE_DIR/configure"           \
        --prefix="$INSTALL_PREFIX"    \
        --enable-fail-if-missing      \
        --enable-luainterp            \
        --enable-perlinterp           \
        --enable-pythoninterp         \
        --enable-rubyinterp           \
        --enable-cscope               \
        --enable-multibyte            \
        #--enable-python3interp        \

    make -j "$NJOBS"
    make install

    cd "$TOPDIR"
}

show_build_dep() {
    local pkg="$1"

    apt-cache showsrc "$pkg" | sed -e '/Build-Depends:/!d;s/Build-Depends: \| |\|,\|([^)]*),*\|\[[^]]*\]//g'
    apt-cache showsrc "$pkg" | sed -e '/Build-Depends-Indep:/!d;s/Build-Depends-Indep: \| |\|,\|([^)]*),*\|\[[^]]*\]//g'
}

remove_build_dep() {
    local build_dep_vim_nox="$(show_build_dep vim-nox)"

    sudo aptitude markauto $build_dep_vim_nox
    sudo apt-get autoremove
}

prepare_from_tarball
fetch_patches
apply_patches
build_vim
