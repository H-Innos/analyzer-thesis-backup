// The patch for this test case is empty on purpose. The problem described does occur in the incremental run even without any changes.
#include <assert.h>

int g = 1;

void f() {
    g = 2;
}

int main() {
    f();
    assert(g == 2); // unknown! before, unknown! after
    assert(g == 1); // unknown! before, unknown! after (when wrongly overriding the start state of start functions this did succeed in the incremental run)
    return 0;
}
