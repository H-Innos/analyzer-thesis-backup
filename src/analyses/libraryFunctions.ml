(** Tools for dealing with library functions. *)

open Batteries
open GoblintCil
open GobConfig

module M = Messages

(** C standard library functions.
    These are specified by the C standard. *)
let c_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("memset", special [__ "dest" [w]; __ "ch" []; __ "count" []] @@ fun dest ch count -> Memset { dest; ch; count; });
    ("__builtin_memset", special [__ "dest" [w]; __ "ch" []; __ "count" []] @@ fun dest ch count -> Memset { dest; ch; count; });
    ("__builtin___memset_chk", special [__ "dest" [w]; __ "ch" []; __ "count" []; drop "os" []] @@ fun dest ch count -> Memset { dest; ch; count; });
    ("memcpy", special [__ "dest" [w]; __ "src" [r]; drop "n" []] @@ fun dest src -> Memcpy { dest; src });
    ("__builtin_memcpy", special [__ "dest" [w]; __ "src" [r]; drop "n" []] @@ fun dest src -> Memcpy { dest; src });
    ("__builtin___memcpy_chk", special [__ "dest" [w]; __ "src" [r]; drop "n" []; drop "os" []] @@ fun dest src -> Memcpy { dest; src });
    ("memmove", special [__ "dest" [w]; __ "src" [r]; drop "count" []] @@ fun dest src -> Memcpy { dest; src });
    ("__builtin_memmove", special [__ "dest" [w]; __ "src" [r]; drop "count" []] @@ fun dest src -> Memcpy { dest; src });
    ("__builtin___memmove_chk", special [__ "dest" [w]; __ "src" [r]; drop "count" []; drop "os" []] @@ fun dest src -> Memcpy { dest; src });
    ("strcpy", special [__ "dest" [w]; __ "src" [r]] @@ fun dest src -> Strcpy { dest; src; n = None; });
    ("__builtin_strcpy", special [__ "dest" [w]; __ "src" [r]] @@ fun dest src -> Strcpy { dest; src; n = None; });
    ("__builtin___strcpy_chk", special [__ "dest" [w]; __ "src" [r]; drop "os" []] @@ fun dest src -> Strcpy { dest; src; n = None; });
    ("strncpy", special [__ "dest" [w]; __ "src" [r]; __ "n" []] @@ fun dest src n -> Strcpy { dest; src; n = Some n; });
    ("__builtin_strncpy", special [__ "dest" [w]; __ "src" [r]; __ "n" []] @@ fun dest src n -> Strcpy { dest; src; n = Some n; });
    ("__builtin___strncpy_chk", special [__ "dest" [w]; __ "src" [r]; __ "n" []; drop "os" []] @@ fun dest src n -> Strcpy { dest; src; n = Some n; });
    ("strcat", special [__ "dest" [r; w]; __ "src" [r]] @@ fun dest src -> Strcat { dest; src; n = None; });
    ("__builtin_strcat", special [__ "dest" [r; w]; __ "src" [r]] @@ fun dest src -> Strcat { dest; src; n = None; });
    ("__builtin___strcat_chk", special [__ "dest" [r; w]; __ "src" [r]; drop "os" []] @@ fun dest src -> Strcat { dest; src; n = None; });
    ("strncat", special [__ "dest" [r; w]; __ "src" [r]; __ "n" []] @@ fun dest src n -> Strcat { dest; src; n = Some n; });
    ("__builtin_strncat", special [__ "dest" [r; w]; __ "src" [r]; __ "n" []] @@ fun dest src n -> Strcat { dest; src; n = Some n; });
    ("__builtin___strncat_chk", special [__ "dest" [r; w]; __ "src" [r]; __ "n" []; drop "os" []] @@ fun dest src n -> Strcat { dest; src; n = Some n; });
    ("asctime", unknown ~attrs:[ThreadUnsafe] [drop "time_ptr" [r_deep]]);
    ("fclose", unknown [drop "stream" [r_deep; w_deep; f_deep]]);
    ("feof", unknown [drop "stream" [r_deep; w_deep]]);
    ("ferror", unknown [drop "stream" [r_deep; w_deep]]);
    ("fflush", unknown [drop "stream" [r_deep; w_deep]]);
    ("fgetc", unknown [drop "stream" [r_deep; w_deep]]);
    ("getc", unknown [drop "stream" [r_deep; w_deep]]);
    ("fgets", unknown [drop "str" [w]; drop "count" []; drop "stream" [r_deep; w_deep]]);
    ("fopen", unknown [drop "pathname" [r]; drop "mode" [r]]);
    ("printf", unknown (drop "format" [r] :: VarArgs (drop' [r])));
    ("fprintf", unknown (drop "stream" [r_deep; w_deep] :: drop "format" [r] :: VarArgs (drop' [r])));
    ("sprintf", unknown (drop "buffer" [w] :: drop "format" [r] :: VarArgs (drop' [r])));
    ("snprintf", unknown (drop "buffer" [w] :: drop "bufsz" [] :: drop "format" [r] :: VarArgs (drop' [r])));
    ("fputc", unknown [drop "ch" []; drop "stream" [r_deep; w_deep]]);
    ("putc", unknown [drop "ch" []; drop "stream" [r_deep; w_deep]]);
    ("fputs", unknown [drop "str" [r]; drop "stream" [r_deep; w_deep]]);
    ("fread", unknown [drop "buffer" [w]; drop "size" []; drop "count" []; drop "stream" [r_deep; w_deep]]);
    ("fseek", unknown [drop "stream" [r_deep; w_deep]; drop "offset" []; drop "origin" []]);
    ("ftell", unknown [drop "stream" [r_deep]]);
    ("fwrite", unknown [drop "buffer" [r]; drop "size" []; drop "count" []; drop "stream" [r_deep; w_deep]]);
    ("rewind", unknown [drop "stream" [r_deep; w_deep]]);
    ("setvbuf", unknown [drop "stream" [r_deep; w_deep]; drop "buffer" [r; w]; drop "mode" []; drop "size" []]);
    (* TODO: if this is used to set an input buffer, the buffer (second argument) would need to remain TOP, *)
    (* as any future write (or flush) of the stream could result in a write to the buffer *)
    ("gmtime", unknown ~attrs:[ThreadUnsafe] [drop "timer" [r_deep]]);
    ("localeconv", unknown ~attrs:[ThreadUnsafe] []);
    ("localtime", unknown ~attrs:[ThreadUnsafe] [drop "time" [r]]);
    ("strlen", special [__ "s" [r]] @@ fun s -> Strlen s);
    ("strstr", special [__ "haystack" [r]; __ "needle" [r]] @@ fun haystack needle -> Strstr { haystack; needle; });
    ("strcmp", special [__ "s1" [r]; __ "s2" [r]] @@ fun s1 s2 -> Strcmp { s1; s2; n = None; });
    ("strtok", unknown ~attrs:[ThreadUnsafe] [drop "str" [r; w]; drop "delim" [r]]);
    ("__builtin_strcmp", special [__ "s1" [r]; __ "s2" [r]] @@ fun s1 s2 -> Strcmp { s1; s2; n = None; });
    ("strncmp", special [__ "s1" [r]; __ "s2" [r]; __ "n" []] @@ fun s1 s2 n -> Strcmp { s1; s2; n = Some n; });
    ("malloc", special [__ "size" []] @@ fun size -> Malloc size);
    ("realloc", special [__ "ptr" [r; f]; __ "size" []] @@ fun ptr size -> Realloc { ptr; size });
    ("free", special [__ "ptr" [f]] @@ fun ptr -> Free ptr);
    ("abort", special [] Abort);
    ("exit", special [drop "exit_code" []] Abort);
    ("ungetc", unknown [drop "c" []; drop "stream" [r; w]]);
    ("scanf", unknown ((drop "format" [r]) :: (VarArgs (drop' [w]))));
    ("fscanf", unknown ((drop "stream" [r_deep; w_deep]) :: (drop "format" [r]) :: (VarArgs (drop' [w]))));
    ("sscanf", unknown ((drop "buffer" [r]) :: (drop "format" [r]) :: (VarArgs (drop' [w]))));
    ("__freading", unknown [drop "stream" [r]]);
    ("mbsinit", unknown [drop "ps" [r]]);
    ("mbrtowc", unknown [drop "pwc" [w]; drop "s" [r]; drop "n" []; drop "ps" [r; w]]);
    ("iswspace", unknown [drop "wc" []]);
    ("iswalnum", unknown [drop "wc" []]);
    ("iswprint", unknown [drop "wc" []]);
    ("rename" , unknown [drop "oldpath" [r]; drop "newpath" [r];]);
    ("perror", unknown [drop "s" [r]]);
    ("getchar", unknown []);
    ("putchar", unknown [drop "ch" []]);
    ("puts", unknown [drop "s" [r]]);
    ("rand", unknown ~attrs:[ThreadUnsafe] []);
    ("strerror", unknown ~attrs:[ThreadUnsafe] [drop "errnum" []]);
    ("strspn", unknown [drop "s" [r]; drop "accept" [r]]);
    ("strcspn", unknown [drop "s" [r]; drop "accept" [r]]);
    ("strftime", unknown [drop "str" [w]; drop "count" []; drop "format" [r]; drop "tp" [r]]);
    ("strtod", unknown [drop "nptr" [r]; drop "endptr" [w]]);
    ("strtol", unknown [drop "nptr" [r]; drop "endptr" [w]; drop "base" []]);
    ("__strtol_internal", unknown [drop "nptr" [r]; drop "endptr" [w]; drop "base" []; drop "group" []]);
    ("strtoll", unknown [drop "nptr" [r]; drop "endptr" [w]; drop "base" []]);
    ("strtoul", unknown [drop "nptr" [r]; drop "endptr" [w]; drop "base" []]);
    ("strtoull", unknown [drop "nptr" [r]; drop "endptr" [w]; drop "base" []]);
    ("tolower", unknown [drop "ch" []]);
    ("toupper", unknown [drop "ch" []]);
    ("time", unknown [drop "arg" [w]]);
    ("tmpnam", unknown ~attrs:[ThreadUnsafe] [drop "filename" [w]]);
    ("vprintf", unknown [drop "format" [r]; drop "vlist" [r_deep]]); (* TODO: what to do with a va_list type? is r_deep correct? *)
    ("vfprintf", unknown [drop "stream" [r_deep; w_deep]; drop "format" [r]; drop "vlist" [r_deep]]); (* TODO: what to do with a va_list type? is r_deep correct? *)
    ("vsprintf", unknown [drop "buffer" [w]; drop "format" [r]; drop "vlist" [r_deep]]); (* TODO: what to do with a va_list type? is r_deep correct? *)
    ("mktime", unknown [drop "tm" [r;w]]);
    ("ctime", unknown ~attrs:[ThreadUnsafe] [drop "rm" [r]]);
    ("clearerr", unknown [drop "stream" [w]]);
    ("setbuf", unknown [drop "stream" [w]; drop "buf" [w]]);
    ("swprintf", unknown (drop "wcs" [w] :: drop "maxlen" [] :: drop "fmt" [r] :: VarArgs (drop' [r])));
    ("assert", special [__ "exp" []] @@ fun exp -> Assert { exp; check = true; refine = get_bool "sem.assert.refine" }); (* only used if assert is used without include, e.g. in transformed files *)
    ("difftime", unknown [drop "time1" []; drop "time2" []]);
    ("system", unknown ~attrs:[ThreadUnsafe] [drop "command" [r]]);
    ("wcscat", unknown [drop "dest" [r; w]; drop "src" [r]]);
    ("wcrtomb", unknown ~attrs:[ThreadUnsafe] [drop "s" [w]; drop "wc" []; drop "ps" [r_deep; w_deep]]);
    ("abs", unknown [drop "j" []]);
    ("localtime_r", unknown [drop "timep" [r]; drop "result" [w]]);
    ("strpbrk", unknown [drop "s" [r]; drop "accept" [r]]);
    ("_setjmp", special [__ "env" [w]] @@ fun env -> Setjmp { env }); (* only has one underscore *)
    ("setjmp", special [__ "env" [w]] @@ fun env -> Setjmp { env });
    ("longjmp", special [__ "env" [r]; __ "value" []] @@ fun env value -> Longjmp { env; value });
    ("rand", special [] Rand);
  ]

(** C POSIX library functions.
    These are {e not} specified by the C standard, but available on POSIX systems. *)
let posix_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("bzero", special [__ "dest" [w]; __ "count" []] @@ fun dest count -> Bzero { dest; count; });
    ("__builtin_bzero", special [__ "dest" [w]; __ "count" []] @@ fun dest count -> Bzero { dest; count; });
    ("explicit_bzero", special [__ "dest" [w]; __ "count" []] @@ fun dest count -> Bzero { dest; count; });
    ("__explicit_bzero_chk", special [__ "dest" [w]; __ "count" []; drop "os" []] @@ fun dest count -> Bzero { dest; count; });
    ("catgets", unknown ~attrs:[ThreadUnsafe] [drop "catalog" [r_deep]; drop "set_number" []; drop "message_number" []; drop "message" [r]]);
    ("crypt", unknown ~attrs:[ThreadUnsafe] [drop "key" [r]; drop "salt" [r]]);
    ("ctermid", unknown ~attrs:[ThreadUnsafe] [drop "s" [w]]);
    ("dbm_clearerr", unknown ~attrs:[ThreadUnsafe] [drop "db" [r_deep; w_deep]]);
    ("dbm_close", unknown ~attrs:[ThreadUnsafe] [drop "db" [r_deep; w_deep; f_deep]]);
    ("dbm_delete", unknown ~attrs:[ThreadUnsafe] [drop "db" [r_deep; w_deep]; drop "key" []]);
    ("dbm_error", unknown ~attrs:[ThreadUnsafe] [drop "db" [r_deep]]);
    ("dbm_fetch", unknown ~attrs:[ThreadUnsafe] [drop "db" [r_deep]; drop "key" []]);
    ("dbm_firstkey", unknown ~attrs:[ThreadUnsafe] [drop "db" [r_deep]]);
    ("dbm_nextkey", unknown ~attrs:[ThreadUnsafe] [drop "db" [r_deep]]);
    ("dbm_open", unknown ~attrs:[ThreadUnsafe] [drop "file" [r; w]; drop "open_flags" []; drop "file_mode" []]);
    ("dbm_store", unknown ~attrs:[ThreadUnsafe] [drop "db" [r_deep; w_deep]; drop "key" []; drop "content" []; drop "store_mode" []]);
    ("dlerror", unknown ~attrs:[ThreadUnsafe] []);
    ("drand48", unknown ~attrs:[ThreadUnsafe] []);
    ("encrypt", unknown ~attrs:[ThreadUnsafe] [drop "block" [r; w]; drop "edflag" []]);
    ("endgrent", unknown ~attrs:[ThreadUnsafe] []);
    ("endpwent", unknown ~attrs:[ThreadUnsafe] []);
    ("fcvt", unknown ~attrs:[ThreadUnsafe] [drop "number" []; drop "ndigits" []; drop "decpt" [w]; drop "sign" [w]]);
    ("gcvt", unknown ~attrs:[ThreadUnsafe] [drop "number" []; drop "ndigit" []; drop "buf" [w]]);
    ("getdate", unknown ~attrs:[ThreadUnsafe] [drop "string" [r]]);
    ("getenv", unknown ~attrs:[ThreadUnsafe] [drop "name" [r]]);
    ("getgrent", unknown ~attrs:[ThreadUnsafe] []);
    ("getgrgid", unknown ~attrs:[ThreadUnsafe] [drop "gid" []]);
    ("getgrnam", unknown ~attrs:[ThreadUnsafe] [drop "name" [r]]);
    ("getlogin", unknown ~attrs:[ThreadUnsafe] []);
    ("getnetbyaddr", unknown ~attrs:[ThreadUnsafe] [drop "net" []; drop "type" []]);
    ("getnetbyname", unknown ~attrs:[ThreadUnsafe] [drop "name" [r]]);
    ("getnetent", unknown ~attrs:[ThreadUnsafe] []);
    ("getprotobyname", unknown ~attrs:[ThreadUnsafe] [drop "name" [r]]);
    ("getprotobynumber", unknown ~attrs:[ThreadUnsafe] [drop "proto" []]);
    ("getprotoent", unknown ~attrs:[ThreadUnsafe] []);
    ("getpwent", unknown ~attrs:[ThreadUnsafe] []);
    ("getpwnam", unknown ~attrs:[ThreadUnsafe] [drop "name" [r]]);
    ("getpwuid", unknown ~attrs:[ThreadUnsafe] [drop "uid" []]);
    ("getservbyname", unknown ~attrs:[ThreadUnsafe] [drop "name" [r]; drop "proto" [r]]);
    ("getservbyport", unknown ~attrs:[ThreadUnsafe] [drop "port" []; drop "proto" [r]]);
    ("getservent", unknown ~attrs:[ThreadUnsafe] []);
    ("getutxent", unknown ~attrs:[ThreadUnsafe] []);
    ("getutxid", unknown ~attrs:[ThreadUnsafe] [drop "utmpx" [r_deep]]);
    ("getutxline", unknown ~attrs:[ThreadUnsafe] [drop "utmpx" [r_deep]]);
    ("pututxline", unknown ~attrs:[ThreadUnsafe] [drop "utmpx" [r_deep]]);
    ("hcreate", unknown ~attrs:[ThreadUnsafe] [drop "nel" []]);
    ("hdestroy", unknown ~attrs:[ThreadUnsafe] []);
    ("hsearch", unknown ~attrs:[ThreadUnsafe] [drop "item" [r_deep]; drop "action" [r_deep]]);
    ("l64a", unknown ~attrs:[ThreadUnsafe] [drop "value" []]);
    ("lrand48", unknown ~attrs:[ThreadUnsafe] []);
    ("mrand48", unknown ~attrs:[ThreadUnsafe] []);
    ("nl_langinfo", unknown ~attrs:[ThreadUnsafe] [drop "item" []]);
    ("nl_langinfo_l", unknown [drop "item" []; drop "locale" [r_deep]]);
    ("getc_unlocked", unknown ~attrs:[ThreadUnsafe] [drop "stream" [r_deep; w_deep]]);
    ("getchar_unlocked", unknown ~attrs:[ThreadUnsafe] []);
    ("ptsname", unknown ~attrs:[ThreadUnsafe] [drop "fd" []]);
    ("putc_unlocked", unknown ~attrs:[ThreadUnsafe] [drop "c" []; drop "stream" [r_deep; w_deep]]);
    ("putchar_unlocked", unknown ~attrs:[ThreadUnsafe] [drop "c" []]);
    ("putenv", unknown ~attrs:[ThreadUnsafe] [drop "string" [r; w]]);
    ("readdir", unknown ~attrs:[ThreadUnsafe] [drop "dirp" [r_deep]]);
    ("setenv", unknown ~attrs:[ThreadUnsafe] [drop "name" [r]; drop "name" [r]; drop "overwrite" []]);
    ("setgrent", unknown ~attrs:[ThreadUnsafe] []);
    ("setpwent", unknown ~attrs:[ThreadUnsafe] []);
    ("setutxent", unknown ~attrs:[ThreadUnsafe] []);
    ("strsignal", unknown ~attrs:[ThreadUnsafe] [drop "sig" []]);
    ("unsetenv", unknown ~attrs:[ThreadUnsafe] [drop "name" [r]]);
    ("lseek", unknown [drop "fd" []; drop "offset" []; drop "whence" []]);
    ("fcntl", unknown (drop "fd" [] :: drop "cmd" [] :: VarArgs (drop' [r; w])));
    ("fseeko", unknown [drop "stream" [r_deep; w_deep]; drop "offset" []; drop "whence" []]);
    ("fileno", unknown [drop "stream" [r_deep; w_deep]]);
    ("fdopen", unknown [drop "fd" []; drop "mode" [r]]);
    ("getopt", unknown ~attrs:[ThreadUnsafe] [drop "argc" []; drop "argv" [r_deep]; drop "optstring" [r]]);
    ("iconv_open", unknown [drop "tocode" [r]; drop "fromcode" [r]]);
    ("iconv", unknown [drop "cd" [r]; drop "inbuf" [r]; drop "inbytesleft" [r;w]; drop "outbuf" [w]; drop "outbytesleft" [r;w]]);
    ("iconv_close", unknown [drop "cd" [f]]);
    ("strnlen", unknown [drop "s" [r]; drop "maxlen" []]);
    ("chmod", unknown [drop "pathname" [r]; drop "mode" []]);
    ("fchmod", unknown [drop "fd" []; drop "mode" []]);
    ("fchown", unknown [drop "fd" []; drop "owner" []; drop "group" []]);
    ("lchown", unknown [drop "pathname" [r]; drop "owner" []; drop "group" []]);
    ("clock_gettime", unknown [drop "clockid" []; drop "tp" [w]]);
    ("gettimeofday", unknown [drop "tv" [w]; drop "tz" [w]]);
    ("futimens", unknown [drop "fd" []; drop "times" [r]]);
    ("utimes", unknown [drop "filename" [r]; drop "times" [r]]);
    ("utimensat", unknown [drop "dirfd" []; drop "pathname" [r]; drop "times" [r]; drop "flags" []]);
    ("linkat", unknown [drop "olddirfd" []; drop "oldpath" [r]; drop "newdirfd" []; drop "newpath" [r]; drop "flags" []]);
    ("dirfd", unknown [drop "dirp" [r]]);
    ("fdopendir", unknown [drop "fd" []]);
    ("pathconf", unknown [drop "path" [r]; drop "name" []]);
    ("symlink" , unknown [drop "oldpath" [r]; drop "newpath" [r];]);
    ("ftruncate", unknown [drop "fd" []; drop "length" []]);
    ("mkfifo", unknown [drop "pathname" [r]; drop "mode" []]);
    ("ntohs", unknown [drop "netshort" []]);
    ("alarm", unknown [drop "seconds" []]);
    ("pwrite", unknown [drop "fd" []; drop "buf" [r]; drop "count" []; drop "offset" []]);
    ("hstrerror", unknown [drop "err" []]);
    ("inet_ntoa", unknown ~attrs:[ThreadUnsafe] [drop "in" []]);
    ("getsockopt", unknown [drop "sockfd" []; drop "level" []; drop "optname" []; drop "optval" [w]; drop "optlen" [w]]);
    ("gethostbyaddr", unknown ~attrs:[ThreadUnsafe] [drop "addr" [r_deep]; drop "len" []; drop "type" []]);
    ("gethostbyaddr_r", unknown [drop "addr" [r_deep]; drop "len" []; drop "type" []; drop "ret" [w_deep]; drop "buf" [w]; drop "buflen" []; drop "result" [w]; drop "h_errnop" [w]]);
    ("gethostbyname", unknown ~attrs:[ThreadUnsafe] [drop "name" [r]]);
    ("sigaction", unknown [drop "signum" []; drop "act" [r_deep; s_deep]; drop "oldact" [w_deep]]);
    ("tcgetattr", unknown [drop "fd" []; drop "termios_p" [w_deep]]);
    ("tcsetattr", unknown [drop "fd" []; drop "optional_actions" []; drop "termios_p" [r_deep]]);
    ("access", unknown [drop "pathname" [r]; drop "mode" []]);
    ("ttyname", unknown ~attrs:[ThreadUnsafe] [drop "fd" []]);
    ("shm_open", unknown [drop "name" [r]; drop "oflag" []; drop "mode" []]);
    ("sched_get_priority_max", unknown [drop "policy" []]);
    ("mprotect", unknown [drop "addr" []; drop "len" []; drop "prot" []]);
    ("ftime", unknown [drop "tp" [w]]);
    ("timer_create", unknown [drop "clockid" []; drop "sevp" [r; w; s]; drop "timerid" [w]]);
    ("timer_settime", unknown [drop "timerid" []; drop "flags" []; drop "new_value" [r_deep]; drop "old_value" [w_deep]]);
    ("timer_gettime", unknown [drop "timerid" []; drop "curr_value" [w_deep]]);
    ("timer_getoverrun", unknown [drop "timerid" []]);
    ("lstat", unknown [drop "pathname" [r]; drop "statbuf" [w]]);
    ("getpwnam", unknown [drop "name" [r]]);
    ("chdir", unknown [drop "path" [r]]);
    ("closedir", unknown [drop "dirp" [r]]);
    ("mkdir", unknown [drop "pathname" [r]; drop "mode" []]);
    ("opendir", unknown [drop "name" [r]]);
    ("rmdir", unknown [drop "path" [r]]);
    ("open", unknown (drop "pathname" [r] :: drop "flags" [] :: VarArgs (drop "mode" [])));
    ("read", unknown [drop "fd" []; drop "buf" [w]; drop "count" []]);
    ("write", unknown [drop "fd" []; drop "buf" [r]; drop "count" []]);
    ("recv", unknown [drop "sockfd" []; drop "buf" [w]; drop "len" []; drop "flags" []]);
    ("send", unknown [drop "sockfd" []; drop "buf" [r]; drop "len" []; drop "flags" []]);
    ("strdup", unknown [drop "s" [r]]);
    ("strndup", unknown [drop "s" [r]; drop "n" []]);
    ("syscall", unknown (drop "number" [] :: VarArgs (drop' [r; w])));
    ("sysconf", unknown [drop "name" []]);
    ("syslog", unknown (drop "priority" [] :: drop "format" [r] :: VarArgs (drop' [r]))); (* TODO: is the VarArgs correct here? *)
    ("vsyslog", unknown [drop "priority" []; drop "format" [r]; drop "ap" [r_deep]]); (* TODO: what to do with a va_list type? is r_deep correct? *)
    ("freeaddrinfo", unknown [drop "res" [f_deep]]);
    ("getgid", unknown []);
    ("pselect", unknown [drop "nfds" []; drop "readdfs" [r]; drop "writedfs" [r]; drop "exceptfds" [r]; drop "timeout" [r]; drop "sigmask" [r]]);
    ("strncasecmp", unknown [drop "s1" [r]; drop "s2" [r]; drop "n" []]);
    ("getnameinfo", unknown [drop "addr" [r_deep]; drop "addrlen" []; drop "host" [w]; drop "hostlen" []; drop "serv" [w]; drop "servlen" []; drop "flags" []]);
    ("strtok_r", unknown [drop "str" [r; w]; drop "delim" [r]; drop "saveptr" [r_deep; w_deep]]); (* deep accesses through saveptr if str is NULL: https://github.com/lattera/glibc/blob/895ef79e04a953cac1493863bcae29ad85657ee1/string/strtok_r.c#L31-L40 *)
    ("kill", unknown [drop "pid" []; drop "sig" []]);
    ("closelog", unknown []);
    ("dirname", unknown ~attrs:[ThreadUnsafe] [drop "path" [r]]);
    ("basename", unknown ~attrs:[ThreadUnsafe] [drop "path" [r]]);
    ("setpgid", unknown [drop "pid" []; drop "pgid" []]);
    ("dup2", unknown [drop "oldfd" []; drop "newfd" []]);
    ("pclose", unknown [drop "stream" [w; f]]);
    ("getcwd", unknown [drop "buf" [w]; drop "size" []]);
    ("inet_pton", unknown [drop "af" []; drop "src" [r]; drop "dst" [w]]);
    ("inet_ntop", unknown [drop "af" []; drop "src" [r]; drop "dst" [w]; drop "size" []]);
    ("gethostent", unknown ~attrs:[ThreadUnsafe] []);
    ("poll", unknown [drop "fds" [r]; drop "nfds" []; drop "timeout" []]);
    ("semget", unknown [drop "key" []; drop "nsems" []; drop "semflg" []]);
    ("semctl", unknown (drop "semid" [] :: drop "semnum" [] :: drop "cmd" [] :: VarArgs (drop "semun" [r_deep])));
    ("semop", unknown [drop "semid" []; drop "sops" [r]; drop "nsops" []]);
    ("__sigsetjmp", special [__ "env" [w]; drop "savesigs" []] @@ fun env -> Setjmp { env }); (* has two underscores *)
    ("sigsetjmp", special [__ "env" [w]; drop "savesigs" []] @@ fun env -> Setjmp { env });
    ("siglongjmp", special [__ "env" [r]; __ "value" []] @@ fun env value -> Longjmp { env; value });
  ]

(** Pthread functions. *)
let pthread_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("pthread_create", special [__ "thread" [w]; drop "attr" [r]; __ "start_routine" [s]; __ "arg" []] @@ fun thread start_routine arg -> ThreadCreate { thread; start_routine; arg }); (* For precision purposes arg is not considered accessed here. Instead all accesses (if any) come from actually analyzing start_routine. *)
    ("pthread_exit", special [__ "retval" []] @@ fun retval -> ThreadExit { ret_val = retval }); (* Doesn't dereference the void* itself, but just passes to pthread_join. *)
    ("pthread_cond_init", unknown [drop "cond" [w]; drop "attr" [r]]);
    ("__pthread_cond_init", unknown [drop "cond" [w]; drop "attr" [r]]);
    ("pthread_cond_signal", special [__ "cond" []] @@ fun cond -> Signal cond);
    ("__pthread_cond_signal", special [__ "cond" []] @@ fun cond -> Signal cond);
    ("pthread_cond_broadcast", special [__ "cond" []] @@ fun cond -> Broadcast cond);
    ("__pthread_cond_broadcast", special [__ "cond" []] @@ fun cond -> Broadcast cond);
    ("pthread_cond_wait", special [__ "cond" []; __ "mutex" []] @@ fun cond mutex -> Wait {cond; mutex});
    ("__pthread_cond_wait", special [__ "cond" []; __ "mutex" []] @@ fun cond mutex -> Wait {cond; mutex});
    ("pthread_cond_timedwait", special [__ "cond" []; __ "mutex" []; __ "abstime" [r]] @@ fun cond mutex abstime -> TimedWait {cond; mutex; abstime});
    ("pthread_cond_destroy", unknown [drop "cond" [f]]);
    ("__pthread_cond_destroy", unknown [drop "cond" [f]]);
    ("pthread_mutexattr_settype", special [__ "attr" []; __ "type" []] @@ fun attr typ -> MutexAttrSetType {attr; typ});
    ("pthread_mutex_init", special [__ "mutex" []; __ "attr" []] @@ fun mutex attr -> MutexInit {mutex; attr});
    ("pthread_mutex_destroy", unknown [drop "mutex" [f]]);
    ("pthread_mutex_lock", special [__ "mutex" []] @@ fun mutex -> Lock {lock = mutex; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = false});
    ("__pthread_mutex_lock", special [__ "mutex" []] @@ fun mutex -> Lock {lock = mutex; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = false});
    ("pthread_mutex_trylock", special [__ "mutex" []] @@ fun mutex -> Lock {lock = mutex; try_ = true; write = true; return_on_success = false});
    ("__pthread_mutex_trylock", special [__ "mutex" []] @@ fun mutex -> Lock {lock = mutex; try_ = true; write = true; return_on_success = false});
    ("pthread_mutex_unlock", special [__ "mutex" []] @@ fun mutex -> Unlock mutex);
    ("__pthread_mutex_unlock", special [__ "mutex" []] @@ fun mutex -> Unlock mutex);
    ("pthread_mutexattr_init", unknown [drop "attr" [w]]);
    ("pthread_mutexattr_destroy", unknown [drop "attr" [f]]);
    ("pthread_rwlock_init", unknown [drop "rwlock" [w]; drop "attr" [r]]);
    ("pthread_rwlock_destroy", unknown [drop "rwlock" [f]]);
    ("pthread_rwlock_rdlock", special [__ "rwlock" []] @@ fun rwlock -> Lock {lock = rwlock; try_ = get_bool "sem.lock.fail"; write = false; return_on_success = true});
    ("pthread_rwlock_tryrdlock", special [__ "rwlock" []] @@ fun rwlock -> Lock {lock = rwlock; try_ = get_bool "sem.lock.fail"; write = false; return_on_success = true});
    ("pthread_rwlock_wrlock", special [__ "rwlock" []] @@ fun rwlock -> Lock {lock = rwlock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true});
    ("pthread_rwlock_trywrlock", special [__ "rwlock" []] @@ fun rwlock -> Lock {lock = rwlock; try_ = true; write = true; return_on_success = false});
    ("pthread_rwlock_unlock", special [__ "rwlock" []] @@ fun rwlock -> Unlock rwlock);
    ("pthread_rwlockattr_init", unknown [drop "attr" [w]]);
    ("pthread_rwlockattr_destroy", unknown [drop "attr" [f]]);
    ("pthread_spin_init", unknown [drop "lock" [w]; drop "pshared" []]);
    ("pthread_spin_destroy", unknown [drop "lock" [f]]);
    ("pthread_spin_lock", special [__ "lock" []] @@ fun lock -> Lock {lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true});
    ("pthread_spin_trylock", special [__ "lock" []] @@ fun lock -> Lock {lock = lock; try_ = true; write = true; return_on_success = false});
    ("pthread_spin_unlock", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("pthread_attr_init", unknown [drop "attr" [w]]);
    ("pthread_attr_destroy", unknown [drop "attr" [f]]);
    ("pthread_attr_getdetachstate", unknown [drop "attr" [r]; drop "detachstate" [w]]);
    ("pthread_attr_setdetachstate", unknown [drop "attr" [w]; drop "detachstate" []]);
    ("pthread_attr_getstacksize", unknown [drop "attr" [r]; drop "stacksize" [w]]);
    ("pthread_attr_setstacksize", unknown [drop "attr" [w]; drop "stacksize" []]);
    ("pthread_attr_getscope", unknown [drop "attr" [r]; drop "scope" [w]]);
    ("pthread_attr_setscope", unknown [drop "attr" [w]; drop "scope" []]);
    ("pthread_self", unknown []);
    ("pthread_sigmask", unknown [drop "how" []; drop "set" [r]; drop "oldset" [w]]);
    ("pthread_setspecific", unknown ~attrs:[InvalidateGlobals] [drop "key" []; drop "value" [w_deep]]);
    ("pthread_getspecific", unknown ~attrs:[InvalidateGlobals] [drop "key" []]);
    ("pthread_key_create", unknown [drop "key" [w]; drop "destructor" [s]]);
    ("pthread_key_delete", unknown [drop "key" [f]]);
    ("pthread_cancel", unknown [drop "thread" []]);
    ("pthread_setcanceltype", unknown [drop "type" []; drop "oldtype" [w]]);
    ("pthread_detach", unknown [drop "thread" []]);
    ("pthread_attr_setschedpolicy", unknown [drop "attr" [r; w]; drop "policy" []]);
    ("pthread_condattr_init", unknown [drop "attr" [w]]);
    ("pthread_condattr_setclock", unknown [drop "attr" [w]; drop "clock_id" []]);
    ("pthread_mutexattr_destroy", unknown [drop "attr" [f]]);
    ("pthread_attr_setschedparam", unknown [drop "attr" [r; w]; drop "param" [r]]);
    ("sem_timedwait", unknown [drop "sem" [r]; drop "abs_timeout" [r]]); (* no write accesses to sem because sync primitive itself has no race *)
  ]

(** GCC builtin functions.
    These are not builtin versions of functions from other lists. *)
let gcc_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("__builtin_bswap16", unknown [drop "x" []]);
    ("__builtin_bswap32", unknown [drop "x" []]);
    ("__builtin_bswap64", unknown [drop "x" []]);
    ("__builtin_bswap128", unknown [drop "x" []]);
    ("__builtin_ctz", unknown [drop "x" []]);
    ("__builtin_ctzl", unknown [drop "x" []]);
    ("__builtin_ctzll", unknown [drop "x" []]);
    ("__builtin_clz", unknown [drop "x" []]);
    ("__builtin_object_size", unknown [drop "ptr" [r]; drop' []]);
    ("__builtin_prefetch", unknown (drop "addr" [] :: VarArgs (drop' [])));
    ("__builtin_expect", special [__ "exp" []; drop' []] @@ fun exp -> Identity exp); (* Identity, because just compiler optimization annotation. *)
    ("__builtin_unreachable", special' [] @@ fun () -> if get_bool "sem.builtin_unreachable.dead_code" then Abort else Unknown); (* https://github.com/sosy-lab/sv-benchmarks/issues/1296 *)
    ("__assert_rtn", special [drop "func" [r]; drop "file" [r]; drop "line" []; drop "exp" [r]] @@ Abort); (* MacOS's built-in assert *)
    ("__assert_fail", special [drop "assertion" [r]; drop "file" [r]; drop "line" []; drop "function" [r]] @@ Abort); (* gcc's built-in assert *)
    ("__builtin_return_address", unknown [drop "level" []]);
    ("__builtin___sprintf_chk", unknown (drop "s" [w] :: drop "flag" [] :: drop "os" [] :: drop "fmt" [r] :: VarArgs (drop' [r])));
    ("__builtin_add_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_sadd_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_saddl_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_saddll_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_uadd_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_uaddl_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_uaddll_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_sub_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_ssub_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_ssubl_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_ssubll_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_usub_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_usubl_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_usubll_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_mul_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_smul_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_smull_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_smulll_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_umul_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_umull_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_umulll_overflow", unknown [drop "a" []; drop "b" []; drop "c" [w]]);
    ("__builtin_add_overflow_p", unknown [drop "a" []; drop "b" []; drop "c" []]);
    ("__builtin_sub_overflow_p", unknown [drop "a" []; drop "b" []; drop "c" []]);
    ("__builtin_mul_overflow_p", unknown [drop "a" []; drop "b" []; drop "c" []]);
    ("__builtin_popcount", unknown [drop "x" []]);
    ("__builtin_popcountl", unknown [drop "x" []]);
    ("__builtin_popcountll", unknown [drop "x" []]);
    ("__atomic_store_n", unknown [drop "ptr" [w]; drop "val" []; drop "memorder" []]);
    ("__atomic_load_n", unknown [drop "ptr" [r]; drop "memorder" []]);
    ("__sync_fetch_and_add", unknown (drop "ptr" [r; w] :: drop "value" [] :: VarArgs (drop' [])));
    ("__sync_fetch_and_sub", unknown (drop "ptr" [r; w] :: drop "value" [] :: VarArgs (drop' [])));
    ("__builtin_va_copy", unknown [drop "dest" [w]; drop "src" [r]]);
  ]

let glibc_desc_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("fputs_unlocked", unknown [drop "s" [r]; drop "stream" [w]]);
    ("futimesat", unknown [drop "dirfd" []; drop "pathname" [r]; drop "times" [r]]);
    ("error", unknown ((drop "status" []):: (drop "errnum" []) :: (drop "format" [r]) :: (VarArgs (drop' [r]))));
    ("gettext", unknown [drop "msgid" [r]]);
    ("euidaccess", unknown [drop "pathname" [r]; drop "mode" []]);
    ("rpmatch", unknown [drop "response" [r]]);
    ("getpagesize", unknown []);
    ("__fgets_alias", unknown [drop "__s" [w]; drop "__n" []; drop "__stream" [r_deep; w_deep]]);
    ("__fgets_chk", unknown [drop "__s" [w]; drop "__size" []; drop "__n" []; drop "__stream" [r_deep; w_deep]]);
    ("__fread_alias", unknown [drop "__ptr" [w]; drop "__size" []; drop "__n" []; drop "__stream" [r_deep; w_deep]]);
    ("__fread_chk", unknown [drop "__ptr" [w]; drop "__ptrlen" []; drop "__size" []; drop "__n" []; drop "__stream" [r_deep; w_deep]]);
    ("__read_chk", unknown [drop "__fd" []; drop "__buf" [w]; drop "__nbytes" []; drop "__buflen" []]);
    ("__read_alias", unknown [drop "__fd" []; drop "__buf" [w]; drop "__nbytes" []]);
    ("__readlink_chk", unknown [drop "path" [r]; drop "buf" [w]; drop "len" []; drop "buflen" []]);
    ("__readlink_alias", unknown [drop "path" [r]; drop "buf" [w]; drop "len" []]);
    ("__overflow", unknown [drop "f" [r]; drop "ch" []]);
    ("__ctype_get_mb_cur_max", unknown []);
    ("__xmknod", unknown [drop "ver" []; drop "path" [r]; drop "mode" []; drop "dev" [r; w]]);
    ("yp_get_default_domain", unknown [drop "outdomain" [w]]);
    ("__nss_configure_lookup", unknown [drop "db" [r]; drop "service_line" [r]]);
    ("xdr_string", unknown [drop "xdrs" [r_deep; w_deep]; drop "sp" [r; w]; drop "maxsize" []]);
    ("xdr_enum", unknown [drop "xdrs" [r_deep; w_deep]; drop "ep" [r; w]]);
    ("xdr_u_int", unknown [drop "xdrs" [r_deep; w_deep]; drop "up" [r; w]]);
    ("xdr_opaque", unknown [drop "xdrs" [r_deep; w_deep]; drop "cp" [r; w]; drop "cnt" []]);
    ("xdr_free", unknown [drop "proc" [s]; drop "objp" [f_deep]]);
    ("svcerr_noproc", unknown [drop "xprt" [r_deep; w_deep]]);
    ("svcerr_decode", unknown [drop "xprt" [r_deep; w_deep]]);
    ("svcerr_systemerr", unknown [drop "xprt" [r_deep; w_deep]]);
    ("svc_sendreply", unknown [drop "xprt" [r_deep; w_deep]; drop "outproc" [s]; drop "out" [r]]);
    ("shutdown", unknown [drop "socket" []; drop "how" []]);
    ("getaddrinfo_a", unknown [drop "mode" []; drop "list" [w_deep]; drop "nitems" []; drop "sevp" [r; w; s]]);
    ("__uflow", unknown [drop "file" [r; w]]);
    ("getservbyname_r", unknown [drop "name" [r]; drop "proto" [r]; drop "result_buf" [w_deep]; drop "buf" [w]; drop "buflen" []; drop "result" [w]]);
    ("strsep", unknown [drop "stringp" [r_deep; w]; drop "delim" [r]]);
    ("strcasestr", unknown [drop "haystack" [r]; drop "needle" [r]]);
    ("inet_aton", unknown [drop "cp" [r]; drop "inp" [w]]);
    ("fopencookie", unknown [drop "cookie" []; drop "mode" [r]; drop "io_funcs" [s_deep]]); (* doesn't access cookie but passes it to io_funcs *)
    ("mempcpy", special [__ "dest" [w]; __ "src" [r]; drop "n" []] @@ fun dest src -> Memcpy { dest; src });
    ("__builtin___mempcpy_chk", special [__ "dest" [w]; __ "src" [r]; drop "n" []; drop "os" []] @@ fun dest src -> Memcpy { dest; src });
  ]

let linux_userspace_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    (* ("prctl", unknown [drop "option" []; drop "arg2" []; drop "arg3" []; drop "arg4" []; drop "arg5" []]); *)
    ("prctl", unknown (drop "option" [] :: VarArgs (drop' []))); (* man page has 5 arguments, but header has varargs and real-world programs may call with <5 *)
    ("__ctype_tolower_loc", unknown []);
    ("__ctype_toupper_loc", unknown []);
    ("endutxent", unknown ~attrs:[ThreadUnsafe] []);
    ("epoll_create", unknown [drop "size" []]);
    ("epoll_ctl", unknown [drop "epfd" []; drop "op" []; drop "fd" []; drop "event" [w]]);
    ("epoll_wait", unknown [drop "epfd" []; drop "events" [w]; drop "maxevents" []; drop "timeout" []]);
    ("__fprintf_chk", unknown (drop "stream" [r_deep; w_deep] :: drop "flag" [] :: drop "format" [r] :: VarArgs (drop' [r])));
    ("sysinfo", unknown [drop "info" [w_deep]]);
    ("__xpg_basename", unknown [drop "path" [r]]);
    ("ptrace", unknown (drop "request" [] :: VarArgs (drop' [r_deep; w_deep]))); (* man page has 4 arguments, but header has varargs and real-world programs may call with <4 *)
  ]

let big_kernel_lock = AddrOf (Cil.var (Cilfacade.create_var (makeGlobalVar "[big kernel lock]" intType)))
let console_sem = AddrOf (Cil.var (Cilfacade.create_var (makeGlobalVar "[console semaphore]" intType)))

(** Linux kernel functions. *)
let linux_kernel_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("down_trylock", special [__ "sem" []] @@ fun sem -> Lock { lock = sem; try_ = true; write = true; return_on_success = true });
    ("down_read", special [__ "sem" []] @@ fun sem -> Lock { lock = sem; try_ = get_bool "sem.lock.fail"; write = false; return_on_success = true });
    ("down_write", special [__ "sem" []] @@ fun sem -> Lock { lock = sem; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("up", special [__ "sem" []] @@ fun sem -> Unlock sem);
    ("up_read", special [__ "sem" []] @@ fun sem -> Unlock sem);
    ("up_write", special [__ "sem" []] @@ fun sem -> Unlock sem);
    ("mutex_init", unknown [drop "mutex" []]);
    ("mutex_lock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("mutex_trylock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = true; write = true; return_on_success = true });
    ("mutex_lock_interruptible", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("mutex_unlock", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("spin_lock_init", unknown [drop "lock" []]);
    ("spin_lock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_spin_lock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_spin_lock_bh", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("spin_trylock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = true; write = true; return_on_success = true });
    ("_spin_trylock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = true; write = true; return_on_success = true });
    ("spin_unlock", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("_spin_unlock", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("_spin_unlock_bh", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("spin_lock_irqsave", special [__ "lock" []; drop "flags" []] @@ fun lock -> Lock { lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_spin_lock_irqsave", special [__ "lock" []] @@ fun lock -> Lock { lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_spin_trylock_irqsave", special [__ "lock" []; drop "flags" []] @@ fun lock -> Lock { lock; try_ = true; write = true; return_on_success = true });
    ("spin_unlock_irqrestore", special [__ "lock" []; drop "flags" []] @@ fun lock -> Unlock lock);
    ("_spin_unlock_irqrestore", special [__ "lock" []; drop "flags" []] @@ fun lock -> Unlock lock);
    ("raw_spin_unlock", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("_raw_spin_unlock_irqrestore", special [__ "lock" []; drop "flags" []] @@ fun lock -> Unlock lock);
    ("_raw_spin_lock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_raw_spin_lock_flags", special [__ "lock" []; drop "flags" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_raw_spin_lock_irqsave", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_raw_spin_lock_irq", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_raw_spin_lock_bh", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_raw_spin_unlock_bh", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("_read_lock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = false; return_on_success = true });
    ("_read_unlock", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("_raw_read_lock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = false; return_on_success = true });
    ("__raw_read_unlock", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("_write_lock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("_write_unlock", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("_raw_write_lock", special [__ "lock" []] @@ fun lock -> Lock { lock = lock; try_ = get_bool "sem.lock.fail"; write = true; return_on_success = true });
    ("__raw_write_unlock", special [__ "lock" []] @@ fun lock -> Unlock lock);
    ("spinlock_check", special [__ "lock" []] @@ fun lock -> Identity lock);  (* Identity, because we don't want lock internals. *)
    ("_lock_kernel", special [drop "func" [r]; drop "file" [r]; drop "line" []] @@ Lock { lock = big_kernel_lock; try_ = false; write = true; return_on_success = true });
    ("_unlock_kernel", special [drop "func" [r]; drop "file" [r]; drop "line" []] @@ Unlock big_kernel_lock);
    ("acquire_console_sem", special [] @@ Lock { lock = console_sem; try_ = false; write = true; return_on_success = true });
    ("release_console_sem", special [] @@ Unlock console_sem);
    ("misc_deregister", unknown [drop "misc" [r_deep]]);
    ("__bad_percpu_size", special [] Abort); (* these do not have definitions so the linker will fail if they are actually called *)
    ("__bad_size_call_parameter", special [] Abort);
    ("__xchg_wrong_size", special [] Abort);
    ("__cmpxchg_wrong_size", special [] Abort);
    ("__xadd_wrong_size", special [] Abort);
    ("__put_user_bad", special [] Abort);
  ]

(** Goblint functions. *)
let goblint_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("__goblint_unknown", unknown [drop' [w]]);
    ("__goblint_check", special [__ "exp" []] @@ fun exp -> Assert { exp; check = true; refine = false });
    ("__goblint_assume", special [__ "exp" []] @@ fun exp -> Assert { exp; check = false; refine = true });
    ("__goblint_assert", special [__ "exp" []] @@ fun exp -> Assert { exp; check = true; refine = get_bool "sem.assert.refine" });
    ("__goblint_split_begin", unknown [drop "exp" []]);
    ("__goblint_split_end", unknown [drop "exp" []]);
  ]

(** zstd functions.
    Only used with extraspecials. *)
let zstd_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("ZSTD_customMalloc", special [__ "size" []; drop "customMem" [r]] @@ fun size -> Malloc size);
    ("ZSTD_customCalloc", special [__ "size" []; drop "customMem" [r]] @@ fun size -> Calloc { size; count = Cil.one });
    ("ZSTD_customFree", special [__ "ptr" [f]; drop "customMem" [r]] @@ fun ptr -> Free ptr);
  ]

(** math functions.
    Functions and builtin versions of function and macros defined in math.h. *)
let math_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("__builtin_nan", special [__ "str" []] @@ fun str -> Math { fun_args = (Nan (FDouble, str)) });
    ("nan", special [__ "str" []] @@ fun str -> Math { fun_args = (Nan (FDouble, str)) });
    ("__builtin_nanf", special [__ "str" []] @@ fun str -> Math { fun_args = (Nan (FFloat, str)) });
    ("nanf", special [__ "str" []] @@ fun str -> Math { fun_args = (Nan (FFloat, str)) });
    ("__builtin_nanl", special [__ "str" []] @@ fun str -> Math { fun_args = (Nan (FLongDouble, str)) });
    ("nanl", special [__ "str" []] @@ fun str -> Math { fun_args = (Nan (FLongDouble, str)) });
    ("__builtin_inf", special [] @@ Math { fun_args = Inf FDouble});
    ("__builtin_huge_val", special [] @@ Math { fun_args = Inf FDouble}); (* we assume the target format can represent infinities *)
    ("__builtin_inff", special [] @@ Math { fun_args = Inf FFloat});
    ("__builtin_huge_valf", special [] @@ Math { fun_args = Inf FFloat}); (* we assume the target format can represent infinities *)
    ("__builtin_infl", special [] @@ Math { fun_args = Inf FLongDouble});
    ("__builtin_huge_vall", special [] @@ Math { fun_args = Inf FLongDouble});  (* we assume the target format can represent infinities *)
    ("__builtin_isfinite", special [__ "x" []] @@ fun x -> Math { fun_args = (Isfinite x) });
    ("__finite", special [__ "x" []] @@ fun x -> Math { fun_args = (Isfinite x) });
    ("__finitef", special [__ "x" []] @@ fun x -> Math { fun_args = (Isfinite x) });
    ("__finitel", special [__ "x" []] @@ fun x -> Math { fun_args = (Isfinite x) });
    ("__builtin_isinf", special [__ "x" []] @@ fun x -> Math { fun_args = (Isinf x) });
    ("__isinf", special [__ "x" []] @@ fun x -> Math { fun_args = (Isinf x) });
    ("__isinff", special [__ "x" []] @@ fun x -> Math { fun_args = (Isinf x) });
    ("__isinfl", special [__ "x" []] @@ fun x -> Math { fun_args = (Isinf x) });
    ("__builtin_isinf_sign", special [__ "x" []] @@ fun x -> Math { fun_args = (Isinf x) });
    ("__builtin_isnan", special [__ "x" []] @@ fun x -> Math { fun_args = (Isnan x) });
    ("__isnan", special [__ "x" []] @@ fun x -> Math { fun_args = (Isnan x) });
    ("__isnanf", special [__ "x" []] @@ fun x -> Math { fun_args = (Isnan x) });
    ("__isnanl", special [__ "x" []] @@ fun x -> Math { fun_args = (Isnan x) });
    ("__builtin_isnormal", special [__ "x" []] @@ fun x -> Math { fun_args = (Isnormal x) });
    ("__builtin_signbit", special [__ "x" []] @@ fun x -> Math { fun_args = (Signbit x) });
    ("__signbit", special [__ "x" []] @@ fun x -> Math { fun_args = (Signbit x) });
    ("__signbitf", special [__ "x" []] @@ fun x -> Math { fun_args = (Signbit x) });
    ("__signbitl", special [__ "x" []] @@ fun x -> Math { fun_args = (Signbit x) });
    ("__builtin_fabs", special [__ "x" []] @@ fun x -> Math { fun_args = (Fabs (FDouble, x)) });
    ("__builtin_fabsf", special [__ "x" []] @@ fun x -> Math { fun_args = (Fabs (FFloat, x)) });
    ("__builtin_fabsl", special [__ "x" []] @@ fun x -> Math { fun_args = (Fabs (FLongDouble, x)) });
    ("__builtin_isgreater", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Isgreater (x,y)) });
    ("__builtin_isgreaterequal", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Isgreaterequal (x,y)) });
    ("__builtin_isless", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Isless (x,y)) });
    ("__builtin_islessequal", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Islessequal (x,y)) });
    ("__builtin_islessgreater", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Islessgreater (x,y)) });
    ("__builtin_isunordered", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Isunordered (x,y)) });
    ("ceil", special [__ "x" []] @@ fun x -> Math { fun_args = (Ceil (FDouble, x)) });
    ("ceilf", special [__ "x" []] @@ fun x -> Math { fun_args = (Ceil (FFloat, x)) });
    ("ceill", special [__ "x" []] @@ fun x -> Math { fun_args = (Ceil (FLongDouble, x)) });
    ("floor", special [__ "x" []] @@ fun x -> Math { fun_args = (Floor (FDouble, x)) });
    ("floorf", special [__ "x" []] @@ fun x -> Math { fun_args = (Floor (FFloat, x)) });
    ("floorl", special [__ "x" []] @@ fun x -> Math { fun_args = (Floor (FLongDouble, x)) });
    ("fabs", special [__ "x" []] @@ fun x -> Math { fun_args = (Fabs (FDouble, x)) });
    ("fabsf", special [__ "x" []] @@ fun x -> Math { fun_args = (Fabs (FFloat, x)) });
    ("fabsl", special [__ "x" []] @@ fun x -> Math { fun_args = (Fabs (FLongDouble, x)) });
    ("fmax", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Fmax (FDouble, x, y)) });
    ("fmaxf", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Fmax (FFloat, x, y)) });
    ("fmaxl", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Fmax (FLongDouble, x, y)) });
    ("fmin", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Fmin (FDouble, x, y)) });
    ("fminf", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Fmin (FFloat, x, y)) });
    ("fminl", special [__ "x" []; __ "y" []] @@ fun x y -> Math { fun_args = (Fmin (FLongDouble, x, y)) });
    ("__builtin_acos", special [__ "x" []] @@ fun x -> Math { fun_args = (Acos (FDouble, x)) });
    ("acos", special [__ "x" []] @@ fun x -> Math { fun_args = (Acos (FDouble, x)) });
    ("acosf", special [__ "x" []] @@ fun x -> Math { fun_args = (Acos (FFloat, x)) });
    ("acosl", special [__ "x" []] @@ fun x -> Math { fun_args = (Acos (FLongDouble, x)) });
    ("__builtin_asin", special [__ "x" []] @@ fun x -> Math { fun_args = (Asin (FDouble, x)) });
    ("asin", special [__ "x" []] @@ fun x -> Math { fun_args = (Asin (FDouble, x)) });
    ("asinf", special [__ "x" []] @@ fun x -> Math { fun_args = (Asin (FFloat, x)) });
    ("asinl", special [__ "x" []] @@ fun x -> Math { fun_args = (Asin (FLongDouble, x)) });
    ("__builtin_atan", special [__ "x" []] @@ fun x -> Math { fun_args = (Atan (FDouble, x)) });
    ("atan", special [__ "x" []] @@ fun x -> Math { fun_args = (Atan (FDouble, x)) });
    ("atanf", special [__ "x" []] @@ fun x -> Math { fun_args = (Atan (FFloat, x)) });
    ("atanl", special [__ "x" []] @@ fun x -> Math { fun_args = (Atan (FLongDouble, x)) });
    ("__builtin_atan2", special [__ "y" []; __ "x" []] @@ fun y x -> Math { fun_args = (Atan2 (FDouble, y, x)) });
    ("atan2", special [__ "y" []; __ "x" []] @@ fun y x -> Math { fun_args = (Atan2 (FDouble, y, x)) });
    ("atan2f", special [__ "y" []; __ "x" []] @@ fun y x -> Math { fun_args = (Atan2 (FFloat, y, x)) });
    ("atan2l", special [__ "y" []; __ "x" []] @@ fun y x -> Math { fun_args = (Atan2 (FLongDouble, y, x)) });
    ("__builtin_cos", special [__ "x" []] @@ fun x -> Math { fun_args = (Cos (FDouble, x)) });
    ("cos", special [__ "x" []] @@ fun x -> Math { fun_args = (Cos (FDouble, x)) });
    ("cosf", special [__ "x" []] @@ fun x -> Math { fun_args = (Cos (FFloat, x)) });
    ("cosl", special [__ "x" []] @@ fun x -> Math { fun_args = (Cos (FLongDouble, x)) });
    ("__builtin_sin", special [__ "x" []] @@ fun x -> Math { fun_args = (Sin (FDouble, x)) });
    ("sin", special [__ "x" []] @@ fun x -> Math { fun_args = (Sin (FDouble, x)) });
    ("sinf", special [__ "x" []] @@ fun x -> Math { fun_args = (Sin (FFloat, x)) });
    ("sinl", special [__ "x" []] @@ fun x -> Math { fun_args = (Sin (FLongDouble, x)) });
    ("__builtin_tan", special [__ "x" []] @@ fun x -> Math { fun_args = (Tan (FDouble, x)) });
    ("tan", special [__ "x" []] @@ fun x -> Math { fun_args = (Tan (FDouble, x)) });
    ("tanf", special [__ "x" []] @@ fun x -> Math { fun_args = (Tan (FFloat, x)) });
    ("tanl", special [__ "x" []] @@ fun x -> Math { fun_args = (Tan (FLongDouble, x)) });
    ("acosh", unknown [drop "x" []]);
    ("acoshf", unknown [drop "x" []]);
    ("acoshl", unknown [drop "x" []]);
    ("asinh", unknown [drop "x" []]);
    ("asinhf", unknown [drop "x" []]);
    ("asinhl", unknown [drop "x" []]);
    ("atanh", unknown [drop "x" []]);
    ("atanhf", unknown [drop "x" []]);
    ("atanhl", unknown [drop "x" []]);
    ("cosh", unknown [drop "x" []]);
    ("coshf", unknown [drop "x" []]);
    ("coshl", unknown [drop "x" []]);
    ("sinh", unknown [drop "x" []]);
    ("sinhf", unknown [drop "x" []]);
    ("sinhl", unknown [drop "x" []]);
    ("tanh", unknown [drop "x" []]);
    ("tanhf", unknown [drop "x" []]);
    ("tanhl", unknown [drop "x" []]);
    ("cbrt", unknown [drop "x" []]);
    ("cbrtf", unknown [drop "x" []]);
    ("cbrtl", unknown [drop "x" []]);
    ("copysign", unknown [drop "x" []; drop "y" []]);
    ("copysignf", unknown [drop "x" []; drop "y" []]);
    ("copysignl", unknown [drop "x" []; drop "y" []]);
    ("erf", unknown [drop "x" []]);
    ("erff", unknown [drop "x" []]);
    ("erfl", unknown [drop "x" []]);
    ("erfc", unknown [drop "x" []]);
    ("erfcf", unknown [drop "x" []]);
    ("erfcl", unknown [drop "x" []]);
    ("exp", unknown [drop "x" []]);
    ("expf", unknown [drop "x" []]);
    ("expl", unknown [drop "x" []]);
    ("exp2", unknown [drop "x" []]);
    ("exp2f", unknown [drop "x" []]);
    ("exp2l", unknown [drop "x" []]);
    ("expm1", unknown [drop "x" []]);
    ("expm1f", unknown [drop "x" []]);
    ("expm1l", unknown [drop "x" []]);
    ("fdim", unknown [drop "x" []; drop "y" []]);
    ("fdimf", unknown [drop "x" []; drop "y" []]);
    ("fdiml", unknown [drop "x" []; drop "y" []]);
    ("fma", unknown [drop "x" []; drop "y" []; drop "z" []]);
    ("fmaf", unknown [drop "x" []; drop "y" []; drop "z" []]);
    ("fmal", unknown [drop "x" []; drop "y" []; drop "z" []]);
    ("fmod", unknown [drop "x" []; drop "y" []]);
    ("fmodf", unknown [drop "x" []; drop "y" []]);
    ("fmodl", unknown [drop "x" []; drop "y" []]);
    ("frexp", unknown [drop "arg" []; drop "exp" [w]]);
    ("frexpf", unknown [drop "arg" []; drop "exp" [w]]);
    ("frexpl", unknown [drop "arg" []; drop "exp" [w]]);
    ("hypot", unknown [drop "x" []; drop "y" []]);
    ("hypotf", unknown [drop "x" []; drop "y" []]);
    ("hypotl", unknown [drop "x" []; drop "y" []]);
    ("ilogb", unknown [drop "x" []]);
    ("ilogbf", unknown [drop "x" []]);
    ("ilogbl", unknown [drop "x" []]);
    ("ldexp", unknown [drop "arg" []; drop "exp" []]);
    ("ldexpf", unknown [drop "arg" []; drop "exp" []]);
    ("ldexpl", unknown [drop "arg" []; drop "exp" []]);
    ("lgamma", unknown ~attrs:[ThreadUnsafe] [drop "x" []]);
    ("lgammaf", unknown ~attrs:[ThreadUnsafe] [drop "x" []]);
    ("lgammal", unknown ~attrs:[ThreadUnsafe] [drop "x" []]);
    ("log", unknown [drop "x" []]);
    ("logf", unknown [drop "x" []]);
    ("logl", unknown [drop "x" []]);
    ("log10", unknown [drop "x" []]);
    ("log10f", unknown [drop "x" []]);
    ("log10l", unknown [drop "x" []]);
    ("log1p", unknown [drop "x" []]);
    ("log1pf", unknown [drop "x" []]);
    ("log1pl", unknown [drop "x" []]);
    ("log2", unknown [drop "x" []]);
    ("log2f", unknown [drop "x" []]);
    ("log2l", unknown [drop "x" []]);
    ("logb", unknown [drop "x" []]);
    ("logbf", unknown [drop "x" []]);
    ("logbl", unknown [drop "x" []]);
    ("rint", unknown [drop "x" []]);
    ("rintf", unknown [drop "x" []]);
    ("rintl", unknown [drop "x" []]);
    ("lrint", unknown [drop "x" []]);
    ("lrintf", unknown [drop "x" []]);
    ("lrintl", unknown [drop "x" []]);
    ("llrint", unknown [drop "x" []]);
    ("llrintf", unknown [drop "x" []]);
    ("llrintl", unknown [drop "x" []]);
    ("round", unknown [drop "x" []]);
    ("roundf", unknown [drop "x" []]);
    ("roundl", unknown [drop "x" []]);
    ("lround", unknown [drop "x" []]);
    ("lroundf", unknown [drop "x" []]);
    ("lroundl", unknown [drop "x" []]);
    ("llround", unknown [drop "x" []]);
    ("llroundf", unknown [drop "x" []]);
    ("llroundl", unknown [drop "x" []]);
    ("modf", unknown [drop "arg" []; drop "iptr" [w]]);
    ("modff", unknown [drop "arg" []; drop "iptr" [w]]);
    ("modfl", unknown [drop "arg" []; drop "iptr" [w]]);
    ("nearbyint", unknown [drop "x" []]);
    ("nearbyintf", unknown [drop "x" []]);
    ("nearbyintl", unknown [drop "x" []]);
    ("nextafter", unknown [drop "from" []; drop "to" []]);
    ("nextafterf", unknown [drop "from" []; drop "to" []]);
    ("nextafterl", unknown [drop "from" []; drop "to" []]);
    ("nexttoward", unknown [drop "from" []; drop "to" []]);
    ("nexttowardf", unknown [drop "from" []; drop "to" []]);
    ("nexttowardl", unknown [drop "from" []; drop "to" []]);
    ("pow", unknown [drop "base" []; drop "exponent" []]);
    ("powf", unknown [drop "base" []; drop "exponent" []]);
    ("powl", unknown [drop "base" []; drop "exponent" []]);
    ("remainder", unknown [drop "x" []; drop "y" []]);
    ("remainderf", unknown [drop "x" []; drop "y" []]);
    ("remainderl", unknown [drop "x" []; drop "y" []]);
    ("remquo", unknown [drop "x" []; drop "y" []; drop "quo" [w]]);
    ("remquof", unknown [drop "x" []; drop "y" []; drop "quo" [w]]);
    ("remquol", unknown [drop "x" []; drop "y" []; drop "quo" [w]]);
    ("scalbn", unknown [drop "arg" []; drop "exp" []]);
    ("scalbnf", unknown [drop "arg" []; drop "exp" []]);
    ("scalbnl", unknown [drop "arg" []; drop "exp" []]);
    ("scalbln", unknown [drop "arg" []; drop "exp" []]);
    ("scalblnf", unknown [drop "arg" []; drop "exp" []]);
    ("scalblnl", unknown [drop "arg" []; drop "exp" []]);
    ("sqrt", unknown [drop "x" []]);
    ("sqrtf", unknown [drop "x" []]);
    ("sqrtl", unknown [drop "x" []]);
    ("tgamma", unknown [drop "x" []]);
    ("tgammaf", unknown [drop "x" []]);
    ("tgammal", unknown [drop "x" []]);
    ("trunc", unknown [drop "x" []]);
    ("truncf", unknown [drop "x" []]);
    ("truncl", unknown [drop "x" []]);
    ("j0", unknown [drop "x" []]); (* GNU C Library special function *)
    ("j1", unknown [drop "x" []]); (* GNU C Library special function *)
    ("jn", unknown [drop "n" []; drop "x" []]); (* GNU C Library special function *)
    ("y0", unknown [drop "x" []]); (* GNU C Library special function *)
    ("y1", unknown [drop "x" []]); (* GNU C Library special function *)
    ("yn", unknown [drop "n" []; drop "x" []]); (* GNU C Library special function *)
    ("fegetround", unknown []);
    ("fesetround", unknown [drop "round" []]); (* Our float domain is rounding agnostic *)
    ("__builtin_fpclassify", unknown [drop "nan" []; drop "infinite" []; drop "normal" []; drop "subnormal" []; drop "zero" []; drop "x" []]); (* TODO: We could do better here *)
    ("__builtin_fpclassifyf", unknown [drop "nan" []; drop "infinite" []; drop "normal" []; drop "subnormal" []; drop "zero" []; drop "x" []]);
    ("__builtin_fpclassifyl", unknown [drop "nan" []; drop "infinite" []; drop "normal" []; drop "subnormal" []; drop "zero" []; drop "x" []]);
    ("__fpclassify", unknown [drop "x" []]);
    ("__fpclassifyd", unknown [drop "x" []]);
    ("__fpclassifyf", unknown [drop "x" []]);
    ("__fpclassifyl", unknown [drop "x" []]);
  ]

let verifier_atomic_var = Cilfacade.create_var (makeGlobalVar "[__VERIFIER_atomic]" intType)
let verifier_atomic = AddrOf (Cil.var (Cilfacade.create_var verifier_atomic_var))

(** SV-COMP functions.
    Just the ones that require special handling and cannot be stubbed. *)
let svcomp_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("__VERIFIER_atomic_begin", special [] @@ Lock { lock = verifier_atomic; try_ = false; write = true; return_on_success = true });
    ("__VERIFIER_atomic_end", special [] @@ Unlock verifier_atomic);
    ("__VERIFIER_nondet_loff_t", unknown []); (* cannot give it in sv-comp.c without including stdlib or similar *)
  ]

let ncurses_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("echo", unknown []);
    ("noecho", unknown []);
    ("wattrset", unknown [drop "win" [r_deep; w_deep]; drop "attrs" []]);
    ("endwin", unknown []);
    ("wgetch", unknown [drop "win" [r_deep; w_deep]]);
    ("wmove", unknown [drop "win" [r_deep; w_deep]; drop "y" []; drop "x" []]);
    ("waddch", unknown [drop "win" [r_deep; w_deep]; drop "ch" []]);
    ("waddnwstr", unknown [drop "win" [r_deep; w_deep]; drop "wstr" [r]; drop "n" []]);
    ("wattr_on", unknown [drop "win" [r_deep; w_deep]; drop "attrs" []; drop "opts" []]); (* opts argument currently not used *)
    ("wrefresh", unknown [drop "win" [r_deep; w_deep]]);
    ("mvprintw", unknown (drop "win" [r_deep; w_deep] :: drop "y" [] :: drop "x" [] :: drop "fmt" [r] :: VarArgs (drop' [r])));
    ("initscr", unknown []);
    ("curs_set", unknown [drop "visibility" []]);
    ("wtimeout", unknown [drop "win" [r_deep; w_deep]; drop "delay" []]);
    ("start_color", unknown []);
    ("use_default_colors", unknown []);
    ("wclear", unknown [drop "win" [r_deep; w_deep]]);
    ("can_change_color", unknown []);
    ("init_color", unknown [drop "color" []; drop "red" []; drop "green" []; drop "blue" []]);
    ("init_pair", unknown [drop "pair" []; drop "f" [r]; drop "b" [r]]);
    ("wbkgd", unknown [drop "win" [r_deep; w_deep]; drop "ch" []]);
  ]

let libraries = Hashtbl.of_list [
    ("c", c_descs_list @ math_descs_list);
    ("posix", posix_descs_list);
    ("pthread", pthread_descs_list);
    ("gcc", gcc_descs_list);
    ("glibc", glibc_desc_list);
    ("linux-userspace", linux_userspace_descs_list);
    ("linux-kernel", linux_kernel_descs_list);
    ("goblint", goblint_descs_list);
    ("sv-comp", svcomp_descs_list);
    ("ncurses", ncurses_descs_list);
    ("zstd", zstd_descs_list);
  ]

let activated_library_descs: (string, LibraryDesc.t) Hashtbl.t ResettableLazy.t =
  ResettableLazy.from_fun (fun () ->
      let activated = List.unique (GobConfig.get_string_list "lib.activated") in
      let desc_list = List.concat_map (Hashtbl.find libraries) activated in
      Hashtbl.of_list desc_list
    )

let reset_lazy () =
  ResettableLazy.reset activated_library_descs

type categories = [
  | `Malloc       of exp
  | `Calloc       of exp * exp
  | `Realloc      of exp * exp
  | `Lock         of bool * bool * bool  (* try? * write? * return  on success *)
  | `Unlock
  | `ThreadCreate of exp * exp * exp (* id * f  * x       *)
  | `ThreadJoin   of exp * exp (* id * ret_var *)
  | `Unknown      of string ]


let classify fn exps: categories =
  let strange_arguments () =
    M.warn ~category:Program "%s arguments are strange!" fn;
    `Unknown fn
  in
  match fn with
  | "pthread_join" ->
    begin match exps with
      | [id; ret_var] -> `ThreadJoin (id, ret_var)
      | _ -> strange_arguments ()
    end
  | "kmalloc" | "__kmalloc" | "usb_alloc_urb" | "__builtin_alloca" ->
    begin match exps with
      | size::_ -> `Malloc size
      | _ -> strange_arguments ()
    end
  | "kzalloc" ->
    begin match exps with
      | size::_ -> `Calloc (Cil.one, size)
      | _ -> strange_arguments ()
    end
  | "calloc" ->
    begin match exps with
      | n::size::_ -> `Calloc (n, size)
      | _ -> strange_arguments ()
    end
  | x -> `Unknown x


module Invalidate =
struct
  [@@@warning "-unused-value-declaration"] (* some functions are not used below *)
  open AccessKind

  let drop = List.drop
  let keep ns = List.filteri (fun i _ -> List.mem i ns)

  let partition ns x =
    let rec go n =
      function
      | [] -> ([],[])
      | y :: ys ->
        let (i,o) = go (n + 1) ys in
        if List.mem n ns
        then (y::i,   o)
        else (   i,y::o)
    in
    go 1 x

  let writesAllButFirst n f a x =
    match a with
    | Write | Spawn -> f a x @ drop n x
    | Read  -> f a x
    | Free  -> []

  let readsAllButFirst n f a x =
    match a with
    | Write | Spawn -> f a x
    | Read  -> f a x @ drop n x
    | Free  -> []

  let reads ns a x =
    let i, o = partition ns x in
    match a with
    | Write | Spawn -> o
    | Read  -> i
    | Free  -> []

  let writes ns a x =
    let i, o = partition ns x in
    match a with
    | Write | Spawn -> i
    | Read  -> o
    | Free  -> []

  let frees ns a x =
    let i, o = partition ns x in
    match a with
    | Write | Spawn -> []
    | Read  -> o
    | Free  -> i

  let readsFrees rs fs a x =
    match a with
    | Write | Spawn -> []
    | Read  -> keep rs x
    | Free  -> keep fs x

  let onlyReads ns a x =
    match a with
    | Write | Spawn -> []
    | Read  -> keep ns x
    | Free  -> []

  let onlyWrites ns a x =
    match a with
    | Write | Spawn -> keep ns x
    | Read  -> []
    | Free  -> []

  let readsWrites rs ws a x =
    match a with
    | Write | Spawn -> keep ws x
    | Read  -> keep rs x
    | Free  -> []

  let readsAll a x =
    match a with
    | Write | Spawn -> []
    | Read  -> x
    | Free  -> []

  let writesAll a x =
    match a with
    | Write | Spawn -> x
    | Read  -> []
    | Free  -> []
end

open Invalidate

(* Data races: which arguments are read/written?
 * We assume that no known functions that are reachable are executed/spawned. For that we use ThreadCreate above. *)
(* WTF: why are argument numbers 1-indexed (in partition)? *)
let invalidate_actions = [
    "atoi", readsAll;             (*safe*)
    "connect", readsAll;          (*safe*)
    "__printf_chk", readsAll;(*safe*)
    "printk", readsAll;(*safe*)
    "__mutex_init", readsAll;(*safe*)
    "__builtin___snprintf_chk", writes [1];(*keep [1]*)
    "__vfprintf_chk", writes [1];(*keep [1]*)
    "__builtin_va_arg", readsAll;(*safe*)
    "__builtin_va_end", readsAll;(*safe*)
    "__builtin_va_start", readsAll;(*safe*)
    "__ctype_b_loc", readsAll;(*safe*)
    "__errno", readsAll;(*safe*)
    "__errno_location", readsAll;(*safe*)
    "sigfillset", writesAll; (*unsafe*)
    "sigprocmask", writesAll; (*unsafe*)
    "uname", writesAll;(*unsafe*)
    "getopt_long", writesAllButFirst 2 readsAll;(*drop 2*)
    "__strdup", readsAll;(*safe*)
    "strtoul__extinline", readsAll;(*safe*)
    "geteuid", readsAll;(*safe*)
    "readdir_r", writesAll;(*unsafe*)
    "atoi__extinline", readsAll;(*safe*)
    "getpid", readsAll;(*safe*)
    "_IO_getc", writesAll;(*unsafe*)
    "pipe", writesAll;(*unsafe*)
    "close", writesAll;(*unsafe*)
    "setsid", readsAll;(*safe*)
    "strerror_r", writesAll;(*unsafe*)
    "sigemptyset", writesAll;(*unsafe*)
    "sigaddset", writesAll;(*unsafe*)
    "raise", writesAll;(*unsafe*)
    "_strlen", readsAll;(*safe*)
    "__builtin_alloca", readsAll;(*safe*)
    "dlopen", readsAll;(*safe*)
    "dlsym", readsAll;(*safe*)
    "dlclose", readsAll;(*safe*)
    "stat__extinline", writesAllButFirst 1 readsAll;(*drop 1*)
    "lstat__extinline", writesAllButFirst 1 readsAll;(*drop 1*)
    "__builtin_strchr", readsAll;(*safe*)
    "getpgrp", readsAll;(*safe*)
    "umount2", readsAll;(*safe*)
    "memchr", readsAll;(*safe*)
    "waitpid", readsAll;(*safe*)
    "statfs", writes [1;3;4];(*keep [1;3;4]*)
    "mount", readsAll;(*safe*)
    "__open_alias", readsAll;(*safe*)
    "__open_2", readsAll;(*safe*)
    "ioctl", writesAll;(*unsafe*)
    "fstat__extinline", writesAll;(*unsafe*)
    "umount", readsAll;(*safe*)
    "strrchr", readsAll;(*safe*)
    "scandir", writes [1;3;4];(*keep [1;3;4]*)
    "unlink", readsAll;(*safe*)
    "sched_yield", readsAll;(*safe*)
    "nanosleep", writesAllButFirst 1 readsAll;(*drop 1*)
    "sigdelset", readsAll;(*safe*)
    "sigwait", writesAllButFirst 1 readsAll;(*drop 1*)
    "setlocale", readsAll;(*safe*)
    "bindtextdomain", readsAll;(*safe*)
    "textdomain", readsAll;(*safe*)
    "dcgettext", readsAll;(*safe*)
    "putw", readsAll;(*safe*)
    "__getdelim", writes [3];(*keep [3]*)
    "gethostbyname_r", readsAll;(*safe*)
    "__h_errno_location", readsAll;(*safe*)
    "__fxstat", readsAll;(*safe*)
    "getuid", readsAll;(*safe*)
    "openlog", readsAll;(*safe*)
    "getdtablesize", readsAll;(*safe*)
    "umask", readsAll;(*safe*)
    "socket", readsAll;(*safe*)
    "clntudp_create", writesAllButFirst 3 readsAll;(*drop 3*)
    "svctcp_create", readsAll;(*safe*)
    "clntudp_bufcreate", writesAll;(*unsafe*)
    "authunix_create_default", readsAll;(*safe*)
    "writev", readsAll;(*safe*)
    "clnt_broadcast", writesAll;(*unsafe*)
    "clnt_sperrno", readsAll;(*safe*)
    "pmap_unset", writesAll;(*unsafe*)
    "bind", readsAll;(*safe*)
    "svcudp_create", readsAll;(*safe*)
    "svc_register", writesAll;(*unsafe*)
    "sleep", readsAll;(*safe*)
    "usleep", readsAll;
    "svc_run", writesAll;(*unsafe*)
    "dup", readsAll; (*safe*)
    "vsnprintf", writesAllButFirst 3 readsAll; (*drop 3*)
    "__builtin___vsnprintf", writesAllButFirst 3 readsAll; (*drop 3*)
    "__builtin___vsnprintf_chk", writesAllButFirst 3 readsAll; (*drop 3*)
    "strcasecmp", readsAll; (*safe*)
    "strchr", readsAll; (*safe*)
    "__error", readsAll; (*safe*)
    "__maskrune", writesAll; (*unsafe*)
    "inet_addr", readsAll; (*safe*)
    "setsockopt", readsAll; (*safe*)
    "listen", readsAll; (*safe*)
    "getsockname", writes [1;3]; (*keep [1;3]*)
    "execl", readsAll; (*safe*)
    "select", writes [1;5]; (*keep [1;5]*)
    "accept", writesAll; (*keep [1]*)
    "getpeername", writes [1]; (*keep [1]*)
    "times", writesAll; (*unsafe*)
    "timespec_get", writes [1];
    "__tolower", readsAll; (*safe*)
    "signal", writesAll; (*unsafe*)
    "popen", readsAll; (*safe*)
    "BF_cfb64_encrypt", writes [1;3;4;5]; (*keep [1;3;4,5]*)
    "BZ2_bzBuffToBuffDecompress", writes [3;4]; (*keep [3;4]*)
    "uncompress", writes [3;4]; (*keep [3;4]*)
    "stat", writes [2]; (*keep [1]*)
    "__xstat", writes [3]; (*keep [1]*)
    "__lxstat", writes [3]; (*keep [1]*)
    "remove", readsAll;
    "BZ2_bzBuffToBuffCompress", writes [3;4]; (*keep [3;4]*)
    "compress2", writes [3]; (*keep [3]*)
    "__toupper", readsAll; (*safe*)
    "BF_set_key", writes [3]; (*keep [3]*)
    "memcmp", readsAll; (*safe*)
    "sendto", writes [2;4]; (*keep [2;4]*)
    "recvfrom", writes [4;5]; (*keep [4;5]*)
    "srand", readsAll; (*safe*)
    "gethostname", writesAll; (*unsafe*)
    "fork", readsAll; (*safe*)
    "setrlimit", readsAll; (*safe*)
    "getrlimit", writes [2]; (*keep [2]*)
    "sem_init", readsAll; (*safe*)
    "sem_destroy", readsAll; (*safe*)
    "sem_wait", readsAll; (*safe*)
    "sem_post", readsAll; (*safe*)
    "PL_NewHashTable", readsAll; (*safe*)
    "assert_failed", readsAll; (*safe*)
    "htonl", readsAll; (*safe*)
    "htons", readsAll; (*safe*)
    "ntohl", readsAll; (*safe*)
    "munmap", readsAll;(*safe*)
    "mmap", readsAll;(*safe*)
    "clock", readsAll;
    "__builtin_va_arg_pack_len", readsAll;
    "__open_too_many_args", readsAll;
    "usb_submit_urb", readsAll; (* first argument is written to but according to specification must not be read from anymore *)
    "dev_driver_string", readsAll;
    "__spin_lock_init", writes [1];
    "kmem_cache_create", readsAll;
    "idr_pre_get", readsAll;
    "zil_replay", writes [1;2;3;5];
    "__VERIFIER_nondet_int", readsAll; (* no args, declare invalidate actions to prevent invalidating globals when extern in regression tests *)
    (* no args, declare invalidate actions to prevent invalidating globals *)
    "isatty", readsAll;
    "setpriority", readsAll;
    "getpriority", readsAll;
    (* ddverify *)
    "sema_init", readsAll;
    "__goblint_assume_join", readsAll;
  ]

let () = List.iter (fun (x, _) ->
    if Hashtbl.exists (fun _ b -> List.mem_assoc x b) libraries then
      failwith ("You have added a function to invalidate_actions that already exists in libraries. Please undo this for function: " ^ x);
  ) invalidate_actions

(* used by get_invalidate_action to make sure
 * that hash of invalidates is built only once
 *
 * Hashtable from strings to functions of type (exp list -> exp list)
*)
let processed_table = ref None

let get_invalidate_action name =
  let tbl = match !processed_table with
    | None -> begin
        let hash = Hashtbl.create 113 in
        let f (k, v) = Hashtbl.add hash k v in
        List.iter f invalidate_actions;
        processed_table := (Some hash);
        hash
      end
    | Some x -> x
  in
  if Hashtbl.mem tbl name
  then Some (Hashtbl.find tbl name)
  else None


let lib_funs = ref (Set.String.of_list ["__raw_read_unlock"; "__raw_write_unlock"; "spin_trylock"])
let add_lib_funs funs = lib_funs := List.fold_right Set.String.add funs !lib_funs
let use_special fn_name = Set.String.mem fn_name !lib_funs

let kernel_safe_uncalled = Set.String.of_list ["__inittest"; "init_module"; "__exittest"; "cleanup_module"]
let kernel_safe_uncalled_regex = List.map Str.regexp ["__check_.*"]
let is_safe_uncalled fn_name =
  Set.String.mem fn_name kernel_safe_uncalled ||
  List.exists (fun r -> Str.string_match r fn_name 0) kernel_safe_uncalled_regex


let unknown_desc ~f name = (* TODO: remove name argument, unknown function shouldn't have classify *)
  let old_accesses (kind: AccessKind.t) args = match kind with
    | Write when GobConfig.get_bool "sem.unknown_function.invalidate.args" -> args
    | Write -> []
    | Read when GobConfig.get_bool "sem.unknown_function.read.args" -> args
    | Read -> []
    | Free -> []
    | Spawn when get_bool "sem.unknown_function.spawn" -> args
    | Spawn -> []
  in
  let attrs: LibraryDesc.attr list =
    if GobConfig.get_bool "sem.unknown_function.invalidate.globals" then
      [InvalidateGlobals]
    else
      []
  in
  let classify_name args =
    match classify name args with
    | `Unknown _ as category ->
      (* TODO: remove hack when all classify are migrated *)
      if not (CilType.Varinfo.equal f dummyFunDec.svar) && not (use_special f.vname) then
        M.error ~category:Imprecise ~tags:[Category Unsound] "Function definition missing for %s" f.vname;
      category
    | category -> category
  in
  LibraryDesc.of_old ~attrs old_accesses classify_name

let find f =
  let name = f.vname in
  match Hashtbl.find_option (ResettableLazy.force activated_library_descs) name with
  | Some desc -> desc
  | None ->
    match get_invalidate_action name with
    | Some old_accesses ->
      LibraryDesc.of_old old_accesses (classify name)
    | None ->
      unknown_desc ~f name


let is_special fv =
  if use_special fv.vname then
    true
  else
    match Cilfacade.find_varinfo_fundec fv with
    | _ -> false
    | exception Not_found -> true
