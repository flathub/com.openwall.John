#!/bin/bash

###############################################################################
#        _       _             _   _            _____  _
#       | |     | |           | | | |          |  __ \(_)
#       | | ___ | |__  _ __   | |_| |__   ___  | |__) |_ _ __  _ __   ___ _ __
#   _   | |/ _ \| '_ \| '_ \  | __| '_ \ / _ \ |  _  /| | '_ \| '_ \ / _ \ '__|
#  | |__| | (_) | | | | | | | | |_| | | |  __/ | | \ \| | |_) | |_) |  __/ |
#   \____/ \___/|_| |_|_| |_|  \__|_| |_|\___| |_|  \_\_| .__/| .__/ \___|_|
#                                                       | |   | |
#                                                       |_|   |_|
#
# Copyright (c) 2019-2024 Claudio André <dev at claudioandre.slmail.me>
#
# This program comes with ABSOLUTELY NO WARRANTY; express or implied.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, as expressed in version 2, seen at
# http://www.gnu.org/licenses/gpl-2.0.html
###############################################################################
# Script to automate the build of John the Ripper flatpak
# More info at https://github.com/openwall/john-packages

function save_build_info() {
    (
    cd .. || exit 1

    cat <<-EOF > run/Defaults
#   File that lists how the build (binaries) were made
[Build Configuration]
System Wide Build=Yes
Architecture="$(uname -m)"
OpenMP, OpenCL=No
Optional Libraries=Yes
Regex, OpenMPI, Experimental Code, ZTEX=No
Version="1.9J1+"
EOF

    )
}

function clean_image() {
    (
    cd .. || exit 1

    rm -rf ../run/ztex
    )
}

# Build options (system wide, disable checks, etc.)
SYSTEM_WIDE='--with-systemwide --enable-rexgen'
X86_REGULAR="--disable-native-tests --disable-opencl $SYSTEM_WIDE"
X86_NO_OPENMP="--disable-native-tests --disable-opencl $SYSTEM_WIDE --disable-openmp"

OTHER_REGULAR="$SYSTEM_WIDE"
OTHER_NO_OPENMP="$SYSTEM_WIDE --disable-openmp"

# Build helper
function do_build () {
    set -e

    if [[ -n "$1" ]]; then
        make -s clean && make -sj4 && mv ../run/john "$1"
    else
        make -s clean && make -sj4
    fi
    set +e
}

#if (Build); then
    echo ""
    echo "---------------------------- BUILDING -----------------------------"

    if [[ "$(uname -m)" == "x86_64" ]]; then
        # x86_64 CPU (OMP and SIMD fallback)
        ./configure $X86_NO_OPENMP --enable-simd=avx    CPPFLAGS="-D_BOXED" && do_build ../run/john-avx
        ./configure $X86_REGULAR   --enable-simd=avx    CPPFLAGS="-D_BOXED -DOMP_FALLBACK_BINARY=\"\\\"john-avx\\\"\"" && do_build ../run/john-avx-omp
        ./configure $X86_NO_OPENMP --enable-simd=avx2   CPPFLAGS="-D_BOXED" && do_build ../run/john-avx2
        ./configure $X86_REGULAR   --enable-simd=avx2   CPPFLAGS="-D_BOXED -DOMP_FALLBACK_BINARY=\"\\\"john-avx2\\\"\" -DCPU_FALLBACK_BINARY=\"\\\"john-avx-omp\\\"\"" && do_build ../run/john-avx2-omp
        ./configure $X86_NO_OPENMP --enable-simd=avx512f  CPPFLAGS="-D_BOXED" && do_build ../run/john-avx512f
        ./configure $X86_REGULAR   --enable-simd=avx512f  CPPFLAGS="-D_BOXED -DOMP_FALLBACK_BINARY=\"\\\"john-avx512f\\\"\" -DCPU_FALLBACK_BINARY=\"\\\"john-avx2-omp\\\"\"" && do_build ../run/john-avx512f-omp
        ./configure $X86_NO_OPENMP --enable-simd=avx512bw CPPFLAGS="-D_BOXED" && do_build ../run/john-avx512bw
        ./configure $X86_REGULAR   --enable-simd=avx512bw CPPFLAGS="-D_BOXED -DOMP_FALLBACK_BINARY=\"\\\"john-avx512bw\\\"\" -DCPU_FALLBACK_BINARY=\"\\\"john-avx512f-omp\\\"\"" && do_build ../run/john-avx512bw-omp

        #Create a 'john' executable
        (
            cd ../run || exit 1
            ln -s john-avx512bw-omp john
        )
    else
        # Non X86 CPU (OMP fallback)
        ./configure $OTHER_NO_OPENMP   CPPFLAGS="-D_BOXED" && do_build "../run/john-$arch"
        ./configure $OTHER_REGULAR     CPPFLAGS="-D_BOXED -DOMP_FALLBACK_BINARY=\"\\\"john-$arch\\\"\"" && do_build ../run/john-omp

        #Create a 'john' executable
        (
            cd ../run || exit 1
            ln -s john-omp john
        )
    fi
#Done
save_build_info
clean_image
