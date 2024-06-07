// PARAM: --set ana.activated[+] 'maylocks' --set ana.activated[+] 'pthreadMutexType'
#define _GNU_SOURCE
#include<pthread.h>
#include<stdio.h>
#include<unistd.h>
#include <assert.h>


int g;

pthread_mutex_t mut = PTHREAD_MUTEX_INITIALIZER;

#ifdef __APPLE__
pthread_mutex_t mut2 = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;
#else
pthread_mutex_t mut2 = PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP;
#endif


void* f1(void* ptr) {
    int top;

    g = 1;
    if(top) {
        pthread_mutex_lock(&mut);
    }
    pthread_mutex_lock(&mut); //WARN
    pthread_mutex_unlock(&mut);
    return NULL;
}


int main(int argc, char const *argv[])
{
    pthread_t t1;
    pthread_t t2;

    pthread_create(&t1,NULL,f1,NULL);
    pthread_join(t1, NULL);

    pthread_mutex_lock(&mut2); //NOWARN
    pthread_mutex_lock(&mut2); //NOWARN
    pthread_mutex_unlock(&mut2);
    pthread_mutex_unlock(&mut2);

    return 0;
}
