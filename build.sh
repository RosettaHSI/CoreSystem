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

#===#===#===#===# This file controls building the Orion CoreSystem
#===#===#===> Note that CoreSystem is a minimal operating system that
#===#===#===> provides little functionality for an end user.
#===#===#===> Orion CoreSystem is intended to be used as the basis or
#===#===#===> framework for another operating system utilising Rosetta tooling.

#===#===#===#===# Global Constants #===#===#===#===#
readonly EXEC_NAME="${0##*/}"
readonly EXEC_DIR=$(dirname $(realpath $0))
readonly EXEC_VER="0.0.1"

#===#===#===#===# Global Variables #===#===#===#===#
ANSI=true
VERBOSE=false
AUTOYES=false
SKELETON_ONLY=false
ROOTDIR=

#===#===#===#===# Usage #===#===#===#===#
Build_Usage() {
    echo ""
    echo "$EXEC_NAME v$EXEC_VER - Rosetta Utility for building Orion CoreSystem."
    echo "  Copyright 2024 - Rosetta HSI. This software comes with absolutely"
    echo "  NO WARRANTY and is released under the MIT License."
    echo ""
    echo "  --- Usage: $EXEC_NAME -o <Output> [options...]"
    echo ""
    echo "  --- Flags:"
    echo "    -h : Display this Help message."
    echo ""
    echo "    -o : The path to the RootFS Output directory. This is where the RootFS will"
    echo "         be placed and initialised."
    echo ""
    echo "    -s : Only generate the CoreSystem skeleton; do not populate."
    echo ""
    echo "    -Y : Automatically answers \"y\" to all prompts. DANGEROUS!"
    echo ""
    echo "    -v : Enable verbose logging."
    echo ""
    echo "    -@ : No ANSI escape sequences for color or prompts."
    echo ""

    exit $1
}

#===#===#===#===# Retrieve Options #===#===#===#===#
Get_Options() {
    while getopts @hvYo:r: flag
    do
        case "${flag}" in
            @) ANSI=false;;
            h) Build_Usage 0;;
            v) VERBOSE=true;;
            Y) AUTOYES=true;;
            o) ROOTDIR="${OPTARG}";;
            s) SKELETON_ONLY=true;;
            *) Build_Usage $ERR_INVALID_OPTION;;
        esac
    done
}

#===#===#===#===# Source Rosetta & 3rd-Party Configurations #===#===#===#===#
Source_Configs() {
    #===#===#===> Source Common Utilities
    cd "$EXEC_DIR"
    if [ ! -e "ScriptData/Common.sh" ]; then
        echo " --- [X]: Script resources could not be loaded. Install is either
          malformed, or it failed to switch to the correct directory."
        exit 200
    fi
    . "ScriptData/Common.sh"
    Log "Loaded Common Utils \"ScriptData/Common.sh\""
    
    #===#===#===> Source Rosetta/Vendor Configurations
    [ -e "ScriptData/Config.sh" ] || \
        Error "Failed to load \"ScriptData/Config.sh\". Malformed install" $ERR_FILE_NOT_FOUND
    . "ScriptData/Config.sh"
    Log "Loaded Vendor Config \"ScriptData/Config.sh\""

    #===#===#===> Source Make_Skeleton
    [ -e "ScriptData/Skeleton.sh" ] || \
        Error "Failed to load \"ScriptData/Skeleton.sh\". Malformed install" $ERR_FILE_NOT_FOUND
    . "ScriptData/Skeleton.sh"
    Log "Loaded Skeleton Script \"ScriptData/Skeleton.sh\""

    #===#===#===> Source Populate_CoreSystem
    [ -e "ScriptData/BuildMgr.sh" ] || \
        Error "Failed to load \"ScriptData/BuildMgr.sh\". Malformed install" $ERR_FILE_NOT_FOUND
    . "ScriptData/BuildMgr.sh"
    Log "Loaded Build Manager Script \"ScriptData/BuildMgr.sh\""
}

#===#===#===#===# Entry Point #===#===#===#===#

Main() {
    #===#===#===> Load Options
    Get_Options "$@"
    #===#===#===> Load ScriptData
    Source_Configs
    #===#===#===> Check Options
    [ ! "$ROOTDIR" ] && Build_Usage $ERR_NONE

    # Are we Root?
    if [ "$(id -u )" -ne 0 ]; then
        Error "This script needs to be run as Root." $ERR_NO_PERMISSION
    fi
    
    # Does it already exist?
    if [ -e "$ROOTDIR" ]; then
        # Is it a Directory?
        if [ -d "$ROOTDIR" ]; then
            Warn_Prompt "Specified Output path \"$ROOTDIR\" already exists. Override?"
            if [ "$?" = 0 ]; then
                rm -rf "$ROOTDIR" \
                    && Info "Deleted \"$ROOTDIR\"" \
                    || Error "Deletion of \"$ROOTDIR\" failed. Something went terribly wrong." $ERR_EXTERNAL_FAILURE
            else
                Warn "Aborting."
                exit 0
            fi
            
        else
            Error "Specified Output path \"$ROOTDIR\" is being used by a FILE, whereas only DIRs are permitted.
           Specify new path, or delete the FILE." $ERR_INVALID_OPTION
        fi
    fi

    #===#===#===> Make Skeleton
    RETURN_DIR="$PWD"
    Make_Skeleton "$ROOTDIR"
    Info_Good "Finished generating Skeleton at \"$ROOTDIR\""

    #===#===#===> Run Build scripts
    RETURN_DIR="$PWD"
    if [ $SKELETON_ONLY = true ]; then
        Info "SKELETON_ONLY = true"
    else
        export OS_ROOTFS=$(realpath "$ROOTDIR")
        [ "$OS_ROOTFS" ] || \
            Error "Failed to resolve \"$ROOTDIR\"." $ERR_DIR_NOT_FOUND

        cd "BuildData" || \
            Error "Failed to CD into \"BuildData\". Malformed install" $ERR_DIR_NOT_FOUND
        
        Run_BuildScripts "$BUILD_SCRIPT"
    fi

    return 0
}

Main "$@"; exit $?
