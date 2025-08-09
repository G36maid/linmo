/* libc: Math function. */

#include <lib/libc.h>

/* Returns the absolute value of an integer. */
int32_t abs(int32_t n)
{
    return n >= 0 ? n : -n;
}
