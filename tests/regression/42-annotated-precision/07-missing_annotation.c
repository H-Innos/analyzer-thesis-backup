// PARAM: --enable annotation.int.enabled --set ana.int.refinement fixpoint

int f(int in) __attribute__((goblint_precision("def_exc"))) {
  return in + 1;
}

int main() __attribute__((goblint_precision("no-def_exc"))) {
  int a = 1;
  assert(a); // UNKNOWN!
  a = f(a);
  return 0;
}