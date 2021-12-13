// PARAM: --set ana.activated "['base','threadid','threadflag','escape','uninit','mallocWrapper']"  --set exp.privatization none --enable annotation.int.enabled --set ana.int.refinement fixpoint
typedef struct {
	int i;
} S;

typedef struct {
	S s;
	int i;
} T;

void init_S(S *x) __attribute__((goblint_precision("def_exc"))) {
	x->i = 0;
}

S ret_S() __attribute__((goblint_precision("def_exc"))) {
	S y;
	y.i = 0;
	return y;
}

void mod_S1(S *z) __attribute__((goblint_precision("def_exc"))) {
	z->i = z->i + 1; //NOWARN
}

void mod_S2(S *z) __attribute__((goblint_precision("def_exc"))) {
	z->i = z->i + 1; //NOWARN
}

void mod_S31(S *z) __attribute__((goblint_precision("def_exc"))) {
	z->i = z->i + 1; //WARN
}

void mod_S32(S *z) __attribute__((goblint_precision("def_exc"))) {
	z->i = z->i + 1; //NOWARN
}

int main() __attribute__((goblint_precision("def_exc"))) {
	T tt1,tt2,tt3;
	int q = 0;

	init_S(&tt1.s);
	tt2.s = ret_S();

	mod_S1(&tt1.s); //NOWARN
	mod_S2(&tt2.s); //NOWARN
	mod_S31(&tt3.s); //NOWARN
	mod_S32(&tt3.s); //NOWARN

	q = tt1.s.i; //NOWARN
	q = tt2.s.i; //NOWARN
	q = tt3.s.i; //NOWARN

	q = tt1.i; //WARN
	q = tt2.i; //WARN
	q = tt3.i; //WARN

	return 0;
}
