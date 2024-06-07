// PARAM: --set ana.path_sens[+] threadflag --set ana.base.privatization mutex-meet-tid --enable ana.int.interval --set ana.activated[+] threadJoins
#include <pthread.h>
#include <goblint.h>

int g = 10;

pthread_mutex_t A = PTHREAD_MUTEX_INITIALIZER;

void* t_other(void *arg) {
  g = 60;
}

void *t_benign(void *arg) {
  pthread_mutex_lock(&A);
  g = 10;
  __goblint_check(g == 10); //UNKNOWN!
  pthread_mutex_unlock(&A);


  pthread_t id2;
  pthread_create(&id2, NULL, t_other, NULL);

  return NULL;
}

int main(void) {

  pthread_t id2;
  pthread_create(&id2, NULL, t_benign, NULL);
  pthread_join(id2, NULL);


  g = 20;
  __goblint_check(g == 20); //UNKNOWN!

  pthread_mutex_lock(&A);
  __goblint_check(g == 20); //UNKNOWN!
  pthread_mutex_unlock(&A);

  return 0;
}
