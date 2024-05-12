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

    if [ "$1" = "--mount" ]; then
        Log "Running Mount actions for \"$ROOTDIR/.root\""
        [ -d "/Applications" ]   && mount $MOUNT_FLAGS "/Applications" "$ROOTDIR/.root/Applications"
        [ -d "/Mount" ]          && mount $MOUNT_FLAGS "/Mount" "$ROOTDIR/.root/Mount"
        [ -d "/Packages/Local" ] && mount $MOUNT_FLAGS "/Packages/Local" "$ROOTDIR/.root/Packages/Local"
        [ -d "/System" ]         && mount $MOUNT_FLAGS "/System" "$ROOTDIR/.root/System"
        [ -d "/Users" ]          && mount $MOUNT_FLAGS "/Users" "$ROOTDIR/.root/Users"
        return
    fi

    if [ "$1" = "--unmount" ]; then
        Log "Running Unmount actions for \"$ROOTDIR/.root\""
        [ -d "/Applications" ]   && umount $UMOUNT_FLAGS "$ROOTDIR/.root/Applications"   2> /dev/null
        [ -d "/Mount" ]          && umount $UMOUNT_FLAGS "$ROOTDIR/.root/Mount"          2> /dev/null
        [ -d "/Packages/Local" ] && umount $UMOUNT_FLAGS "$ROOTDIR/.root/Packages/Local" 2> /dev/null
        [ -d "/System" ]         && umount $UMOUNT_FLAGS "$ROOTDIR/.root/System"         2> /dev/null
        [ -d "/Users" ]          && umount $UMOUNT_FLAGS "$ROOTDIR/.root/Users"          2> /dev/null

        Validate_Umount "$ROOTDIR/.root/Applications"
        Validate_Umount "$ROOTDIR/.root/Mount"
        Validate_Umount "$ROOTDIR/.root/Packages/Local"
        Validate_Umount "$ROOTDIR/.root/System"
        Validate_Umount "$ROOTDIR/.root/Users"
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
    [ -d "Packages/Local" ] && umount -fl "Packages/Local" 2> /dev/null
    [ -d "System" ]         && umount -fl "System"         2> /dev/null
    [ -d "Users" ]          && umount -fl "Users"          2> /dev/null

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
    touch ".packerenv" # If you ever see this at / then you are in a packerenv!
    [ -d "/Applications" ] && MkSys 0755 "Applications"   # Orion
    [ -d "/Mount" ]        && MkSys 0755 "Mount"          # CoreSystem
    [ -d "/Packages" ]     && MkSys 0755 "Packages"       # CoreSystem
    [ -d "/Packages" ]     && MkSys 0755 "Packages/Local" # CoreSystem
    [ -d "/System" ]       && MkSys 0755 "System"         # CoreSystem
    [ -d "/Users" ]        && MkSys 0755 "Users"          # Orion
    #===#===#===> Populate internal /Packages
    MkSys 0755 "Packages/Binaries"
    MkSys 0755 "Packages/Configuration"
    MkSys 0755 "Packages/Headers"
    MkSys 0755 "Packages/Libraries"
    MkSys 0755 "Packages/Libraries/32Bit"
    MkSys 0755 "Packages/Libraries/64Bit"
    MkSys 0755 "Packages/Libraries/Core"
    MkSys 0755 "Packages/Libraries/Exec"
    MkSys 0755 "Packages/PackageData"
    MkSys 0755 "Packages/Keys"
    MkSys 0755 "Packages/.internalbin" # Keeps everything together
    MkSys 0755 "Packages/.internalbin/bin"
    # MkSys 0755 "Packages/.internalbin/sbin"
    MkSys 0755 "Packages/.internalbin/alt-bin"
    # MkSys 0755 "Packages/.internalbin/alt-sbin"
    #===#===#===> Populate modified FHS in /
    # Populate top level / 
    MkLnk "Packages/.internalbin/bin"  "bin"
    MkLnk "System/Kernel/BootInfo"     "boot"
    MkLnk "System/Kernel/DevicesInfo"  "dev"
    MkLnk "Packages/Configuration"     "etc"
    MkLnk "Packages/Libraries/Core"    "lib"
    MkLnk "Packages/Libraries/32Bit"   "lib32"
    MkLnk "Packages/Libraries/32Bit"   "lib64"
    MkLnk "Packages/Libraries/Exec"    "libexec"
    MkLnk "Mount/Drives"               "media"
    MkLnk "Mount/Local"                "mnt"
    MkLnk "Packages/Local"             "opt"
    MkLnk "System/Kernel/ProcessInfo"  "proc"
    MkLnk "System/Local/AdminHome"     "root"
    MkLnk "System/Services/run"        "run"
    MkLnk "Packages/.internalbin/bin"  "sbin"
    # MkLnk "Packages/.internalbin/sbin" "sbin"
    MkLnk "System/Kernel/MachineInfo"  "sys"
    MkLnk "System/Temporary"           "tmp"
    MkLnk "System/Services"            "var"
    # Populate /usr
    MkSys 0755 "usr"
    MkLnk "../Packages/.internalbin/alt-bin"  "usr/bin"
    MkLnk "../Packages/Headers"               "usr/include"
    MkLnk "../Packages/Libraries"             "usr/lib"
    MkLnk "../Packages/Libraries/32Bit"       "usr/lib32"
    MkLnk "../Packages/Libraries/32Bit"       "usr/lib64"
    MkLnk "../Packages/Libraries/Exec"        "usr/libexec"
    MkLnk "../Packages/.internalbin/alt-bin"  "usr/sbin"
    # MkLnk "../Packages/.internalbin/alt-sbin" "usr/sbin"
    MkLnk "../Packages/PackageData"           "usr/share"
    MkSys 0755 "usr/local"
    MkLnk "../../Packages/Local/Binaries"        "usr/local/bin"
    MkLnk "../../Packages/Local/Headers"         "usr/local/include"
    MkLnk "../../Packages/Local/Libraries"       "usr/local/lib"
    MkLnk "../../Packages/Local/Libraries/32Bit" "usr/local/lib32"
    MkLnk "../../Packages/Local/Libraries/32Bit" "usr/local/lib64"
    MkLnk "../../Packages/Local/Libraries/Exec"  "usr/local/libexec"
    MkLnk "../../Packages/Local/Binaries"        "usr/local/sbin"
    MkLnk "../../Packages/Local/PackageData"     "usr/local/share"

    #===#===#===> Dump Repositories
    for REPO in $DEFAULT_REPOS; do
        if [ $ANSI = true ]; then
            Info "Using Repository \"${FG_BLUE2}${TXT_UNDERLINE}${REPO}${OFF_UNDERLINE}${FG_WHITE}\""
        else
            Info "Using Repository \"$REPO\""
        fi
        echo "$REPO" >> "Packages/Repositories"
    done

    #===#===#===> Copy the CoreUtils
    cp "$DATA_DIR/apk.static"    ".apk"          || Error "Failed to copy apk.static to Packer root \"$ROOTDIR/.root/\"" $ERR_NO_PERMISSION
    cp "$DATA_DIR/CoreUtils.tar" "CoreUtils.tar" || Error "Failed to copy CoreUtils to Packer root \"$ROOTDIR/.root/\"" $ERR_NO_PERMISSION

    #===#===#===> Install CoreUtils
    Info "Installing CoreUtils"
    tar -xf "CoreUtils.tar" && rm "CoreUtils.tar"
    #===#===#===> Install Alpine Package Keeper
    Info "Installing Alpine Package Keeper"
    Run_Mounts --mount # Remember this!
    
    chroot "." /.apk --initdb add -q
    if [ ! "$?" = 0 ]; then
        Error "Failed to initialise Alpine Package Keeper service. Your installation will not work." $ERR_NONE
        Run_Mounts --unmount
        exit $ERR_EXTERNAL_FAILURE
    fi

    #===#===#===> Set up APK Keys
    Info "Setting up Keys"
    MkLnk "../../Keys" "Packages/Configuration/apk/keys"
    # Cheap & dirty trick
    cp "/etc/resolv.conf" "Packages/Configuration/" # Remove this later!
    chroot "." \
        /.apk -X "http://dl-cdn.alpinelinux.org/alpine/latest-stable/main/" \
        --allow-untrusted \
        add alpine-keys -q
    if [ ! "$?" = 0 ]; then
        Error "Failed to initialise Packer Keys. Your installation will not work." $ERR_NONE
        Run_Mounts --unmount
        exit $ERR_EXTERNAL_FAILURE
    fi

    Run_Mounts --unmount # Safe!

    #===#===#===> Create the symlinks for /Packages
    cd "$ROOTDIR" || Error "Failed to CD into \"$ROOTDIR\"" $ERR_EXTERNAL_FAILURE

    MkSys 0755                           "Binaries"
    MkLnk ".root/Packages/Configuration" "Configuration"
    MkLnk ".root/Packages/Headers"       "Headers"
    MkLnk ".root/Packages/Keys"          "Keys"
    MkLnk ".root/Packages/Libraries"     "Libraries"
    MkLnk ".root/Packages/PackageData"   "PackageData"
    MkLnk ".root/Packages/Repositories"  "Repositories"
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
    [ -d "$ROOTDIR/.root" ]&& Delete_Root
    Build_Root

    Info_Good "Packer environment \"$ROOTDIR\" successfully created."
}

Main "$@"; exit $?
