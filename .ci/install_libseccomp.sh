#!/bin/bash
#
# Copyright 2021 Sony Group Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o nounset

cidir=$(dirname "$0")
arch=$("${cidir}"/kata-arch.sh -d)

libseccomp_version="2.5.1"
libseccomp_tarball="libseccomp-${libseccomp_version}.tar.gz"
libseccomp_url="https://github.com/seccomp/libseccomp/releases/download/v${libseccomp_version}/${libseccomp_tarball}"
#libseccomp_install_dir=$(mktemp -d -t install-libseccomp-v"${libseccomp_version}".XXXXXXXXXX)
libseccomp_install_dir="/usr/local/libseccomp-${libseccomp_version}"
musl_include_path="/usr/include"
cppflags=""
cflags=""

# We need to build the libseccomp library from sources to create a static library using the musl libc.
# However, ppc64le and s390x have no musl targets in Rust. Hence, we do not use the musl libc.
if ([ "${arch}" != "ppc64le" ] && [ "${arch}" != "s390x" ]); then
    cppflags="-I${musl_include_path}/${arch}-linux-musl"
    # Ignore a warning about parentheses around arithmetic in musl libc
    cflags="-Wno-parentheses"
fi

finish() {
    rm -rf "${libseccomp_tarball}" "libseccomp-${libseccomp_version}"
}

trap finish EXIT

build_and_install_libseccomp() {
    echo "Build and install libseccomp version ${libseccomp_version}"
    sudo mkdir -p "${libseccomp_install_dir}"
    curl -L -O ${libseccomp_url}
    tar -xf "${libseccomp_tarball}"
    pushd "libseccomp-${libseccomp_version}"
    ./configure --prefix="${libseccomp_install_dir}" CPPFLAGS="${cppflags}" CFLAGS="${cflags}" --enable-static --disable-shared
    make
    sudo make install
    popd
    echo "Libseccomp installed successfully"
}

set_env_for_libseccomp_crate() {
    echo "Set environment variables for the libseccomp crate to link the libseccomp library statically"
    export LIBSECCOMP_LINK_TYPE=static
    export LIBSECCOMP_LIB_PATH="${libseccomp_install_dir}/lib"
}

main() {
    build_and_install_libseccomp
    set_env_for_libseccomp_crate
}

main
