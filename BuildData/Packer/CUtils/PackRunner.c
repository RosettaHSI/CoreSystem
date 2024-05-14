///////////////////////////////////////////////////////////////////////////////
//                           Copyright (c) 2024                              //
//                         Rosetta H&S Integrated                            //
///////////////////////////////////////////////////////////////////////////////
//  Permission is hereby granted, free of charge, to any person obtaining    //
//        a copy of this software and associated documentation files         //
//  (the "Software"), to deal in the Software without restriction, including //
//     without limitation the right to use, copy, modify, merge, publish,    //
//     distribute, sublicense, and/or sell copies of the Software, and to    //
//         permit persons to whom the Software is furnished to do so,        //
//                     subject to the following conditions:                  //
///////////////////////////////////////////////////////////////////////////////
// The above copyright notice and this permission notice shall be included   //
//          in all copies or substantial portions of the Software.           //
///////////////////////////////////////////////////////////////////////////////
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS   //
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF                //
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.    //
// IN NO EVENT SHALL THE   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY    //
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT //
// OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR  //
// THE USE OR OTHER DEALINGS IN THE SOFTWARE.                                //
///////////////////////////////////////////////////////////////////////////////

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <limits.h>
#include <stdbool.h>
#include <libgen.h>
#include <string.h>
#include <sys/mount.h>
#include <sched.h>

/// CONSTANTS:
////////////////////////////////////////
#define INTERNAL_PATH_MAX 1024

/// USAGE:
////////////////////////////////////////
void Usage(const char* ExecName)
{
    const char* const ExecVersion="0.0.1";
    printf("\n");
    printf("%s v%s - Executable handler for Packer \n", ExecName, ExecVersion);
    printf("  Copyright 2024 - Rosetta HSI. This software comes with absolutely\n");
    printf("  NO WARRANTY and is released under the MIT License.\n");
    printf("\n");
    printf("  This utility handles running Packaged programs installed by Packer.\n");
    printf("\n");
    printf("  --- Usage: %s /Packages/Binaries/program_name\n", ExecName);
    printf("\n");
    printf("  --- Usage: %s -M /Packages /bin/sh\n", ExecName);
    printf("\n");
    exit(1);
}

/// SAFECHDIR:
////////////////////////////////////////
void Chdir_Or_Die(const char* Dir) {
    if ( chdir(Dir) == -1 ) {
        printf(" --- [PACKER]: Cannot change working directory to \"%s\".\n", Dir);
        perror(" --- [PERROR]: chdir() ");
        exit(1);
    }
}

/// RUN:MOUNTS:
////////////////////////////////////////
void Run_Mounts(const char* Packer_Path,
                const char* Packer_Root,
                const char* Packer_Env) {
    if ( unshare(CLONE_NEWNS) == -1 ) {
        printf(" --- [PACKER]: Failed to create new Mount namespace.\n");
        perror(" --- [PERROR]: unshare() : ");
        exit(1);
    }
    
    //////////////// NOTE: /////////////////
    /// It doesnt really matter if any of these fail,
    /// so don't check them.
    ////////////////////////////////////////
    const char* OPTS = "bind,x-gvfs-hide";
    mount("/Applications",   "Applications/",   NULL, MS_BIND | MS_REC, OPTS);
    mount("/Packages",       "Packages/",       NULL, MS_BIND | MS_REC, OPTS);
    mount("/Mount",          "Mount/",          NULL, MS_BIND | MS_REC, OPTS);
    mount("/System",         "System/",         NULL, MS_BIND | MS_REC, OPTS);
    mount("/Users",          "Users/",          NULL, MS_BIND | MS_REC, OPTS);
    mount("/",               ".sysroot/",       NULL, MS_BIND | MS_REC, OPTS);

    // Mount Env overlay
    // Adding +1 removes the leading /
    mount(Packer_Env,         (Packer_Path + 1),   NULL, MS_BIND | MS_REC, OPTS);
    // Mount Raw Env
    mount(Packer_Path,         ".rawenv/",        NULL, MS_BIND | MS_REC, OPTS);

}

/// RUN:PROGRAM:
////////////////////////////////////////
#define ERR_RUN_INVALID_BIN 20
unsigned Run_Program(uid_t UID,
                     const char*  Packer_Path,
                     const char*  Program_Path, 
                     const char** Program_Args)
{
/// Common Variables
    char Packer_Root[INTERNAL_PATH_MAX];
    char Packer_Env[INTERNAL_PATH_MAX];
    char WorkingDirectory[INTERNAL_PATH_MAX];
    int  Result;
/// Initialise Packer_Root
    Result = snprintf(Packer_Root, INTERNAL_PATH_MAX, "%s/.root", Packer_Path);
    if ( Result > INTERNAL_PATH_MAX ) {
        printf(" --- [PACKER]: Resolving Packer Directory \"%s\" internals exceeds (%u) INTERNAL_PATH_MAX (%u)\n",
                Packer_Path, Result, INTERNAL_PATH_MAX);
        perror(" --- [PERROR]: snprintf() ");
        exit(1);
    }
/// Initialise Packer_Env
    Result = snprintf(Packer_Env, INTERNAL_PATH_MAX, "%s/.root/.packerenv", Packer_Path);
    if ( Result > INTERNAL_PATH_MAX ) {
        printf(" --- [PACKER]: Resolving Packer Directory \"%s\" internals exceeds (%u) INTERNAL_PATH_MAX (%u)\n",
                Packer_Path, Result, INTERNAL_PATH_MAX);
        perror(" --- [PERROR]: snprintf() ");
        exit(1);
    }

/// Initialise CWD
    if ( getcwd(WorkingDirectory, INTERNAL_PATH_MAX) == 0 ) {
        printf(" --- [PACKER]: Cannot get current working directory.\n");
        perror(" --- [PERROR]: getcwd() ");
        exit(1);
    }

/// Run Mounts
    Chdir_Or_Die(Packer_Root);
    Run_Mounts(Packer_Path, Packer_Root, Packer_Env);
    Chdir_Or_Die(WorkingDirectory);
/// Change Root
    if ( chroot(Packer_Root) == -1 ) {
        printf(" --- [PACKER]: Failed to change root to \"%s\".\n", Packer_Root);
        perror(" --- [PERROR]: chroot() ");
        exit(1);
    }
    // Drop permissions
    if ( setuid(UID) == -1 ) {
        printf(" --- [PACKER]: Failed to change UID to \"%u\".\n", UID);
        perror(" --- [PERROR]: setuid() ");
        exit(1);
    }
    
    Chdir_Or_Die("/");              // Inside of Packer Root
    Chdir_Or_Die(WorkingDirectory); // Should now be relative to Packer Root
/// Run Executable
    execv(Program_Path, (char**)(Program_Args));
    /// --- This should never be reached! --- ///
    printf(" --- [PACKER]: The specified binary \"%s\" could not be executed within the Packer Environment.\n",
           Program_Path);
    perror(" --- [PERROR]: execv() ");
    exit(1);
    
}


/// PARSE:
////////////////////////////////////////

/// PARSE:FILE:
////////////////////////////////////////
#define PARSE_OK               0
#define PARSE_CANT_OPEN        1
#define PARSE_NO_EMBEDDED_PATH 2
#define PARSE_OVERRUN          3

unsigned Parse_File(const char* FilePath, char* Output, unsigned OutputLen)
{
    FILE* File = fopen(FilePath, "r");
    if ( File == NULL )
        return PARSE_CANT_OPEN;

    unsigned OutputIDX = 0;    
    bool CommentLine = false;
    while (1) {
        int c = fgetc(File);
        // EOF
        if ( c == EOF) // Should never hit this before a path. Malformed.
            return PARSE_NO_EMBEDDED_PATH;

        // Comment/Shebang line
        if (c == '#')
            CommentLine = true;
        
        if ( CommentLine ) {
            if ( c == '\n' )
                CommentLine = false;
        } else {
            // Prevent overflow
            if ( OutputIDX + 1 > OutputLen )
                return PARSE_OVERRUN; 
            
            // Newline
            Output[OutputIDX] = 0;
            if ( c == '\n' )
                if ( OutputIDX > 1 ) // If we have more than a single character
                    return PARSE_OK;
                else // Otherwise, there is no path, or it is malformed.
                    return PARSE_NO_EMBEDDED_PATH;
            else // Write byte
                Output[OutputIDX++] = c;
        }
    }

    return 0;
}



/// PARSE:MANUAL:
////////////////////////////////////////
unsigned Parse_Manual(uid_t UID,
                      const char*  Packer_Dir,
                      const char*  Packer_Bin,
                      const char** Bin_Args) 
{
    /// Variables
    ////////////////////////////////////////
    char Packer_RealPath[INTERNAL_PATH_MAX];
    int Result;
    
    // Validate Packer Directory
    if ( realpath(Packer_Dir, Packer_RealPath) == NULL ) {
        printf(" --- [PACKER]: Failed to resolve Packer Directory \"%s\".\n",
                Packer_Dir);
        perror(" --- [PERROR]: realpath() ");
        exit(1);
    }
    return Run_Program(UID, Packer_RealPath, Packer_Bin, Bin_Args);
}

/// PARSE:NORMAL:
////////////////////////////////////////
unsigned Parse_Normal(uid_t UID, 
                      const char*  FilePath,
                      const char** Program_Args) {
    /// Common Variables
    char     Temp[INTERNAL_PATH_MAX];
    char     Temp2[INTERNAL_PATH_MAX];
    char     Packer_Path[INTERNAL_PATH_MAX];
    char     Program_Path[INTERNAL_PATH_MAX];
    unsigned Result;

    /// Parse the File
    Result = Parse_File(FilePath, Program_Path, INTERNAL_PATH_MAX);
    switch ( Result ) {
        case PARSE_CANT_OPEN:
            printf(" --- [PACKER]: Failed to open Program Link \"%s\".\n", FilePath);
            perror(" --- [PERROR]: fopen ");
            exit(1);
        break;
        
        case PARSE_NO_EMBEDDED_PATH:
            printf(" --- [PACKER]: Program Link \"%s\" does not contain an embedded path.\n", FilePath);
            exit(1);
        break;

        case PARSE_OVERRUN:
            printf(" --- [PACKER]: Embedded path in Program Link \"%s\" exceeds INTERNAL_PATH_MAX (%u)\n",
                   FilePath, INTERNAL_PATH_MAX);
            exit(1);
        break;
    }
    /// Normalise FilePath
    if ( realpath(FilePath, Temp) == NULL ) {
        printf(" --- [PACKER]: Failed to resolve Program Link path \"%s\".\n",
                Temp);
        perror(" --- [PERROR]: realpath() ");
        exit(1);
    }
    if ( dirname(Temp) == NULL ) {
        printf(" --- [PACKER]: Failed to resolve Program Link dirname \"%s\".\n",
                Temp);
        perror(" --- [PERROR]: dirname() ");
        exit(1);
    }
    
    /// Retrieve Packer directory from FilePath (After dirname'd to Temp2)
    Result = snprintf(Temp2, INTERNAL_PATH_MAX, "%s/../", Temp);
    if ( Result > INTERNAL_PATH_MAX ) {
        printf(" --- [PACKER]: Attempting to retrieve Packer Directory from Program Link base directory \"%s\" internals exceeds (%u) INTERNAL_PATH_MAX (%u)\n",
                Temp, Result, INTERNAL_PATH_MAX);
        perror(" --- [PERROR]: snprintf() ");
        exit(1);
    }
    
    if ( realpath(Temp2, Packer_Path) == NULL ) {
        printf(" --- [PACKER]: Failed to resolve Packer Directory \"%s\".\n",
                Temp);
        perror(" --- [PERROR]: realpath() ");
        exit(1);
    }

    /// Run Program
    // printf("Packer Path: %s\nProgram Path: %s\n", Packer_Path, Program_Path);
    Run_Program(UID, Packer_Path, Program_Path, Program_Args);

    return 0;
}

/// ENTRY POINT
////////////////////////////////////////


/// MAIN:
////////////////////////////////////////
int main(int argc, const char** argv) {
/// Sanity Check
////////////////////////////////////////
    if ( argc < 2 )
        Usage(argv[0]);

    /// Validate this is a SetUID Binary
    if ( geteuid() != 0 ) {
        printf(" --- [PACKER]: Cannot execute \"%s\" because the runner utility \"%s\" is not set as SetUID.\n", argv[1], argv[0]);
        printf("               Run \"chmod u+s\" on the runner utility to fix this issue.\n");
        exit(1);
    }

    /// Save UIDs
    uid_t UID = getuid();
    if ( setuid(0) < 0) {
        printf(" --- [PACKER]: Cannot setuid. Does the runner utility have the setuid bit set?\n");
        perror(" --- [PERROR]: setuid() ");
        exit(1);
    }
    
/// If argc is 3 it means the 1st parameter is a path to the Packer
/// directory, and the 2nd parameter is a path to a binary to execute.
///////////////////////////////////////////////////////////////////////
    bool MANUAL_EXECUTION = false;
    unsigned Error;
    if ( argv[1][0] == '-' && argv[1][1] == 'M' )
        MANUAL_EXECUTION = true;

/// Run Program
    if ( MANUAL_EXECUTION )
        Error = Parse_Manual(UID, argv[2], argv[3], argv + 3);
    else
        Error = Parse_Normal(UID, argv[1], argv + 1);

/// UNREACHABLE ///
    return 1;
}