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

#===#===#===#===# This file handles building the Skeleton for Orion CoreSystem

#===#===#===#===# Utilities #===#===#===#===#
MkSys() {
    install -m $1 -o root -g root -d "$2" \
        && Log "Generated \"$2\"" \
        || Error "Failed to generate directory \"$2\"" $ERR_NO_PERMISSION
}

MkLnk() {
    ln -s "$1" "$2" \
        && Log "Generated Link \"$2\" -> \"$1\"" \
        || Error "Failed to generate link \"$2\" -> \"$1\"" $ERR_EXTERNAL_FAILURE
}

#===#===#===#===# Entry #===#===#===#===#
Make_Skeleton() {
    #===#===#===> Make the RootFS Directory, and cd into it
    ROOT=$1
    mkdir -p "$ROOT" || Error "Failed to mkdir \"$ROOTDIR\"" $ERR_EXTERNAL_FAILURE
    Info "Created \"$ROOT\" as RootFS"
    ROOT=$(realpath "$1")
    cd "$ROOT" || Error "Failed to cd into \"$ROOTDIR\"" $ERR_EXTERNAL_FAILURE
    
    #===#===#===> Populate /
    MkSys 0755 "Mount"
    MkSys 0755 "Mount/Drives"
    MkSys 0755 "Mount/Local"
    MkSys 0755 "System"
    
    #===#===#===> Populate /System
    MkSys 0755 "System/Configuration"
    
    MkSys 0755 "System/Kernel"
    MkSys 0755 "System/Kernel/BootInfo"
    MkSys 0755 "System/Kernel/DevicesInfo"
    MkSys 0755 "System/Kernel/MachineInfo"
    MkSys 0755 "System/Kernel/Modules"
    MkSys 0755 "System/Kernel/ProcessInfo"
    
    MkSys 0755 "System/Local"           # FIXME: Get rid of these two.
    MkSys 0755 "System/Local/AdminHome" # FIXME: Get rid of these two.

    MkSys 0755 "System/Protected/"
    MkSys 0755 "System/Protected/Binaries"
    MkSys 0755 "System/Protected/Headers"
    MkSys 0755 "System/Protected/Libraries"
    MkSys 0755 "System/Protected/Libraries/32Bit"
    MkSys 0755 "System/Protected/Libraries/64Bit"
    MkSys 0755 "System/Protected/Libraries/Exec"
    MkSys 0755 "System/Protected/PackageData"
    MkSys 0755 "System/Protected/Static"

    MkSys 0755 "System/Services"
    MkSys 0755 "System/Services/run"
    
    MkSys 1777 "System/Temporary"
    #===#===#===> Populate /System (Symlinks)
    MkLnk "Protected/Binaries"    "System/"
    MkLnk "Protected/Headers"     "System/"
    MkLnk "Protected/Libraries"   "System/"
    MkLnk "Protected/PackageData" "System/"
    MkLnk "Protected/Static"      "System/"
    MkLnk "../../Kernel/Modules"  "System/Protected/Libraries/modules"

    #===#===#===> Populate /Packages (Some items...)
    MkSys 0755 "Packages/"
    MkSys 0755 "Packages/Local"
    MkSys 0755 "Packages/Local/Binaries"
    MkSys 0755 "Packages/Local/Headers"
    MkSys 0755 "Packages/Local/Libraries"
    MkSys 0755 "Packages/Local/Libraries/32Bit"
    MkSys 0755 "Packages/Local/Libraries/64Bit"
    MkSys 0755 "Packages/Local/Libraries/Core"
    MkSys 0755 "Packages/Local/Libraries/Exec"
    MkSys 0755 "Packages/Local/PackageData"

    #===#===#===> Generate Compatibility Directories & Links
    if [ $BUILD_GEN_COMPAT_SYMLINKS = true ]; then
        Info "BUILD_GEN_COMPAT_SYMLINKS = true"
        # Populate top level / 
        MkLnk "System/Binaries"           "bin"
        MkLnk "System/Kernel/BootInfo"    "boot"
        MkLnk "System/Kernel/DevicesInfo" "dev"
        MkLnk "System/Configuration"      "etc"
        # MkLnk "System/Libraries/Core"     "lib"
        MkLnk "System/Libraries"          "lib"
        MkLnk "System/Libraries/32Bit"    "lib32"
        MkLnk "System/Libraries/32Bit"    "lib64"
        MkLnk "System/Libraries/Exec"     "libexec"
        MkLnk "Mount/Drives"              "media"
        MkLnk "Mount/Local"               "mnt"
        MkLnk "Packages/Local"            "opt"
        MkLnk "System/Kernel/ProcessInfo" "proc"
        MkLnk "System/Local/AdminHome"    "root"
        MkLnk "System/Services/run"       "run"
        MkLnk "System/Binaries"           "sbin"
        MkLnk "System/Kernel/MachineInfo" "sys"
        MkLnk "System/Temporary"          "tmp"
        MkLnk "System/Services"           "var"

        # Populate /usr
        MkSys 0755 "usr"
        MkLnk "../System/Binaries"        "usr/bin"
        MkLnk "../System/Headers"         "usr/include"
        MkLnk "../System/Libraries"       "usr/lib"
        MkLnk "../System/Libraries/32Bit" "usr/lib32"
        MkLnk "../System/Libraries/32Bit" "usr/lib64"
        MkLnk "../System/Libraries/Exec"  "usr/libexec"
        MkLnk "../System/Binaries"        "usr/sbin"
        MkLnk "../System/PackageData"     "usr/share"
        MkSys 0755 "usr/local"
        MkLnk "../../Packages/Local/Binaries"        "usr/local/bin"
        MkLnk "../../Packages/Local/include"         "usr/local/include"
        MkLnk "../../Packages/Local/Libraries"       "usr/local/lib"
        MkLnk "../../Packages/Local/Libraries/32Bit" "usr/local/lib32"
        MkLnk "../../Packages/Local/Libraries/32Bit" "usr/local/lib64"
        MkLnk "../../Packages/Local/Libraries/Exec"  "usr/local/libexec"
        MkLnk "../../Packages/Local/Binaries"        "usr/local/sbin"
        MkLnk "../../Packages/Local/PackageData"     "usr/local/share"
    fi

    #===#===#===> Cleanup
    cd $RETURN_DIR || \
        Error "Failed to return to Return Directory \"$RETURN_DIR\"" $ERR_NO_PERMISSION
    return 0
}