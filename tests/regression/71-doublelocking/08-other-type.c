// PARAM: --set ana.activated[+] 'maylocks' --set ana.activated[+] 'pthreadMutexType'
#define _GNU_SOURCE
#include<pthread.h>
#include<stdio.h>
#include<unistd.h>
#include <assert.h>


int g;

pthread_mutex_t mut = PTHREAD_MUTEX_INITIALIZER;

#ifndef __APPLE__
pthread_mutex_t mut2 = PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP;
pthread_mutex_t mut3 = PTHREAD_ERRORCHECK_MUTEX_INITIALIZER_NP;
#else
// OS X does not define PTHREAD_ERRORCHECK_MUTEX_INITIALIZER_NP
// we thus use the default one there, which should also create warnings
pthread_mutex_t mut3;
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

void* f2(void* ptr) {
    int top;

    g = 1;
    if(top) {
        pthread_mutex_lock(&mut3);
    }
    pthread_mutex_lock(&mut3); //WARN
    pthread_mutex_unlock(&mut3);
    return NULL;
}



int main(int argc, char const *argv[])
{
    pthread_t t1;
    pthread_t t2;

    pthread_create(&t1,NULL,f1,NULL);
    pthread_create(&t2,NULL,f2,NULL);
    pthread_join(t1, NULL);

#ifndef __APPLE__
    pthread_mutex_lock(&mut2); //NOWARN
    pthread_mutex_lock(&mut2); //NOWARN
    pthread_mutex_unlock(&mut2); //NOWARN
    pthread_mutex_unlock(&mut2);
#endif

    return 0;
}
