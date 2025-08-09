/* libc: Memory manipulation functions. */

#include <lib/libc.h>

#include "private/utils.h"

void *memcpy(void *dst, const void *src, uint32_t len)
{
    uint8_t *d8 = dst;
    const uint8_t *s8 = src;

    /* If source and destination are aligned to the same word boundary */
    if (((uint32_t) d8 & 3) == ((uint32_t) s8 & 3)) {
        /* Copy initial bytes until destination is word-aligned. */
        uint32_t bound = ALIGN4(d8);
        while (len && (uint32_t) d8 < bound) {
            *d8++ = *s8++;
            len--;
        }

        /* Word-aligned copy */
        uint32_t *d32 = (uint32_t *) d8;
        const uint32_t *s32 = (const uint32_t *) s8;
        while (len >= 4) {
            *d32++ = *s32++;
            len -= 4;
        }

        /* Back to byte copy for any remaining bytes */
        d8 = (uint8_t *) d32;
        s8 = (const uint8_t *) s32;
    }

    /* Byte-by-byte copy for any remaining bytes or if not word-aligned */
    while (len--)
        *d8++ = *s8++;
    return dst;
}

void *memmove(void *dst, const void *src, uint32_t len)
{
    /* If no overlap, use memcpy */
    if (dst <= src || (uintptr_t) dst >= (uintptr_t) src + len)
        return memcpy(dst, src, len);

    /* Otherwise, copy backwards to handle overlap */
    uint8_t *d8 = (uint8_t *) dst + len;
    const uint8_t *s8 = (const uint8_t *) src + len;

    /* If source and destination are aligned to the same word boundary */
    if (((uint32_t) d8 & 3) == ((uint32_t) s8 & 3)) {
        /* Copy initial bytes backwards until destination is word-aligned. */
        uint32_t bound = ALIGN4(d8);
        while (len && (uint32_t) d8 > bound) {
            *--d8 = *--s8;
            len--;
        }

        /* Word-aligned copy backwards */
        uint32_t *d32 = (uint32_t *) d8;
        const uint32_t *s32 = (const uint32_t *) s8;
        while (len >= 4) {
            *--d32 = *--s32;
            len -= 4;
        }

        /* Back to byte copy for any remaining bytes */
        d8 = (uint8_t *) d32;
        s8 = (const uint8_t *) s32;
    }

    /* Byte-by-byte copy backwards for any remaining bytes */
    while (len--)
        *--d8 = *--s8;
    return dst;
}

void *memset(void *dst, int32_t c, uint32_t len)
{
    uint8_t *d8 = dst;
    /* Create a 32-bit word filled with the character 'c' */
    uint32_t word = (uint8_t) c;
    word |= word << 8;
    word |= word << 16;

    /* Copy initial bytes until destination is word-aligned. */
    uint32_t bound = ALIGN4(d8);
    while (len && (uint32_t) d8 < bound) {
        *d8++ = (uint8_t) c;
        len--;
    }

    /* Word-aligned fill */
    uint32_t *d32 = (uint32_t *) d8;
    while (len >= 4) {
        *d32++ = word;
        len -= 4;
    }

    /* Byte-by-byte fill for any remaining bytes */
    d8 = (uint8_t *) d32;
    while (len--)
        *d8++ = (uint8_t) c;
    return dst;
}

/* Compares two memory blocks byte by byte. */
int32_t memcmp(const void *cs, const void *ct, uint32_t n)
{
    char *r1 = (char *) cs;
    char *r2 = (char *) ct;

    /* Compare bytes until a difference is found or n bytes are processed. */
    while (n && (*r1 == *r2)) {
        ++r1;
        ++r2;
        --n;
    }

    /* Return 0 if all n bytes matched, otherwise the difference of the first
     * mismatching bytes.
     */
    return (n == 0) ? 0 : ((*r1 < *r2) ? -1 : 1);
}
