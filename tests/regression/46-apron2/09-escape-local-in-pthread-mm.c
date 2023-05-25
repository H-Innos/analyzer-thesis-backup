// SKIP PARAM: --set ana.activated[+] apron --set ana.base.privatization none --set ana.relation.privatization mutex-meet
// Copy of 45 01 for apron
#include <pthread.h>
#include <goblint.h>
#include <stdio.h>
#include <unistd.h>


void *foo(void* p){
    sleep(2);
    int* ip = *((int**) p);
    printf("ip is %d\n", *ip);
    *ip = 42;
    return NULL;
}

int main(){
    int x = 0;
    int *xp = &x;
    int** ptr = &xp;
    int x2 = 35;
    pthread_t thread;
    pthread_create(&thread, NULL, foo, ptr);
    __goblint_check(x2 == 35);
    *ptr = &x2;
    sleep(4); // to make sure that we actually fail the assert when running.
    __goblint_check(x2 == 42); //UNKNOWN!
    __goblint_check(x2 == 35); //UNKNOWN!
    pthread_join(thread, NULL);
    return 0;
}
