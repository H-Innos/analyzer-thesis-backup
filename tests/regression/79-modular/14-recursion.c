//PARAM: --set ana.modular.funs "['fib']" --set ana.activated[+] "'modular_queries'" --set ana.activated[+] "'is_modular'" --set ana.activated[+] "'written'" --set ana.activated[+] "'read'"  --set ana.activated[+] "'used_globals'"

#include<goblint.h>

int fib(int *n, int* acc){
	if(*n == 0){
		return *acc;
	} else {
		*acc = (*acc) * (*n);
		*n = (*n) - 1;
		fib(n, acc);
	}
}

int main(){
	int n = 10;
	int acc = 1;

	__goblint_check(n == 10);
	__goblint_check(acc == 1);
	fib(&n, &acc);
	__goblint_check(n != 10); //UNKNOWN
	__goblint_check(acc != 1); //UNKNOWN
	return 0;
}
