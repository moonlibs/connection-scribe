/*
	legacy proto module
	compile with:
		gcc -Wall -shared -fPIC -o libtntlegacy.so libtntlegacy.c
		gcc -Wall -shared -fPIC -o libtntlegacy.dylib libtntlegacy.c

	test as binary:
		gcc -Wall -DTEST -o tntlegacy libtntlegacy.c && ./tntlegacy
*/

#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>
#include <string.h>
#include <stdio.h>

#include "portable_endian.h"

#include "xd.h"

char * scr_hexdump(char *data, size_t size, xd_conf *cf) {
	return xd(data, size, cf);
}

/*

static const int VERSION_1    = 0x80010000;
#define VERSION_MASK 0xffff0000

#ifndef WBUF_MAX
#  define WBUF_MAX 10240
#endif

enum TType {
  T_STOP       = 0,
  T_VOID       = 1,
  T_BOOL       = 2,
  T_BYTE       = 3,
  T_I08        = 3,
  T_I16        = 6,
  T_I32        = 8,
  T_U64        = 9,
  T_I64        = 10,
  T_DOUBLE     = 4,
  T_STRING     = 11,
  T_UTF7       = 11,
  T_STRUCT     = 12,
  T_MAP        = 13,
  T_SET        = 14,
  T_LIST       = 15,
  T_UTF8       = 16,
  T_UTF16      = 17
};

#pragma pack (push, 1)
typedef struct {
	unsigned size : 32;
	char     v0   : 8;
	char     v1   : 8;
	char     t0   : 8;
	char     t1   : 8;
	//unsigned type : 16;
	
	//unsigned len  : 32;
	union {
		char     c[4];
		unsigned i : 32;
	} len;
	union {
		char     c[3];
		unsigned i:24;
	} proc;
	unsigned seq  : 32;
	struct {
		unsigned char type;
		unsigned char  id[2];
	} field;
	struct {
		unsigned char type;
		unsigned int  size : 32;
	} list;
} sc_hdr_t;
#pragma pack (pop)

static const sc_hdr_t default_hdr = {
	0,
	0x80,0x01, // version
	0,1, //type
	
	{0,0,0,3},
	{'L','o','g'},
	0xdeadbeef,
	{ 15,{0,1} },
	{ 12,0 }
};


*/
