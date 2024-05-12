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

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdbool.h>
#include <libgen.h>
#include <string.h>
#include <sys/mount.h>
#define _GNU_SOURCE
#include <sched.h>

//////////////// NOTE: /////////////////
/// This code should NEVER and will NEVER
/// be used in production. This is just being
/// made quickly so I can test out Packer.
////////////////////////////////////////


/// CONSTANTS:
////////////////////////////////////////
#define INTERNAL_PATH_MAX 2048

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
    exit(1);
}

/// PARSE:FILE:
////////////////////////////////////////
#define PARSE_OK               0
#define PARSE_CANT_OPEN        1
#define PARSE_NO_EMBEDDED_PATH 2
#define PARSE_OVERRUN          3
#define PARSE_CANT_NORMALISE   4
#define PARSE_CANT_CHDIR       5
#define PARSE_NO_PACKERENV     6

unsigned ParseFile(const char* FilePath, char* Output, unsigned OutputLen)
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

/// PARSE:PACKERENV:
////////////////////////////////////////
// unsigned ParsePackerEnv(char* FilePath, char* Output, unsigned OutputLen)
// {
//     //////////////// FIXME: ////////////////
//     /// This, is stupid. It works for now.
//     ////////////////////////////////////////
    
//     char* Dirname = dirname(FilePath);
//     if ( Dirname == 0 )
//         return PARSE_CANT_NORMALISE;

//     if ( chdir(Dirname) != 0 )
//         return PARSE_CANT_CHDIR;

//     if ( chdir("../.root") != 0 )
//         return PARSE_NO_PACKERENV;
    
//     if ( getcwd(Output, OutputLen) == 0 )
//         return PARSE_NO_PACKERENV;
    
//     return 0;
// };

/// PARSE:PACKERDIR:
////////////////////////////////////////
unsigned Parse_PackerDir(char* FilePath,
                         char* DirOut, 
                         char* EnvOut,
                         unsigned DirOutLen,
                         unsigned EnvOutLen)
{
    //////////////// FIXME: ////////////////
    /// This, is stupid. It works for now.
    ////////////////////////////////////////

    char* Dirname = dirname(FilePath);

    if ( Dirname == 0 )
        return PARSE_CANT_NORMALISE;

    if ( chdir(Dirname) != 0 )
        return PARSE_CANT_CHDIR;

    chdir("../");

    if ( getcwd(DirOut, DirOutLen) == 0 )
        return PARSE_NO_PACKERENV;

    snprintf(EnvOut, EnvOutLen, "%s/.root/.packerenv/", DirOut);

    return PARSE_OK;
}

/// RUNMOUNTS:
////////////////////////////////////////
void Run_Mounts(const char* PackerDir, const char* PackerEnv)
{
    unshare(CLONE_NEWNS);
    
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
    mount(PackerEnv,         (PackerDir + 1),   NULL, MS_BIND | MS_REC, OPTS);
    // Mount Raw Env
    mount(PackerDir,         ".rawenv/",        NULL, MS_BIND | MS_REC, OPTS);

}


/// MAIN:
////////////////////////////////////////

int main(int argc, const char** argv)
{
    /// Setup Commons
    ////////////////////////////////////////
    
    if ( argc < 2) // Fail if there is no passed binary.
        Usage(argv[0]);

    const char* InputPath = argv[1];
    char  InputCopy[INTERNAL_PATH_MAX];
    strncpy(InputCopy, InputPath, INTERNAL_PATH_MAX);
    
    /// Validate this is a SetUID Binary
    ////////////////////////////////////////

    if ( geteuid() != 0 ) {
        printf(" --- [X]: Cannot execute \"%s\" because the runner utility \"%s\" is not set as SetUID.\n", argv[1], argv[0]);
        printf("         Run \"chmod u+s\" on the runner utility to fix this issue.\n");
        exit(1);
    }

    /// Save UIDs
    ////////////////////////////////////////
    uid_t UID = getuid();
    if ( setuid(0) < 0) {
        printf(" --- [X]: Cannot setuid. Does the runner utility have the setuid bit set?\n");
        exit(1);
    }
    
    /// Parse File.
    ////////////////////////////////////////
    unsigned Result;
    char     PackerBinPath[INTERNAL_PATH_MAX];

    Result = ParseFile(InputPath, PackerBinPath, INTERNAL_PATH_MAX);
    
    switch ( Result ) {
        case PARSE_CANT_OPEN:
            printf(" --- [X]: Cannot execute \"%s\" because the file cannot be opened or does not exist.\n", InputPath);
            exit(1);
        break;
        case PARSE_NO_EMBEDDED_PATH:
            printf(" --- [X]: Cannot execute \"%s\" because the file is malformed and/or does not contain an embedded path.\n", InputPath);
            exit(1);
        break;
        case PARSE_OVERRUN:
            printf(" --- [X]: Cannot execute \"%s\" because the file is malformed and causes an internal failure.\n", InputPath);
        break;
    }

    /// Parse Packer root
    ////////////////////////////////////////
    char PackerDir[INTERNAL_PATH_MAX];
    char PackerEnv[INTERNAL_PATH_MAX];    
    char CWD[INTERNAL_PATH_MAX];

    if ( getcwd(CWD, INTERNAL_PATH_MAX) == 0 ) {
        printf(" --- [X]: Cannot get current working directory.\n");
        exit(1);
    }

    Result = Parse_PackerDir(InputCopy, PackerDir, PackerEnv, 
                             INTERNAL_PATH_MAX, INTERNAL_PATH_MAX);

    switch ( Result ) {
        case PARSE_CANT_NORMALISE:
            printf(" --- [X]: Cannot normalise \"%s\".\n", InputPath);
            exit(1);
        break;
        case PARSE_CANT_CHDIR:
            printf(" --- [X]: Cannot find internal directories. Is Packer setup correctly?\n");
            exit(1);
        break;
        case PARSE_NO_PACKERENV:
            printf(" --- [X]: No Packer environment was found. Is Packer setup correctly?\n");
            exit(1);
        break;
    }

    /// Setup mounts
    ////////////////////////////////////////
    chdir(PackerDir);
    chdir(".root/");
    Run_Mounts(PackerDir, PackerEnv);

    /// Switch to Packer Root
    ////////////////////////////////////////
    chroot(".");
    chdir("/");
    setuid(UID); // Dropped!
    chdir(CWD);  // Relative to chroot

    /// Run the program
    //////////////////////////////////////
    execv(PackerBinPath, (char**)(argv + 1));
    /// --- This should never be reached! --- ///
    printf(" --- [X]: The specified binary \"%s\" cannot be found within the Packer environment.\n", PackerBinPath);

    


}
