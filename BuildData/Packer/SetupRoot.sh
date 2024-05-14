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

#===#===#===#===# Global Constants #===#===#===#===#
readonly EXEC_NAME="${0##*/}"
readonly EXEC_DIR=$(dirname $(realpath $0))
readonly DATA_DIR="$EXEC_DIR"
# readonly EXEC_VER="0.0.1"

#===#===#===#===# Global Variables #===#===#===#===#
ANSI=true
VERBOSE=false
AUTOYES=false

#===#===#===#===# Load Commons #===#===#===#===#
[ $_PKG_COMMON_LOADED ] || . "$EXEC_DIR/Common.sh"

#===#===#===#===# Usage #===#===#===#===#
SetupRoot_Usage() {
    echo ""
    echo "$EXEC_NAME v$EXEC_VER - Rosetta Utility for setting up a chroot environment for Packer."
    echo "  Copyright 2024 - Rosetta HSI. This software comes with absolutely"
    echo "  NO WARRANTY and is released under the MIT License."
    echo ""
    echo "  --- Usage: $EXEC_NAME -o <Output> [options...]"
    echo "       $ $EXEC_NAME -o /Packages -v"
    echo ""
    echo "  --- Flags:"
    echo "    -h : Display this Help message."
    echo ""
    echo "    -o : The path to the Packer Packages directory. This is where the Packer chroot"
    echo "         environment will be placed and initialised."
    echo ""
    echo "    -Y : Automatically answers \"y\" to all prompts. DANGEROUS!"
    echo ""
    echo "    -v : Enable verbose logging."
    echo ""
    echo "    -@ : No ANSI escape sequences for color or prompts."
    echo ""

    exit $1
}

#===#===#===#===# Read options from cmdline #===#===#===#===#
Get_Options() {
    while getopts @hvYo: flag
    do
        case "${flag}" in
            @) ANSI=false;;
            h) Build_Usage 0;;
            v) VERBOSE=true;;
            Y) AUTOYES=true;;
            o) ROOTDIR="${OPTARG}";;
            *) SetupRoot_Usage $ERR_INVALID_OPTION;;
        esac
    done
}

#===#===#===#===# Validate Unmount #===#===#===#===#
Validate_Umount() {
    if [ -d "$1" ]; then
        CONTENT=$(ls "$1/")
        Log "Content of \"$1\" = \"$CONTENT\""
        [ "$CONTENT" ] && Error "Unmount of \"$ROOTDIR/.root/$1\" failed. Bailing to prevent accidental deletion of files." $ERR_NO_PERMISSION \
                       || Log "^ Contents OK."
    fi
}

#===#===#===#===# Setup Mounts #===#===#===#===#
Run_Mounts() {
    local MOUNT_FLAGS="--bind"
    local UMOUNT_FLAGS="-lf"

    local ROOTDIR=$(realpath "$ROOTDIR")

    # WARNING #
    # $ROOTDIR MUST BE AN ABSOLUTE PATH!

    if [ "$1" = "--mount" ]; then
        Log "Running Mount actions for \"$ROOTDIR/.root\""
        [ -d "/Applications" ] && mount $MOUNT_FLAGS "/Applications" "$ROOTDIR/.root/Applications"
        [ -d "/Mount" ]        && mount $MOUNT_FLAGS "/Mount"        "$ROOTDIR/.root/Mount"
        [ -d "/Packages" ]     && mount $MOUNT_FLAGS "/Packages"     "$ROOTDIR/.root/Packages/"
        [ -d "/System" ]       && mount $MOUNT_FLAGS "/System"       "$ROOTDIR/.root/System"
        [ -d "/Users" ]        && mount $MOUNT_FLAGS "/Users"        "$ROOTDIR/.root/Users"
        
        #===#===#===> Mount packerenv over the packer directory
        [ -d "$ROOTDIR/.root/.packerenv" ] \
            && mount $MOUNT_FLAGS "$ROOTDIR/.root/.packerenv" \
                                  "$ROOTDIR/.root/$ROOTDIR"
        return
    fi

    if [ "$1" = "--unmount" ]; then
        Log "Running Unmount actions for \"$ROOTDIR/.root\""
        [ -d "/Applications" ]   && umount $UMOUNT_FLAGS "$ROOTDIR/.root/Applications"   2> /dev/null
        [ -d "/Mount" ]          && umount $UMOUNT_FLAGS "$ROOTDIR/.root/Mount"          2> /dev/null
        [ -d "/Packages" ]       && umount $UMOUNT_FLAGS "$ROOTDIR/.root/Packages"       2> /dev/null
        [ -d "/System" ]         && umount $UMOUNT_FLAGS "$ROOTDIR/.root/System"         2> /dev/null
        [ -d "/Users" ]          && umount $UMOUNT_FLAGS "$ROOTDIR/.root/Users"          2> /dev/null
        
        #===#===#===> Detach packerenv
        [ -d "$ROOTDIR/.root/.packerenv" ] \
            && umount $UMOUNT_FLAGS "$ROOTDIR/.root/$ROOTDIR" 2> /dev/null

        Validate_Umount "$ROOTDIR/.root/Applications"
        Validate_Umount "$ROOTDIR/.root/Mount"
        Validate_Umount "$ROOTDIR/.root/Packages"
        Validate_Umount "$ROOTDIR/.root/System"
        Validate_Umount "$ROOTDIR/.root/Users"
        Validate_Umount "$ROOTDIR/.root/$ROOTDIR"
        return
    fi

    Error "Run_Mounts: Unknown option \"$1\"" $ERR_INVALID_OPTION
}

#===#===#===#===# Delete the Root environment #===#===#===#===#
Delete_Root() {
    Warn_Prompt "Delete Packer root? (\"$ROOTDIR/.root\")"
    if [ ! "$?" = 0 ]; then
        Warn "Aborting."
        exit 0
    fi

    #===#===#===#===# WARNING: MAKE 100% SURE THE DIRECTORIES ARE UNMOUNTED
    #===#===#===#===# FIRST BEFORE DELETING ANYTHING!!!
    cd "$ROOTDIR/.root" || Error "Failed to CD into \"$ROOTDIR/.root\"" $ERR_EXTERNAL_FAILURE
    [ -d "Applications" ]   && umount -fl "Applications"   2> /dev/null
    [ -d "Mount" ]          && umount -fl "Mount"          2> /dev/null
    [ -d "Packages" ]       && umount -fl "Packages"       2> /dev/null
    [ -d "System" ]         && umount -fl "System"         2> /dev/null
    [ -d "Users" ]          && umount -fl "Users"          2> /dev/null
    [ -d "$ROOTDIR" ]       && umount $UMOUNT_FLAGS "$ROOTDIR/.root/$ROOTDIR"       2> /dev/null

    #===#===#===> Validate umounts have occured.
    # These directories should ALL be empty if unmounted.
    # If any file is found, this has failed!
    Run_Mounts --unmount

    #===#===#===> Perform the deletion.
    # FIXME: This seems VERY scary!
    rm -rf "$ROOTDIR/.root" \
        && Info "Deleted \"$ROOTDIR/.root\"" \
        || Error "Deletion of \"$ROOTDIR/.root\" failed. Something went terribly wrong." $ERR_EXTERNAL_FAILURE
    rm "$ROOTDIR/Configuration"
    rm "$ROOTDIR/Headers"
    rm "$ROOTDIR/Keys"
    rm "$ROOTDIR/Libraries"
    rm "$ROOTDIR/PackageData"
    rm "$ROOTDIR/Repositories"
}

#===#===#===#===# Build the Root environment #===#===#===#===#
DEFAULT_REPOS="http://dl-cdn.alpinelinux.org/alpine/latest-stable/main/ http://dl-cdn.alpinelinux.org/alpine/latest-stable/community/"
Build_Root() {
    #===#===#===> Create the Root directory
    Log "Building for \"$ROOTDIR\"..."
    MkSys 0755 "$ROOTDIR"
    MkSys 0755 "$ROOTDIR/.root"
    cd "$ROOTDIR/.root" || Error "Failed to CD into \"$ROOTDIR/.root\"" $ERR_EXTERNAL_FAILURE
    
    #===#===#===> Populate / (Packer root)
    # We are now in the Packer root.
    [ -d "/Applications" ] && MkSys 0755 "Applications"   # Orion
    [ -d "/Mount" ]        && MkSys 0755 "Mount"          # CoreSystem
    [ -d "/Packages" ]     && MkSys 0755 "Packages"       # CoreSystem
    # [ -d "/Packages" ]     && MkSys 0755 "Packages/Local" # CoreSystem
    [ -d "/System" ]       && MkSys 0755 "System"         # CoreSystem
    [ -d "/Users" ]        && MkSys 0755 "Users"          # CoreSystem
    #===#===#===> Populate internal Package Environment
    MkSys 0755 ".packerenv" # If you ever see this at / then you are in Packer!
    MkSys 0755 ".sysroot"   # Expose the REAL filesystem to Packer.
    MkSys 0755 ".rawenv"    # Expose the REAL Packer directory to the env.
    MkSys 0755 ".packerenv/.root/etc/"
    MkSys 0755 ".packerenv/.root/etc/apk/keys"
    MkSys 0755 ".packerenv/.root/bin/"
    MkSys 0755 ".packerenv/.root/sbin/"
    MkSys 0755 ".packerenv/.root/lib/"
    MkSys 0755 ".packerenv/.root/lib32/"
    MkSys 0755 ".packerenv/.root/lib64/"
    MkSys 0755 ".packerenv/.root/usr/"
    MkSys 0755 ".packerenv/.root/usr/include"
    MkSys 0755 ".packerenv/.root/usr/share"
    MkSys 0755 ".packerenv/.root/usr/bin"
    MkSys 0755 ".packerenv/.root/usr/sbin"
    MkSys 0755 ".packerenv/.root/usr/lib"
    MkSys 0755 ".packerenv/.root/usr/lib32"
    MkSys 0755 ".packerenv/.root/usr/lib64"
    MkSys 0755 ".packerenv/.root/usr/libexec"
    MkLnk "../lib32"   ".packerenv/.root/lib/32Bit"
    MkLnk "../lib64"   ".packerenv/.root/lib/64Bit"
    MkLnk "../lib32"   ".packerenv/.root/usr/lib/32Bit"
    MkLnk "../lib64"   ".packerenv/.root/usr/lib/64Bit"
    MkLnk "../../lib"  ".packerenv/.root/usr/lib/Core"
    MkLnk "../libexec" ".packerenv/.root/usr/lib/Exec"
    MkLnk "/System/Libraries/sudo" ".packerenv/.root/usr/lib/sudo" # Compat
    ### TODO: Add 'local' entries..
    #===#===#===> Populate exposable Packages directory.
    MkSys 0755                 ".packerenv/Binaries"
    MkLnk ".root/etc"          ".packerenv/Configuration"
    MkLnk ".root/usr/include"  ".packerenv/Headers"
    MkLnk ".root/usr/lib"      ".packerenv/Libraries"
    MkLnk ".root/usr/share"    ".packerenv/PackageData"
    MkLnk ".root/etc/apk/keys" ".packerenv/Keys"
    #===#===#===> Populate modified FHS in /
    # Populate top level / 
    MkLnk ".packerenv/.root/bin"         "bin"
    MkLnk "System/Kernel/BootInfo"       "boot"
    MkLnk "System/Kernel/DevicesInfo"    "dev"
    MkLnk ".packerenv/.root/etc"         "etc"
    MkLnk ".packerenv/.root/lib"         "lib"
    MkLnk ".packerenv/.root/lib32"       "lib32"
    MkLnk ".packerenv/.root/lib64"       "lib64"
    MkLnk "Mount/Drives"                 "media"
    MkLnk "Mount/Local"                  "mnt"
    # MkLnk "Packages/Local"               "opt"
    MkLnk "System/Kernel/ProcessInfo"    "proc"
    MkLnk "Users/.root"                  "root"
    MkLnk "System/Services/run"          "run"
    MkLnk ".packerenv/.root/sbin"        "sbin"
    MkLnk "System/Kernel/MachineInfo"    "sys"
    MkLnk "System/Temporary"             "tmp"
    MkLnk "System/Services"              "var"
    MkLnk ".packerenv/.root/usr"         "usr"

    #===#===#===> Dump Repositories
    for REPO in $DEFAULT_REPOS; do
        if [ $ANSI = true ]; then
            Info "Using Repository \"${FG_BLUE2}${TXT_UNDERLINE}${REPO}${OFF_UNDERLINE}${FG_WHITE}\""
        else
            Info "Using Repository \"$REPO\""
        fi
        echo "$REPO" >> ".packerenv/Repositories"
        ln -s "../../../Repositories" ".packerenv/.root/etc/apk/repositories"
    done

    # #===#===#===> Copy the CoreUtils
    cp "$DATA_DIR/apk.static"    ".packerenv/.root/apk" \
        || Error "Failed to copy apk.static to Packer Environment \"$ROOTDIR\"" $ERR_NO_PERMISSION
    cp "$DATA_DIR/CoreUtils.tar" "CoreUtils.tar" \
        || Error "Failed to copy CoreUtils to Packer Environment \"$ROOTDIR\"" $ERR_NO_PERMISSION

    #===#===#===> Install CoreUtils
    Info "Installing CoreUtils"
    tar -xf "CoreUtils.tar" && rm "CoreUtils.tar"
    ln -s "busybox.static" "bin/busybox"
    ln -s "busybox.static" "bin/sh"
    #===#===#===> Install Alpine Package Keeper
    Info "Installing Alpine Package Keeper. Sometimes this may take a while."
    Run_Mounts --mount # Remember this!
    

    [ $VERBOSE = true ]  \
        && _APK_FLAGS="" \
        || _APK_FLAGS="-q"
    
    chroot "." /.packerenv/.root/apk --initdb add $_APK_FLAGS
    # ranger .
    if [ ! "$?" = 0 ]; then
        Error "Failed to initialise Alpine Package Keeper service. Your installation will not work." $ERR_NONE
        Run_Mounts --unmount
        exit $ERR_EXTERNAL_FAILURE
    fi

    #===#===#===> Set up APK Keys
    Info "Setting up Keys"
    # MkLnk "../../Keys" "Packages/Configuration/apk/keys"
    # Cheap & dirty trick
    cp "/etc/resolv.conf" ".packerenv/Configuration" # Remove this later!
    chroot "." \
        /.packerenv/.root/apk -X "http://dl-cdn.alpinelinux.org/alpine/latest-stable/main/" \
        --allow-untrusted \
        add alpine-keys -q
    if [ ! "$?" = 0 ]; then
        Error "Failed to initialise Packer Keys. Your installation will not work." $ERR_NONE
        Run_Mounts --unmount
        exit $ERR_EXTERNAL_FAILURE
    fi

    rm ".packerenv/Configuration/resolv.conf"
    Run_Mounts --unmount # Safe!

    #===#===#===> Create the symlinks for /Packages
    cd "$ROOTDIR" || Error "Failed to CD into \"$ROOTDIR\"" $ERR_EXTERNAL_FAILURE

    MkSys 0755                             "Binaries"
    MkLnk ".root/.packerenv/Configuration" "Configuration"
    MkLnk ".root/.packerenv/Headers"       "Headers"
    MkLnk ".root/.packerenv/Keys"          "Keys"
    MkLnk ".root/.packerenv/Libraries"     "Libraries"
    MkLnk ".root/.packerenv/PackageData"   "PackageData"
    MkLnk ".root/.packerenv/Repositories"  "Repositories"
}

#===#===#===#===# Entry Point #===#===#===#===#
Main() {
    #===#===#===> Read Options
    Get_Options "$@"
    #===#===#===> Validate Options
    [ "$ROOTDIR" ] || SetupRoot_Usage $ERR_INVALID_OPTION
    ROOTDIR=$(realpath $ROOTDIR)
    
    # Compare against illegal directories
    [ "$ROOTDIR" ] || Error "The specified directory could not be resolved." $ERR_DIR_NOT_FOUND
    [ "$ROOTDIR" = "/" ] && Error "The specified directory cannot be the System root \"$ROOTDIR\"" $ERR_INVALID_OPTION
    [ "$ROOTDIR" = "$HOME" ] && Error "The specified directory cannot your Home folder \"$ROOTDIR\"" $ERR_INVALID_OPTION
    [ "$ROOTDIR" = "/System" ] && Error "The specified directory cannot your System folder \"$ROOTDIR\"" $ERR_INVALID_OPTION
    
    #===#===#===> Begin generating the Root environment
    # [ "$SUDO_USER" ] && export MK_USER="$SUDO_USER"
    [ -d "$ROOTDIR/.root" ]&& Delete_Root
    Build_Root

    Info_Good "Packer environment \"$ROOTDIR\" successfully created."
}

Main "$@"; exit $?
