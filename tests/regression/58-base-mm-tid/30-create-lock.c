// PARAM: --set ana.path_sens[+] threadflag --set ana.base.privatization mutex-meet-tid --enable ana.int.interval --set ana.activated[+] threadJoins
#include <pthread.h>
#include <goblint.h>

int g = 10;

pthread_mutex_t A = PTHREAD_MUTEX_INITIALIZER;


void *t_benign(void *arg) {
  return NULL;
}

void *t_benign2(void *arg) {
  pthread_mutex_lock(&A);
  int x =  g == 40; // For evaluations that happen before the side-effect of the unlock of A, g is bot and the exception is caught by eval_rv
  __goblint_check(x); //UNKNOWN!
  return NULL;
}

int main(void) {

  pthread_t id2;
  pthread_create(&id2, NULL, t_benign, NULL);
  pthread_join(id2, NULL);

  pthread_mutex_lock(&A);
  g = 30;
  pthread_create(&id2, NULL, t_benign2, NULL);
  g = 40;
  pthread_mutex_unlock(&A);

  return 0;
}
