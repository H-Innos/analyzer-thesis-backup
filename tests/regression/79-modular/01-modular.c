//PARAM: --enable modular --enable ana.modular.auto-funs --set ana.activated[+] "'modular_queries'" --set ana.activated[+] "'is_modular'" --set ana.activated[+] "'written'" --set ana.activated[+] "'read'"  --set ana.activated[+] "'used_globals'"

#include <goblint.h>

void foo(){
	// Check that the modular analysis analyizes function even when not called from main
	__goblint_check(1);
}

void bar(){
	// Check that the modular analysis analyizes function even when not called from main
	__goblint_check(1);
}
