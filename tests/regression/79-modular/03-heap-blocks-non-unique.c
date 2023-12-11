//PARAM: --enable modular --enable ana.modular.auto-funs --set ana.activated[+] "'modular_queries'" --set ana.activated[+] "'is_modular'" --set ana.activated[+] "'written'" --set ana.activated[+] "'read'"  --set ana.activated[+] "'used_globals'"
#include <goblint.h>
#include <stdlib.h>

typedef struct node {
  int data;
  struct node *next;
} node_t;

void list_op(node_t *n){
	// Check that modular analysis does not assume that the type-based objects are unique
	__goblint_check(n->next == n); //UNKNOWN!
}

void list_op2(node_t *n, node_t *m){
	__goblint_check(n == m); //UNKNOWN!
	__goblint_check(n->next == m); //UNKNOWN!
	__goblint_check(m->next == n); //UNKNOWN!
	__goblint_check(n->next == m->next); //UNKNOWN!
}
