# Assumptions

Goblint makes the following (implicit) assumptions about the systems and programs it analyzes.

_NB! This list is likely incomplete._

1. `PTHREAD_MUTEX_DEFAULT` is a non-recursive mutex type.

    Although the [POSIX Programmer's Manual](https://linux.die.net/man/3/pthread_mutexattr_settype) states that

    > An implementation may map this mutex to one of the other mutex types.

    including `PTHREAD_MUTEX_RECURSIVE`, on Linux and OSX it seems to be mapped to `PTHREAD_MUTEX_NORMAL`.
    Goblint assumes this to be the case.

    This affects the `maylocks` analysis.

    See [PR #1414](https://github.com/goblint/analyzer/pull/1414).

