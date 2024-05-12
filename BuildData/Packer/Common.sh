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

_PKG_COMMON_LOADED=true
#===#===#===#===# This file contains common shared utilities #===#===#===#===# 
#===#===#===> From ANSI Sequences, to logging and file management utilities.


#===#===#===#===# ANSI Sequences #===#===#===#===#
#===#===#===> COMMANDS
export CMD_CLS="\033[2J\033[H"
export CMD_BELL="\007"
#===#===#===> TEXT EFFECTS
export TXT_RESET="\033[0m"
export TXT_BOLD="\033[1m"
export OFF_BOLD="\033[21m"
export TXT_DIM="\033[2m"
export OFF_DIM="\033[22m"
export TXT_ITALIC="\033[3m"
export OFF_ITALIC="\033[23m"
export TXT_UNDERLINE="\033[4m"
export OFF_UNDERLINE="\033[24m"
#===#===#===> COLORS
export TXT_CROSS="\033[9m"
export FG_BLACK="\033[30m"
export FG_RED="\033[31m"
export FG_GREEN="\033[32m"
export FG_YELLOW="\033[33m"
export FG_BLUE="\033[34m"
export FG_MAGENTA="\033[35m"
export FG_CYAN="\033[36m"
export FG_WHITE="\033[37m"
export FG_GREY="\033[90m"
export FG_RED2="\033[91m"
export FG_GREEN2="\033[92m"
export FG_YELLOW2="\033[93m"
export FG_BLUE2="\033[94m"
export FG_MAGENTA2="\033[95m"
export FG_CYAN2="\033[96m"
export FG_WHITE2="\033[97m"
#===#===#===> BACKING
export BG_BLACK="\033[40m"
export BG_RED="\033[41m"
export BG_GREEN="\033[42m"
export BG_YELLOW="\033[43m"
export BG_BLUE="\033[44m"
export BG_MAGENTA="\033[45m"
export BG_CYAN="\033[46m"
export BG_WHITE="\033[47m"
export BG_GREY="\033[100m"
export BG_RED2="\033[101m"
export BG_GREEN2="\033[102m"
export BG_YELLOW2="\033[103m"
export BG_BLUE2="\033[104m"
export BG_MAGENTA2="\033[105m"
export BG_CYAN2="\033[106m"
export BG_WHITE2="\033[107m"

#===#===#===#===# ERRORS #===#===#===#===#
export ERR_NONE=0
export ERR_EXTERNAL_FAILURE=100
export ERR_INVALID_OPTION=101
export ERR_UNSUPPORTED=102
export ERR_NO_PERMISSION=103

export ERR_FILE_NOT_FOUND=200
export ERR_DIR_NOT_FOUND=201

#===#===#===#===# Common Variables #===#===#===#===#
EXEC_VER="0.0.1"
# ANSI=true
# VERBOSE=false

#===#===#===#===# Generation Functions #===#===#===#===#
MK_USER="root"
MkSys() {
    if [ $ANSI = true ]; then
        install -m $1 -o $MK_USER -g $MK_USER -d "$2" \
            && Log "Generated \"${TXT_UNDERLINE}${FG_YELLOW2}$2${OFF_UNDERLINE}${TXT_RESET}\"" \
            || Error "Failed to generate directory \"$2\"" $ERR_NO_PERMISSION
    else
        install -m $1 -o $MK_USER -g $MK_USER -d "$2" \
            && Log "Generated \"$2\"" \
            || Error "Failed to generate directory \"$2\"" $ERR_NO_PERMISSION
    fi
}

MkLnk() {
    if [ $ANSI = true ]; then
        ln -s "$1" "$2" \
            && Log "Generated Link \"${TXT_UNDERLINE}${FG_YELLOW2}$2${TXT_OFFSET}${TXT_RESET}\" -> \"${TXT_UNDERLINE}${FG_YELLOW2}$1${TXT_OFFSET}${TXT_RESET}\"" \
            || Error "Failed to generate link \"$2\" -> \"$1\"" $ERR_EXTERNAL_FAILURE
    else
        ln -s "$1" "$2" \
            && Log "Generated Link \"$2\" -> \"$1\"" \
            || Error "Failed to generate link \"$2\" -> \"$1\"" $ERR_EXTERNAL_FAILURE
    fi
}

#===#===#===#===# Logging Routines #===#===#===#===#

#===#===#===> For critical errors resulting in termination
Error() {
    [ $ANSI = true ] && printf "${BG_RED}${FG_WHITE2}"
    printf " --- [X]: "
    printf " $1 | (Error $2) --- "
    [ $ANSI = true ] && printf "${BG_BLACK}${FG_WHITE2}${TXT_RESET}\n" \
                     || printf "\n"
    
    [ $2 = $ERR_NONE ] || exit "$2"
}

#===#===#===> For warnings that won't kill the program
Warn() {
    [ $ANSI = true ] && printf "${BG_YELLOW}${FG_BLACK}"
    printf " --- <!>: "
    [ $ANSI = true ] && printf "${BG_BLACK}${FG_WHITE}${TXT_RESET}"
    printf " $1\n"
}

Warn_Prompt() {
    [ $ANSI = true ] && printf "${BG_YELLOW}${FG_BLACK}"
    printf " --- <!>: "
    [ $ANSI = true ] && printf "${BG_BLACK}${FG_WHITE}${TXT_RESET}"
    printf " $1"
    if [ $AUTOYES = true ]; then
        printf " | Auto Override.\n"
    else
        read -p " | [y\N]: " _ANSWER
        case $_ANSWER in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            *     ) return 1;;
        esac
    fi
    
}

#===#===#===> For verbose logging information. Only visible with -v
Log() {
    [ $VERBOSE = false ] && return
    
    [ $ANSI = true ] && printf "${FG_GREY}"
    printf " --- [.]: "
    [ $ANSI = true ] && printf "${BG_BLACK}${FG_WHITE}${TXT_RESET}"
    printf " $1\n"
}

#===#===#===> Neutral info to show to the user
Info() {
    [ $ANSI = true ] && printf "${FG_GREY}"
    printf " --- [*]: "
    [ $ANSI = true ] && printf "${BG_BLACK}${FG_WHITE}${TXT_RESET}"
    printf " $1\n"
}

#===#===#===> Indicate success
Info_Good() {
    [ $ANSI = true ] && printf "${BG_GREEN}${FG_BLACK}"
    printf " --- [+]: "
    [ $ANSI = true ] && printf "${BG_BLACK}${FG_WHITE}${TXT_RESET}"
    printf " $1\n"
}

#===#===#===> Prompt a text input
PROMPT_TEXT_RESULT=""
Prompt_Text() {
    [ $ANSI = true ] && printf "${FG_GREY}"
    printf " --- [?]: "
    [ $ANSI = true ] && printf "${BG_BLACK}${FG_WHITE}${TXT_RESET}"
    printf " $1" PROMPT_TEXT_RESULT
}

#===#===#===#===# Other Utilities #===#===#===#===#

#===#===#===> Elevate Privileges
Elevate() {
    [ $(id -u) = 0 ] && return
    
    [ $ANSI = false ] && FG_GREY="" && FG_BLUE2="" && TXT_BOLD="" && TXT_RESET=""
    PROMPT_A=$(Info "You may need administrator privileges to run this action.")
    PROMPT_B=$(echo -e "${FG_GREY} --- [?]:${TXT_RESET}  Enter the password for ${TXT_BOLD}${FG_BLUE}${USER}${TXT_RESET}: ")
    
    PROMPT=$(echo "$PROMPT_A"; echo "$PROMPT_B")
    APPLET=$1
    shift 1
    exec sudo -p "$PROMPT" -E -- "/System/Protected/Binaries/Rosetta/packer" "$APPLET" "$@"
}

#===#===#===> Validate a Packer environment
Validate_Environ() { 
    [ -d "$1" ]                  || return 1
    [ -d "$1/.root" ]            || return 1
    [ -d "$1/Binaries" ]         || return 1
    
    return 0
}