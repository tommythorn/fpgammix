long unsigned uninitialized;
long unsigned initialized = 27;
static long unsigned uninitialized_static;
static long unsigned initialized_static = 27;

extern long bar(long);

long foo(long x)
{
        return 2*bar(x+1);
}
