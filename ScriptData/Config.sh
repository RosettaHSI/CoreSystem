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

#===#===#===#===# This file configurations for Orion CoreSystem by Rosetta
#===#===#===> Do NOT modify this file to change OS-metadata! Instead,
#===#===#===> copy "DefConfig.sh" -> "Config.sh" and make your modifications
#===#===#===> from there. This file is for Rosetta HSI to setup CoreSystem with
#===#===#===> configurations standard to the Orion Operating System and
#===#===#===> its derivatives.

#===#===#===#===# OS Info #===#===#===#===#
#===#===#===> This will be used to generate the OSInfo file in /System/Static
#===#===#===> and the os-release file in /etc ( -> /System/Static/...)
export OS_ID="rosetta_orion"
export OS_NAME="Orion"
export OS_LOGO="rosetta-orion-logo"
export OS_VARIANT="CoreSystem"
export OS_VERSION_ID="0.1.0"
export OS_PRETTY_NAME="$OS_NAME $OS_VERSION_ID $OS_VARIANT"
export OS_VENDOR_NAME="Rosetta HSI"
export OS_VENDOR_URL="https://rosttahsi.com"
export OS_HOME_URL="https://rosttahsi.com/orion/"

#===#===#===#===# Build Configuration #===#===#===#===#

# --- What is the target architecture for this CoreSystem build?
# --> DEFAULT: "x86_64"
# --- Can be "x86_64", "aarch64"
export BUILD_ARCH="x86_64"

# --- Generate FHS-compliant symlinks for *NIX programs?
# --> DEFAULT: true
# --- If false, FHS links (bin, lib, usr) will NOT be established.
# --- For most systems, leave this true.
export BUILD_GEN_COMPAT_SYMLINKS=true

# --- What Script to run after the skeleton has been generated?
# ---> DEFAULT: "build.sh"
# --- Note that this is relative to 'BuildData' and it will then be
# --- the CWD. Leave blank if no build scripts are to be executed.
# ---> USAGE:
# --- This will send the absolute path to the Skeleton directory as the
# --- first argument to the build script. It will also be available through
# --- the environment variable $OS_ROOTFS
# --- The subsequent arguments will be the flags in BUILD_SCRIPT_OPTS
export BUILD_SCRIPT="build.sh"

# --- What options will be passed to 'BUILD_SCRIPT'
# ---> DEFAULT: ""
# --- Flags/Options are separated by spaces. Note that options with spaces
# --- included can not be escaped, meaning this is fairly limited.
export BUILD_SCRIPT_OPTS=""

# --- What directory within 'BuildData' will be used as the Merge directory?
# --> DEFAULT: "MergeData"
# --- After all the Build scripts have been ran, they should place any
# --- content intended to populate the RootFS into this directory.
# --- BuildMgr will then merge all of the files from here into the RootFS,
# --- overriding any present directories and files in the RootFS.
export BUILD_MERGE_DIR="MergeData"
