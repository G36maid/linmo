#pragma once

#include <hal.h>

#ifndef NULL
#define NULL ((void *) 0) /* Standard NULL definition */
#endif

typedef _Bool bool;
#define false ((bool) 0)
#define true ((bool) 1)

/* Character classification macros */
#define isprint(c) (' ' <= (c) && (c) <= '~')
#define isspace(c) ((c) == ' ' || (c) == '\t' || (c) == '\n' || (c) == '\r')
#define isdigit(c) ('0' <= (c) && (c) <= '9')
#define islower(c) ('a' <= (c) && (c) <= 'z')
#define isupper(c) ('A' <= (c) && (c) <= 'Z')
#define isalpha(c) (islower(c) || isupper(c))
#define isalnum(c) (isalpha(c) || isdigit(c))
#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

/* Endianness conversion macros (standard network to host byte order) */
#if __BYTE_ORDER == __BIG_ENDIAN
#define htons(n) (n)
#define ntohs(n) (n)
#define htonl(n) (n)
#define ntohl(n) (n)

#else /* __LITTLE_ENDIAN */
/* 16-bit byte swap */
#define htons(n) \
    (((((uint16_t) (n) & 0x00FF)) << 8) | (((uint16_t) (n) & 0xFF00) >> 8))
#define ntohs(n) \
    (((((uint16_t) (n) & 0x00FF)) << 8) | (((uint16_t) (n) & 0xFF00) >> 8))

/* 32-bit byte swap */
#define htonl(n)                               \
    (((((uint32_t) (n) & 0x000000FF)) << 24) | \
     ((((uint32_t) (n) & 0x0000FF00)) << 8) |  \
     ((((uint32_t) (n) & 0x00FF0000)) >> 8) |  \
     ((((uint32_t) (n) & 0xFF000000)) >> 24))

#define ntohl(n)                               \
    (((((uint32_t) (n) & 0x000000FF)) << 24) | \
     ((((uint32_t) (n) & 0x0000FF00)) << 8) |  \
     ((((uint32_t) (n) & 0x00FF0000)) >> 8) |  \
     ((((uint32_t) (n) & 0xFF000000)) >> 24))

/* 64-bit byte swap - relies on 32-bit htonl/ntohl */
#define htonll(x)                                                         \
    ((1 == htonl(1))                                                      \
         ? (x)                                                            \
         : (((uint64_t) htonl((uint32_t) ((x) & 0xFFFFFFFFULL))) << 32) | \
               htonl((uint32_t) (((x) >> 32) & 0xFFFFFFFFULL)))
#define ntohll(x)                                                         \
    ((1 == ntohl(1))                                                      \
         ? (x)                                                            \
         : (((uint64_t) ntohl((uint32_t) ((x) & 0xFFFFFFFFULL))) << 32) | \
               ntohl((uint32_t) (((x) >> 32) & 0xFFFFFFFFULL)))

#endif /* __BYTE_ORDER */

/* String manipulation functions */
char *strcpy(char *s1, const char *s2);
char *strncpy(char *s1, const char *s2, int32_t n);
char *strcat(char *s1, const char *s2);
char *strncat(char *s1, const char *s2, int32_t n);
int32_t strcmp(const char *s1, const char *s2);
int32_t strncmp(const char *s1, const char *s2, int32_t n);
char *strstr(const char *s1, const char *s2);
size_t strlen(const char *s1);
char *strchr(const char *s1, int32_t c);
char *strpbrk(const char *s1, const char *s2);
char *strsep(char **pp, const char *delim);
char *strtok(char *s, const char *delim);
char *strtok_r(char *s, const char *delim, char **holder);
int32_t strtol(const char *s, char **end, int32_t base);
int32_t atoi(const char *s);
void itoa(int32_t i, char *s, int32_t base); /* Integer to ASCII conversion */

/* Memory manipulation functions */
void *memcpy(void *dst, const void *src, uint32_t n);
void *memmove(void *dst, const void *src, uint32_t n);
int32_t memcmp(const void *cs, const void *ct, uint32_t n);
void *memset(void *s, int32_t c, uint32_t n);
int32_t abs(int32_t n); /* Absolute value */

/* Random number generation */

#ifndef RAND_MAX
#define RAND_MAX 32767U /* Default max value for random() */
#endif

int32_t random(void);
void srand(uint32_t seed);

/* POSIX-style opaque container for re-entrant random number generator state */
struct random_data {
    uint32_t state; /* state must never be zero */
};
int random_r(struct random_data *buf, int32_t *result);

/* Input/Output functions */
int32_t puts(const char *str);
int getchar(void);
char *gets(char *s);
char *fgets(char *s, int n, void *f);
char *getline(char *s);
int32_t printf(const char *fmt, ...);
int32_t sprintf(char *out, const char *fmt, ...);
