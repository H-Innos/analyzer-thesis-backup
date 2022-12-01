#include <pthread.h>
#include <stdio.h>

#ifdef __APPLE__
  int main(void) {
    // OS X has no spin_lock
    int x =5; //NORACE
  }
#else
  int myglobal;
  pthread_spinlock_t spinlock1;
  pthread_spinlock_t spinlock2;

  void *t_fun(void *arg) {
    pthread_spin_lock(&spinlock1);
    myglobal=myglobal+1; // NORACE
    pthread_spin_unlock(&spinlock1);
    return NULL;
  }

  int main(void) {
    pthread_t id;
    pthread_create(&id, NULL, t_fun, NULL);
    pthread_spin_lock(&spinlock1);
    myglobal=myglobal+1; // NORACE
    pthread_spin_unlock(&spinlock1);
    pthread_join (id, NULL);
    return 0;
  }
#endif
