//PARAM: --enable modular --set ana.modular.funs "['five', 'write_arg']" --set ana.activated[+] "'modular_queries'" --set ana.activated[+] "'is_modular'" --set ana.activated[+] "'written'" --set ana.activated[+] "'read'" --set ana.activated[+] "'used_globals'" --set ana.activated[+] "'startstate'"
#include<goblint.h>

int five(){
    return 5;
}

void write_arg(int *x){
    *x = five();
}

void main(){
    int x = 3;
    __goblint_check(x == 3);
    write_arg(&x);
    __goblint_check(x != 3); //UNKNOWN
    __goblint_check(x == 5); //UNKNOWN
}
