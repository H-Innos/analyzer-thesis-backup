// PARAM: --set ana.activated[+] "localTraces"
#include <goblint.h>
#include <pthread.h>
#include <stdio.h>

void *f_exit(void *arg) {
  int z = 12;
  pthread_exit(NULL);
}

void *f(void *arg) {
  int z = 9;
  pthread_t id_thread;
  pthread_create(&id_thread, NULL, &f_exit, NULL);

  pthread_join(id_thread, NULL);
  pthread_join(id_thread, NULL);  // WARN
}

int main() {
  int z = 0;
  pthread_t id_thread;
  pthread_t id_thread2;
  pthread_create(&id_thread, NULL, &f, NULL);
  return 0;
}