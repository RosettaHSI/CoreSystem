#!/bin/sh
###############################################################################
##                           Copyright (c) 2024                              ##
##                         Rosetta H&S Integrated                            ##
###############################################################################
##  Permission is hereby granted, free of charge, to any person obtaining    ##
##        a copy of this software and associated documentation files         ##
##  (the "Software"), to deal in the Software without restriction, including ##
##     without limitation the right to use, copy, modify, merge, publish,    ##
##     distribute, sublicense, and or sell copies of the Software, and to    ##
##         permit persons to whom the Software is furnished to do so,        ##
##                     subject to the following conditions:                  ##
###############################################################################
## The above copyright notice and this permission notice shall be included   ##
##          in all copies or substantial portions of the Software.           ##
###############################################################################
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS   ##
## OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF                ##
## MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.    ##
## IN NO EVENT SHALL THE   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY    ##
## CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT ##
## OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR  ##
## THE USE OR OTHER DEALINGS IN THE SOFTWARE.                                ##
###############################################################################

#===#===#===#===# This file manages building the CoreSystem utilities

#===#===#===> THIS FILE IS SPECIFIC FOR THE ORION CORESYSTEM <===#===#===#
#===#===#===> THIS FILE IS ONLY MEANT TO BE RAN FROM THE OS BUILD SYSTEM!

#===#===#===#===# OS Metadata #===#===#===#===#q
Build_Metadata() {
cat <<-EOF > "Overlay/System/Protected/Static/OsInfo"
    ID="$OS_ID"
    NAME="$OS_NAME"
    LOGO="$OS_LOGO"
    VARIANT="$OS_VARIANT"
    VERSION_ID="$OS_VERSION_ID"
    PRETTY_NAME="$OS_NAME $OS_VERSION_ID $OS_VARIANT"
    VENDOR_NAME="$OS_VENDOR_NAME"
    VENDOR_URL="$OS_VENDOR_URL
    HOME_URL="$OS_HOME_URL"
EOF
}

#===#===#===#===# Make temporary RootFS #===#===#===#===#
TMP_ROOTFS="TmpRoot"
Make_TmpRoot() {
    # Make the base
    [ "$TMP_ROOTFS" ] || return 100
    [ -d "$TMP_ROOTFS" ] && rm -rf "$TMP_ROOTFS"

    mkdir "$TMP_ROOTFS"
    mkdir "$TMP_ROOTFS/etc"

    cp /etc/resolv.conf "$TMP_ROOTFS/etc/resolv.conf"

    # Install the CoreUtils
    cp -r "CoreUtils/$BUILD_ARCH/bin" "$TMP_ROOTFS"
    cp -r "CoreUtils/$BUILD_ARCH/lib" "$TMP_ROOTFS"
}

#===#===#===#===# Install all Packages #===#===#===#===#
Install_CorePkgs() {
    OLD_PATH="$PATH"
    OLD_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
    
    for FILE in $(ls "CorePkgs/$BUILD_ARCH"); do
        echo "Working $FILE..."
        tar -xf "CorePkgs/$BUILD_ARCH/$FILE" -C "$TMP_ROOTFS"
        if [ -f "$TMP_ROOTFS/.post-install" ]; then
            echo ""
            echo "--- Running Post Install script for $FILE ---"
            
            export PATH="/bin:/sbin:/usr/bin:/usr/sbin"
            export LD_LIBRARY_PATH="/lib:/usr/lib:/usr/lib32:/usr/lib64:/usr/libexec"
            chmod +x "$TMP_ROOTFS/.post-install"
            chroot "$TMP_ROOTFS" "/.post-install"
            
            echo "--- Ran Post Install script ---"
            echo ""
            rm "$TMP_ROOTFS/.post-install"
        fi
    done
    PATH="$OLD_PATH"
    
    LD_LIBRARY_PATH="$OLD_LD_LIBRARY_PATH"
    echo "Finished installing all CorePkgs"
}

#===#===#===#===# Transfer all from TmpRoot to OS_ROOTFS #===#===#===#===#
Install_Files() {
    # Transfer from TmpRoot
    [ "$TMP_ROOTFS" ]       || return 101
    [ "$TMP_ROOTFS" = "/" ] && return 102
    [ "$OS_ROOTFS" ]        || return 103
    [ "$OS_ROOTFS" = "/" ]  && return 104

    mv "$TMP_ROOTFS"/usr/sbin/*    "$OS_ROOTFS/System/Binaries"
    mv "$TMP_ROOTFS"/usr/bin/*     "$OS_ROOTFS/System/Binaries"
    mv "$TMP_ROOTFS"/sbin/*        "$OS_ROOTFS/System/Binaries"
    mv "$TMP_ROOTFS"/bin/*         "$OS_ROOTFS/System/Binaries"
    mv "$TMP_ROOTFS"/usr/lib/*     "$OS_ROOTFS/System/Libraries"
    mv "$TMP_ROOTFS"/usr/libexec/* "$OS_ROOTFS/System/Libraries/Exec"
    mv "$TMP_ROOTFS"/usr/share/*   "$OS_ROOTFS/System/PackageData"
    mv "$TMP_ROOTFS"/usr/include/* "$OS_ROOTFS/System/Headers"
    mv "$TMP_ROOTFS"/lib/*         "$OS_ROOTFS/System/Libraries"
    mv "$TMP_ROOTFS"/etc/*         "$OS_ROOTFS/System/Configuration"
    
    # Delete TmpRoot
    rm -rf "$TMP_ROOTFS"

    # Transfer from Rosetta
    [ "$OS_ROOTFS" ]       || return 10
    [ "$OS_ROOTFS" = "/" ] && return 11
    cp --archive -adfvL "Overlay/"* "$OS_ROOTFS/"
    # Perform some fixes cause this shit is broken
    rm "$OS_ROOTFS/System/Configuration/os-release"
    ln -s "../Protected/Static/OsInfo" "$OS_ROOTFS/System/Configuration/os-release"
}

#===#===#===#===# Entry Point #===#===#===#===#
Main() {
    [ "$BUILD_ARCH" ] || exit 127
    [ "$OS_ROOTFS" ]  || exit 127

    Build_Metadata
    Make_TmpRoot
    Install_CorePkgs
    Install_Files

    return 0
}

Main "$@" && exit $?
