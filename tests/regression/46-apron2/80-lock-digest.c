// SKIP PARAM: --set ana.activated[+] apron --set ana.relation.privatization mutex-meet-tid --set ana.path_sens[+] threadflag
// cherry-picked from https://github.com/goblint/analyzer/pull/1286: works with mutex-meet-tid, without lock digests
#include <pthread.h>
#include <goblint.h>

int g, h;
pthread_mutex_t a = PTHREAD_MUTEX_INITIALIZER;

void *t2(void *arg) {
  pthread_mutex_lock(&a);
  // wrong in more-traces!
  __goblint_check(h < g);
  pthread_mutex_unlock(&a);
  return NULL;
}

void *t1(void *arg) {
  pthread_t x;
  pthread_create(&x, NULL, t2, NULL);

  pthread_mutex_lock(&a);
  h = 11; g = 12;
  pthread_mutex_unlock(&a);
  return NULL;
}

void *t0(void *arg) {
  return NULL;
}

int main() {
  pthread_t x;
  pthread_create(&x, NULL, t0, NULL); // go multithreaded

  pthread_mutex_lock(&a);
  h = 9;
  g = 10;
  pthread_mutex_unlock(&a);

  pthread_create(&x, NULL, t1, NULL);
  return 0;
}
