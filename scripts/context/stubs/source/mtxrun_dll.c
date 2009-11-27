/*

Copyright:

The originally 'runscript' program was written by in 2009 by
T.M.Trzeciak and is public domain. This derived mtxrun program
is an adapted version by Hans Hagen.

Comment:

In ConTeXt MkIV we have two core scripts: luatools.lua and
mtxrun.lua where the second one is used to launch other scripts.
Normally a user will use a call like:

mtxrun --script font --reload

Here mtxrun is a lua script. In order to avoid the usage of a cmd
file on windows this runner will start texlua directly. In TeXlive
a runner is added for each cmd file but we don't want that overhead
(and extra files). By using an exe we can call these scripts in
batch files without the need for using call.

We also don't want to use other runners, like those that use kpse
to locate the script as this is exactly what mtxrun itself is doing
already. Therefore the runscript program is adapted to a more direct
approach suitable for mtxrun.

Compilation:

with gcc (size optimized):

gcc -Os -s -shared -o mtxrun.dll mtxrun_dll.c
gcc -Os -s -o mtxrun.exe mtxrun_exe.c -L./ -lmtxrun

with tcc (ver. 0.9.24), extra small size

tcc -shared -o runscript.dll runscript_dll.c
tcc -o runscript.exe runscript_exe.c runscript.def

*/

#include <windows.h>
#include <stdio.h>

#define IS_WHITESPACE(c) ((c == ' ') || (c == '\t'))
#define MAX_CMD 32768
//~ #define DRYRUN

static char dirname [MAX_PATH];
static char basename[MAX_PATH];
static char progname[MAX_PATH];
static char cmdline [MAX_CMD];

__declspec(dllexport) int dllrunscript( int argc, char *argv[] ) {

    int i;

    static char path[MAX_PATH];

    // get file name of this executable and split it into parts

    DWORD nchars = GetModuleFileNameA(NULL, path, MAX_PATH);
    if ( !nchars || (nchars == MAX_PATH) ) {
        fprintf(stderr, "mtxrun: unable to determine a valid own name\n");
        return -1;
    }

    // file extension part

    i = strlen(path);

    while ( i && (path[i] != '.') && (path[i] != '\\') ) i--;

    strcpy(basename, path);

    if ( basename[i] == '.' ) basename[i] = '\0'; //remove file extension

    // file name part

    while ( i && (path[i] != '\\') ) i--;

    if ( path[i] != '\\' ) {
        fprintf(stderr, "mtxrun: the runner has no directory part in its name: %s\n", path);
        return -1;
    }

    strcpy(dirname, path);
    dirname[i+1] = '\0'; //remove file name, leave trailing backslash
    strcpy(progname, &basename[i+1]);

    // find program to execute

    if ( (strlen(basename)+100 >= MAX_PATH) ) {
        fprintf(stderr, "mtxrun: the runners path is too long: %s\n", path);
        return -1;
    }

    // check .lua

    strcpy(path, dirname);
    strcat(path, "mtxrun.lua");

    if ( GetFileAttributesA(path) != INVALID_FILE_ATTRIBUTES ) {
		goto PROGRAM_FOUND;
    } else {
		fprintf(stderr, "mtxrun: the mtxrun.lua file is not in the same path\n");
		return -1;
    }

PROGRAM_FOUND:

    strcpy(cmdline,"texlua.exe ");

    if ( ( strcmp(progname,"mtxrun") == 0 ) || ( strcmp(progname,"luatools") == 0 ) ) {
        strcat(cmdline, dirname);
        strcat(cmdline,progname);
        strcat(cmdline, ".lua");
    } else if ( ( strcmp(progname,"texmfstart") == 0 ) ) {
        strcat(cmdline, dirname);
        strcat(cmdline,"mtxrun.lua");
    } else {
        strcat(cmdline, dirname);
        strcat(cmdline, "mtxrun.lua --script ");
        strcat(cmdline,progname);
    }

    // get the command line for this process

    char *argstr;
    argstr = GetCommandLineA();
    if ( argstr == NULL ) {
        fprintf(stderr, "mtxrun: fetching the command line string fails\n");
        return -1;
    }

    // skip over argv[0] (it can contain embedded double quotes if launched from cmd.exe!)

    int argstrlen = strlen(argstr);
    int quoted = 0;
    for ( i = 0; ( i < argstrlen) && ( !IS_WHITESPACE(argstr[i]) || quoted ); i++ )

    if (argstr[i] == '"') quoted = !quoted;

    // while ( IS_WHITESPACE(argstr[i]) ) i++; // arguments leading whitespace

    argstr = &argstr[i];

    if ( strlen(cmdline) + strlen(argstr) >= MAX_CMD ) {
        fprintf(stderr, "mtxrun: the command line string is too long:\n%s%s\n", cmdline, argstr);
        return -1;
    }

    // pass through all the arguments

    strcat(cmdline, argstr);

#ifdef DRYRUN
    printf("progname    : %s\n", progname);
    printf("dirname     : %s\n", dirname);
    printf("arguments   : %s\n", &argstr[-i]);
    for (i = 0; i < argc; i++) {
        printf("argv[%d]     : %s\n", i, argv[i]);
    }
    printf("commandline : %s\n", cmdline);
    return;
#endif

    // create child process

    STARTUPINFOA si; // ANSI variant
    PROCESS_INFORMATION pi;
    ZeroMemory( &si, sizeof(si) );
    si.cb = sizeof(si);
	si.dwFlags = STARTF_USESTDHANDLES;// | STARTF_USESHOWWINDOW;

	//si.dwFlags = STARTF_USESHOWWINDOW;
	//si.wShowWindow = SW_HIDE ; // can be used to hide console window (requires STARTF_USESHOWWINDOW flag)

	si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
	si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
	si.hStdError = GetStdHandle(STD_ERROR_HANDLE);

    ZeroMemory( &pi, sizeof(pi) );
    if( !CreateProcessA(
        NULL,     // module name (uses command line if NULL)
        cmdline,  // command line
        NULL,     // process security attributes
        NULL,     // thread security attributes
        TRUE,     // handle inheritance
        0,        // creation flags, e.g. CREATE_NEW_CONSOLE, CREATE_NO_WINDOW, DETACHED_PROCESS
        NULL,     // pointer to environment block (uses parent if NULL)
        NULL,     // starting directory (uses parent if NULL)
        &si,      // STARTUPINFO structure
        &pi )     // PROCESS_INFORMATION structure
    ) {
        fprintf(stderr, "mtxrun: unable to create a process for: %s\n", cmdline);
        return -1;
    }
    CloseHandle( pi.hThread ); // thread handle is not needed
    DWORD ret = 0;
    if ( WaitForSingleObject( pi.hProcess, INFINITE ) == WAIT_OBJECT_0 ) {
        if ( !GetExitCodeProcess( pi.hProcess, &ret) ) {
            fprintf(stderr, "mtxrun: unable to fetch the exit code for process: %s\n", cmdline);
            return -1;
        }
    } else {
        fprintf(stderr, "mtxrun: the script has been terminated unexpectedly: %s\n", cmdline);
        return -1;
    }
    CloseHandle( pi.hProcess );

    return ret;

}
