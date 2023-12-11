//SKIP PARAM: --enable modular --enable ana.modular.auto-funs --set ana.activated[+] "'modular_queries'" --set ana.activated[+] "'is_modular'" --set ana.activated[+] "'written'" --set ana.activated[+] "'read'"  --set ana.activated[+] "'used_globals'" --enable ana.int.interval
#include<goblint.h>
#include<stdlib.h>

typedef struct node {
    struct node* next;
    int value;
} node_t;

node_t *allocate_node(){
    // Changing the pointer type to node_t* resolves the issue
    node_t* n = malloc(sizeof(node_t));
    return (node_t*) n;
}

node_t *init_node(node_t *n){
    if(n != NULL){
        n->value = 0;
        n->next = NULL;
    }
    return n;
}

node_t *add_node(node_t *n){
    if(n != NULL){
        node_t *new_node = allocate_node();
        __goblint_check(new_node != NULL);

        init_node(new_node);
        __goblint_check(new_node != NULL);

        n->next = new_node;
        __goblint_check(n->next != NULL); //UNKNOWN!

        new_node = init_node(new_node);
        __goblint_check(new_node != NULL); //UNKNOWN
    }
}
