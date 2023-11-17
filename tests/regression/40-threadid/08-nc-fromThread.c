// PARAM: --disable ana.thread.context.create-edges
#include <goblint.h>
#include <pthread.h>

int glob;

void *t_norace(void *arg) {
  glob = 1; //NORACE
}

void *t_other(void *arg) {
}

int create_other () {
  pthread_t id;
  pthread_create(&id, NULL, t_other, NULL);
}

void *t_fun(void *arg) {
  create_other();

  glob = 2; //NORACE

  pthread_t id;
  pthread_create(&id, NULL, t_norace, NULL);

  create_other();
}

int main() {
  pthread_t id;
  pthread_create(&id, NULL, t_fun, NULL);

  create_other();
}
