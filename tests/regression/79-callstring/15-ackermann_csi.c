// PARAM: --set ana.context.callString_length 2 --set "ana.activated[+]" call_site --set ana.ctx_sens "['call_site']" --enable ana.int.interval_set

int ack(int n, int m)
{
    if (n == 0)
    {
        return m + 1;
    }
    else
    {
        if (m == 0)
        {
            return ack(n - 1, 1);
        }
        else
        {
            return ack(n - 1, ack(n, m - 1));
        }
    }
}

int main(void)
{
    // main -> ack -> ack -> ...
    ack(4, 1);
    __goblint_check(1); // reachable
}