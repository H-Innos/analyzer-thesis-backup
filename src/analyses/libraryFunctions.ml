(** Tools for dealing with library functions. *)

open Prelude.Ana
open GobConfig

module M = Messages

(** C standard library functions.
    These are specified by the C standard. *)
let c_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("memset", special [__ "dest" [w]; __ "ch" []; __ "count" []] @@ fun dest ch count -> Memset { dest; ch; count; });
    ("__builtin_memset", special [__ "dest" [w]; __ "ch" []; __ "count" []] @@ fun dest ch count -> Memset { dest; ch; count; });
    ("__builtin___memset_chk", special [__ "dest" [w]; __ "ch" []; __ "count" []; drop "os" []] @@ fun dest ch count -> Memset { dest; ch; count; });
    ("malloc", special [__ "size" []] @@ fun size -> Malloc size);
    ("realloc", special [__ "ptr" [r; f]; __ "size" []] @@ fun ptr size -> Realloc { ptr; size });
    ("abort", special [] Abort);
    ("exit", special [drop "exit_code" []] Abort);
    ("assert", special [__ "cond" [r]] @@ fun cond -> Assert cond);
  ]

(** C POSIX library functions.
    These are {e not} specified by the C standard, but available on POSIX systems. *)
let posix_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("bzero", special [__ "dest" [w]; __ "count" []] @@ fun dest count -> Bzero { dest; count; });
    ("__builtin_bzero", special [__ "dest" [w]; __ "count" []] @@ fun dest count -> Bzero { dest; count; });
    ("explicit_bzero", special [__ "dest" [w]; __ "count" []] @@ fun dest count -> Bzero { dest; count; });
    ("__explicit_bzero_chk", special [__ "dest" [w]; __ "count" []; drop "os" []] @@ fun dest count -> Bzero { dest; count; });
  ]

(** Pthread functions. *)
let pthread_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("pthread_create", special [__ "thread" [w]; drop "attr" [r]; __ "start_routine" [s]; __ "arg" []] @@ fun thread start_routine arg -> ThreadCreate { thread; start_routine; arg }); (* For precision purposes arg is not considered accessed here. Instead all accesses (if any) come from actually analyzing start_routine. *)
    ("pthread_exit", special [__ "retval" []] @@ fun retval -> ThreadExit { ret_val = retval }); (* Doesn't dereference the void* itself, but just passes to pthread_join. *)
  ]

(** GCC builtin functions.
    These are not builtin versions of functions from other lists. *)
let gcc_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("__builtin_object_size", unknown [drop "ptr" [r]; drop' []]);
  ]

(** Linux kernel functions. *)
let linux_descs_list: (string * LibraryDesc.t) list = (* LibraryDsl. *) [

  ]

(** Goblint functions. *)
let goblint_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("__goblint_unknown", unknown [drop' [w]]);
    ("__goblint_check", unknown [drop' []]);
    ("__goblint_commit", unknown [drop' []]);
    ("__goblint_assert", unknown [drop' []]);
  ]

(** zstd functions.
    Only used with extraspecials. *)
let zstd_descs_list: (string * LibraryDesc.t) list = LibraryDsl.[
    ("ZSTD_customMalloc", special [__ "size" []; drop "customMem" [r]] @@ fun size -> Malloc size);
    ("ZSTD_customCalloc", special [__ "size" []; drop "customMem" [r]] @@ fun size -> Calloc { size; count = Cil.one });
    ("ZSTD_customFree", unknown [drop "ptr" [f]; drop "customMem" [r]]);
  ]

(* TODO: allow selecting which lists to use *)
let library_descs = Hashtbl.of_list (List.concat [
    c_descs_list;
    posix_descs_list;
    pthread_descs_list;
    gcc_descs_list;
    linux_descs_list;
    goblint_descs_list;
    zstd_descs_list;
  ])


type categories = [
  | `Malloc       of exp
  | `Calloc       of exp * exp
  | `Realloc      of exp * exp
  | `Assert       of exp
  | `Lock         of bool * bool * bool  (* try? * write? * return  on success *)
  | `Unlock
  | `ThreadCreate of exp * exp * exp (* id * f  * x       *)
  | `ThreadJoin   of exp * exp (* id * ret_var *)
  | `Unknown      of string ]


let classify fn exps: categories =
  let strange_arguments () =
    M.warn "%s arguments are strange!" fn;
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
  | "_spin_trylock" | "spin_trylock" | "mutex_trylock" | "_spin_trylock_irqsave"
  | "down_trylock"
    -> `Lock(true, true, true)
  | "pthread_mutex_trylock" | "pthread_rwlock_trywrlock"
    -> `Lock (true, true, false)
  | "LAP_Se_WaitSemaphore" (* TODO: only handle those when arinc analysis is enabled? *)
  | "_spin_lock" | "_spin_lock_irqsave" | "_spin_lock_bh" | "down_write"
  | "mutex_lock" | "mutex_lock_interruptible" | "_write_lock" | "_raw_write_lock"
  | "pthread_rwlock_wrlock" | "GetResource" | "_raw_spin_lock"
  | "_raw_spin_lock_flags" | "_raw_spin_lock_irqsave" | "_raw_spin_lock_irq" | "_raw_spin_lock_bh"
  | "spin_lock_irqsave" | "spin_lock"
    -> `Lock (get_bool "sem.lock.fail", true, true)
  | "pthread_mutex_lock" | "__pthread_mutex_lock"
    -> `Lock (get_bool "sem.lock.fail", true, false)
  | "pthread_rwlock_tryrdlock" | "pthread_rwlock_rdlock" | "_read_lock"  | "_raw_read_lock"
  | "down_read"
    -> `Lock (get_bool "sem.lock.fail", false, true)
  | "LAP_Se_SignalSemaphore"
  | "__raw_read_unlock" | "__raw_write_unlock"  | "raw_spin_unlock"
  | "_spin_unlock" | "spin_unlock" | "_spin_unlock_irqrestore" | "_spin_unlock_bh" | "_raw_spin_unlock_bh"
  | "mutex_unlock" | "_write_unlock" | "_read_unlock" | "_raw_spin_unlock_irqrestore"
  | "pthread_mutex_unlock" | "__pthread_mutex_unlock" | "spin_unlock_irqrestore" | "up_read" | "up_write"
  | "up"
    -> `Unlock
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
    "__builtin_ctz", readsAll;
    "__builtin_ctzl", readsAll;
    "__builtin_ctzll", readsAll;
    "__builtin_clz", readsAll;
    "connect", readsAll;          (*safe*)
    "fclose", readsAll;           (*safe*)
    "fflush", writesAll;          (*unsafe*)
    "fopen", readsAll;            (*safe*)
    "fdopen", readsAll;           (*safe*)
    "setvbuf", writes[1;2];       (* TODO: if this is used to set an input buffer, the buffer (second argument) would need to remain TOP, *)
                                  (* as any future write (or flush) of the stream could result in a write to the buffer *)
    "fprintf", writes [1];          (*keep [1]*)
    "__fprintf_chk", writes [1];    (*keep [1]*)
    "fread", writes [1;4];
    "__fread_alias", writes [1;4];
    "__fread_chk", writes [1;4];
    "utimensat", readsAll;
    "free", frees [1]; (*unsafe*)
    "fwrite", readsAll;(*safe*)
    "getopt", writes [2];(*keep [2]*)
    "localtime", readsAll;(*safe*)
    "memcpy", writes [1];(*keep [1]*)
    "__builtin_memcpy", writes [1];(*keep [1]*)
    "mempcpy", writes [1];(*keep [1]*)
    "__builtin___memcpy_chk", writes [1];
    "__builtin___mempcpy_chk", writes [1];
    "printf", readsAll;(*safe*)
    "__printf_chk", readsAll;(*safe*)
    "printk", readsAll;(*safe*)
    "perror", readsAll;(*safe*)
    "pthread_mutex_lock", readsAll;(*safe*)
    "pthread_mutex_trylock", readsAll;
    "pthread_mutex_unlock", readsAll;(*safe*)
    "__pthread_mutex_lock", readsAll;(*safe*)
    "__pthread_mutex_trylock", readsAll;
    "__pthread_mutex_unlock", readsAll;(*safe*)
    "__mutex_init", readsAll;(*safe*)
    "mutex_init", readsAll;(*safe*)
    "mutex_lock", readsAll;(*safe*)
    "mutex_lock_interruptible", readsAll;(*safe*)
    "mutex_unlock", readsAll;(*safe*)
    "_spin_lock", readsAll;(*safe*)
    "_spin_unlock", readsAll;(*safe*)
    "_spin_lock_irqsave", readsAll;(*safe*)
    "_spin_unlock_irqrestore", readsAll;(*safe*)
    "pthread_mutex_init", readsAll;(*safe*)
    "pthread_mutex_destroy", readsAll;(*safe*)
    "pthread_mutexattr_settype", readsAll;(*safe*)
    "pthread_mutexattr_init", readsAll;(*safe*)
    "pthread_self", readsAll;(*safe*)
    "read", writes [2];(*keep [2]*)
    "recv", writes [2];(*keep [2]*)
    "scanf",  writesAllButFirst 1 readsAll;(*drop 1*)
    "send", readsAll;(*safe*)
    "snprintf", writes [1];(*keep [1]*)
    "__builtin___snprintf_chk", writes [1];(*keep [1]*)
    "sprintf", writes [1];(*keep [1]*)
    "sscanf", writesAllButFirst 2 readsAll;(*drop 2*)
    "strcmp", readsAll;(*safe*)
    "strftime", writes [1];(*keep [1]*)
    "strlen", readsAll;(*safe*)
    "strncmp", readsAll;(*safe*)
    "strncpy", writes [1];(*keep [1]*)
    "strncat", writes [1];(*keep [1]*)
    "strstr", readsAll;(*safe*)
    "strdup", readsAll;(*safe*)
    "toupper", readsAll;(*safe*)
    "tolower", readsAll;(*safe*)
    "time", writesAll;(*unsafe*)
    "vfprintf", writes [1];(*keep [1]*)
    "__vfprintf_chk", writes [1];(*keep [1]*)
    "vprintf", readsAll;(*safe*)
    "vsprintf", writes [1];(*keep [1]*)
    "write", readsAll;(*safe*)
    "__builtin_va_arg", readsAll;(*safe*)
    "__builtin_va_end", readsAll;(*safe*)
    "__builtin_va_start", readsAll;(*safe*)
    "__ctype_b_loc", readsAll;(*safe*)
    "__errno", readsAll;(*safe*)
    "__errno_location", readsAll;(*safe*)
    "sigfillset", writesAll; (*unsafe*)
    "sigprocmask", writesAll; (*unsafe*)
    "uname", writesAll;(*unsafe*)
    "__builtin_strcmp", readsAll;(*safe*)
    "getopt_long", writesAllButFirst 2 readsAll;(*drop 2*)
    "__strdup", readsAll;(*safe*)
    "strtoul__extinline", readsAll;(*safe*)
    "strtol", writes [2];
    "geteuid", readsAll;(*safe*)
    "opendir", readsAll;  (*safe*)
    "readdir_r", writesAll;(*unsafe*)
    "atoi__extinline", readsAll;(*safe*)
    "getpid", readsAll;(*safe*)
    "fgetc", writesAll;(*unsafe*)
    "getc", writesAll;(*unsafe*)
    "_IO_getc", writesAll;(*unsafe*)
    "closedir", writesAll;(*unsafe*)
    "setrlimit", readsAll;(*safe*)
    "chdir", readsAll;(*safe*)
    "pipe", writesAll;(*unsafe*)
    "close", writesAll;(*unsafe*)
    "setsid", readsAll;(*safe*)
    "strerror_r", writesAll;(*unsafe*)
    "pthread_attr_init", writesAll; (*unsafe*)
    "pthread_attr_setdetachstate", writesAll;(*unsafe*)
    "pthread_attr_setstacksize", writesAll;(*unsafe*)
    "pthread_attr_setscope", writesAll;(*unsafe*)
    "pthread_attr_getdetachstate", readsAll;(*safe*)
    "pthread_attr_getstacksize", readsAll;(*safe*)
    "pthread_attr_getscope", readsAll;(*safe*)
    "pthread_cond_init", readsAll; (*safe*)
    "pthread_cond_wait", readsAll; (*safe*)
    "pthread_cond_signal", readsAll;(*safe*)
    "pthread_cond_broadcast", readsAll;(*safe*)
    "pthread_cond_destroy", readsAll;(*safe*)
    "__pthread_cond_init", readsAll; (*safe*)
    "__pthread_cond_wait", readsAll; (*safe*)
    "__pthread_cond_signal", readsAll;(*safe*)
    "__pthread_cond_broadcast", readsAll;(*safe*)
    "__pthread_cond_destroy", readsAll;(*safe*)
    "pthread_key_create", writesAll;(*unsafe*)
    "sigemptyset", writesAll;(*unsafe*)
    "sigaddset", writesAll;(*unsafe*)
    "pthread_sigmask", writesAllButFirst 2 readsAll;(*unsafe*)
    "raise", writesAll;(*unsafe*)
    "_strlen", readsAll;(*safe*)
    "__builtin_alloca", readsAll;(*safe*)
    "dlopen", readsAll;(*safe*)
    "dlsym", readsAll;(*safe*)
    "dlclose", readsAll;(*safe*)
    "dlerror", readsAll;(*safe*)
    "stat__extinline", writesAllButFirst 1 readsAll;(*drop 1*)
    "lstat__extinline", writesAllButFirst 1 readsAll;(*drop 1*)
    "__builtin_strchr", readsAll;(*safe*)
    "strcpy", writes [1];(*keep [1]*)
    "__builtin___strcpy", writes [1];(*keep [1]*)
    "__builtin___strcpy_chk", writes [1];(*keep [1]*)
    "strcat", writes [1];(*keep [1]*)
    "strtok", readsAll;(*safe*)
    "getpgrp", readsAll;(*safe*)
    "umount2", readsAll;(*safe*)
    "memchr", readsAll;(*safe*)
    "memmove", writes [2;3];(*keep [2;3]*)
    "__builtin_memmove", writes [2;3];(*keep [2;3]*)
    "__builtin___memmove_chk", writes [2;3];(*keep [2;3]*)
    "waitpid", readsAll;(*safe*)
    "statfs", writes [1;3;4];(*keep [1;3;4]*)
    "mkdir", readsAll;(*safe*)
    "mount", readsAll;(*safe*)
    "open", readsAll;(*safe*)
    "__open_alias", readsAll;(*safe*)
    "__open_2", readsAll;(*safe*)
    "fcntl", readsAll;(*safe*)
    "ioctl", writesAll;(*unsafe*)
    "fstat__extinline", writesAll;(*unsafe*)
    "umount", readsAll;(*safe*)
    "rmdir", readsAll;(*safe*)
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
    "syscall", writesAllButFirst 1 readsAll;(*drop 1*)
    "sysconf", readsAll;
    "fputs", readsAll;(*safe*)
    "fputc", readsAll;(*safe*)
    "fseek", writes[1];
    "rewind", writesAll;
    "fileno", readsAll;
    "ferror", readsAll;
    "ftell", readsAll;
    "putc", readsAll;(*safe*)
    "putw", readsAll;(*safe*)
    "putchar", readsAll;(*safe*)
    "getchar", readsAll;(*safe*)
    "feof", readsAll;(*safe*)
    "__getdelim", writes [3];(*keep [3]*)
    "vsyslog", readsAll;(*safe*)
    "gethostbyname_r", readsAll;(*safe*)
    "__h_errno_location", readsAll;(*safe*)
    "__fxstat", readsAll;(*safe*)
    "getuid", readsAll;(*safe*)
    "strerror", readsAll;(*safe*)
    "readdir", readsAll;(*safe*)
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
    "__builtin_expect", readsAll; (*safe*)
    "vsnprintf", writesAllButFirst 3 readsAll; (*drop 3*)
    "__builtin___vsnprintf", writesAllButFirst 3 readsAll; (*drop 3*)
    "__builtin___vsnprintf_chk", writesAllButFirst 3 readsAll; (*drop 3*)
    "syslog", readsAll; (*safe*)
    "strcasecmp", readsAll; (*safe*)
    "strchr", readsAll; (*safe*)
    "getservbyname", readsAll; (*safe*)
    "__error", readsAll; (*safe*)
    "__maskrune", writesAll; (*unsafe*)
    "inet_addr", readsAll; (*safe*)
    "gethostbyname", readsAll; (*safe*)
    "setsockopt", readsAll; (*safe*)
    "listen", readsAll; (*safe*)
    "getsockname", writes [1;3]; (*keep [1;3]*)
    "getenv", readsAll; (*safe*)
    "execl", readsAll; (*safe*)
    "select", writes [1;5]; (*keep [1;5]*)
    "accept", writesAll; (*keep [1]*)
    "getpeername", writes [1]; (*keep [1]*)
    "times", writesAll; (*unsafe*)
    "timespec_get", writes [1];
    "fgets", writes [1;3]; (*keep [3]*)
    "__fgets_alias", writes [1;3]; (*keep [3]*)
    "__fgets_chk", writes [1;3]; (*keep [3]*)
    "strtoul", readsAll; (*safe*)
    "__tolower", readsAll; (*safe*)
    "signal", writesAll; (*unsafe*)
    "strsignal", readsAll;
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
    "rand", readsAll; (*safe*)
    "gethostname", writesAll; (*unsafe*)
    "fork", readsAll; (*safe*)
    "setrlimit", readsAll; (*safe*)
    "getrlimit", writes [2]; (*keep [2]*)
    "sem_init", readsAll; (*safe*)
    "sem_destroy", readsAll; (*safe*)
    "sem_wait", readsAll; (*safe*)
    "sem_post", readsAll; (*safe*)
    "PL_NewHashTable", readsAll; (*safe*)
    "__assert_fail", readsAll; (*safe*)
    "assert_failed", readsAll; (*safe*)
    "htonl", readsAll; (*safe*)
    "htons", readsAll; (*safe*)
    "ntohl", readsAll; (*safe*)
    "htons", readsAll; (*safe*)
    "munmap", readsAll;(*safe*)
    "mmap", readsAll;(*safe*)
    "clock", readsAll;
    "pthread_rwlock_wrlock", readsAll;
    "pthread_rwlock_trywrlock", readsAll;
    "pthread_rwlock_rdlock", readsAll;
    "pthread_rwlock_tryrdlock", readsAll;
    "pthread_rwlockattr_destroy", writesAll;
    "pthread_rwlockattr_init", writesAll;
    "pthread_rwlock_destroy", readsAll;
    "pthread_rwlock_init", readsAll;
    "pthread_rwlock_unlock", readsAll;
    "__builtin_bswap16", readsAll;
    "__builtin_bswap32", readsAll;
    "__builtin_bswap64", readsAll;
    "__builtin_bswap128", readsAll;
    "__builtin_va_arg_pack_len", readsAll;
    "__open_too_many_args", readsAll;
    "usb_submit_urb", readsAll; (* first argument is written to but according to specification must not be read from anymore *)
    "dev_driver_string", readsAll;
    "dev_driver_string", readsAll;
    "__spin_lock_init", writes [1];
    "kmem_cache_create", readsAll;
    "__builtin_prefetch", readsAll;
    "idr_pre_get", readsAll;
    "zil_replay", writes [1;2;3;5];
    "__VERIFIER_nondet_int", readsAll; (* no args, declare invalidate actions to prevent invalidating globals when extern in regression tests *)
    (* no args, declare invalidate actions to prevent invalidating globals *)
    "__VERIFIER_atomic_begin", readsAll;
    "__VERIFIER_atomic_end", readsAll;
    (* prevent base from spawning ARINC processes early, handled by arinc/extract_arinc *)
    (* "LAP_Se_SetPartitionMode", writes [2]; *)
    "LAP_Se_CreateProcess", writes [2; 3];
    "LAP_Se_CreateErrorHandler", writes [2; 3];
    "isatty", readsAll;
    "setpriority", readsAll;
    "getpriority", readsAll;
    (* ddverify *)
    "spin_lock_init", readsAll;
    "spin_lock", readsAll;
    "spin_unlock", readsAll;
    "spin_unlock_irqrestore", readsAll;
    "spin_lock_irqsave", readsAll;
    "sema_init", readsAll;
    "down_trylock", readsAll;
    "up", readsAll;
    "__goblint_assume_join", readsAll;
  ]


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

let effects: (string -> Cil.exp list -> (Cil.lval * ValueDomain.Compound.t) list option) list ref = ref []
let add_effects f = effects := f :: !effects
let effects_for fname args = List.filter_map (fun f -> f fname args) !effects

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
  match Hashtbl.find_option library_descs name with
  | Some desc -> desc
  | None ->
    match get_invalidate_action name with
    | Some old_accesses ->
      LibraryDesc.of_old old_accesses (classify name)
    | None ->
      unknown_desc ~f name