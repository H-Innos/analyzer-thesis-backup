// PARAM: --set ana.activated[+] 'maylocks' --set ana.activated[+] 'pthreadMutexType'
#define _GNU_SOURCE
#include<pthread.h>
#include<stdio.h>
#include<unistd.h>
#include <assert.h>

int g;

void* f1(void* ptr) {
    pthread_mutex_t* mut = (pthread_mutex_t*) ptr;

    pthread_mutex_lock(mut);
    pthread_mutex_lock(mut); //WARN

    return NULL;
}


void* f2(void* ptr) {
    pthread_mutex_t* mut = (pthread_mutex_t*) ptr;

    pthread_mutex_lock(mut);
    pthread_mutex_unlock(mut);

    // default mutex type may be mapped to recursive, so shouldn't be removed, but Goblint assumes it to be non-recursive
    return NULL; // NOWARN (assumption)
}



int main(int argc, char const *argv[])
{
    pthread_t t1;
    pthread_t t2;
    pthread_mutex_t mut = PTHREAD_MUTEX_INITIALIZER;

    pthread_create(&t1,NULL,f1,&mut);


    pthread_mutex_lock(&mut);
    pthread_mutex_lock(&mut); //WARN


    pthread_join(t1, NULL);

    pthread_create(&t2,NULL,f2,&mut);

    return 0;
}
