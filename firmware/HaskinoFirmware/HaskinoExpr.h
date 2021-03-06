#ifndef HaskinoExprH
#define HaskinoExprH

#include "HaskinoScheduler.h"

#define EXPR(a,b) ((a << EXPR_TYPE_SHFT) | b)
#define EXPR_L(b) ((EXPR_LIST8 << EXPR_EXT_TYPE_SHFT) | b)
#define EXPR_F(b) ((EXPR_FLOAT << EXPR_EXT_TYPE_SHFT) | b)

// Base Expression Types
#define EXPR_TYPE_MASK 0xE0
#define EXPR_TYPE_SHFT 5
#define EXPR_BOOL   0x00
#define EXPR_WORD8  0x01
#define EXPR_WORD16 0x02
#define EXPR_WORD32 0x03
#define EXPR_INT8   0x04
#define EXPR_INT16  0x05
#define EXPR_INT32  0x06
#define EXPR_EXT    0x07

// Extended Expression Types
#define EXPR_EXT_TYPE_MASK  0xF0
#define EXPR_EXT_TYPE_SHFT  4
#define EXPR_EXT_OP_MASK    0x0F
#define EXPR_LIST8  0x0E
#define EXPR_FLOAT  0x0F

// Base Expression Ops
#define EXPR_OP_MASK 0x1F
#define EXPR_LIT  0x00
#define EXPR_REF  0x01
#define EXPR_BIND 0x02
#define EXPR_EQ   0x03
#define EXPR_LESS 0x04
#define EXPR_IF   0x05
#define EXPR_FINT 0x06
#define EXPR_NEG  0x07
#define EXPR_SIGN 0x08
#define EXPR_ADD  0x09
#define EXPR_SUB  0x0A
#define EXPR_MULT 0x0B
#define EXPR_DIV  0x0C
#define EXPR_NOT  0x0D
#define EXPR_AND  0x0E
#define EXPR_OR   0x0F
#define EXPR_TINT 0x10
#define EXPR_XOR  0x11
#define EXPR_REM  0x12
#define EXPR_COMP 0x13
#define EXPR_SHFL 0x14
#define EXPR_SHFR 0x15
#define EXPR_TSTB 0x16
#define EXPR_SETB 0x17
#define EXPR_CLRB 0x18
#define EXPR_QUOT 0x19
#define EXPR_MOD  0x1A
#define EXPR_SHOW 0x1B

// List Expression Ops
#define EXPR_ELEM 0x06
#define EXPR_LEN  0x07
#define EXPR_CONS 0x08
#define EXPR_APND 0x09
#define EXPR_PACK 0x0A
#define EXPR_PTR  0x0F

// Float Expression Ops
#define EXPRF_SHOW 0x0D
#define EXPRF_MATH 0x0E

// Float Math Expression Ops
#define EXPRF_TRUNC 0x00
#define EXPRF_FRAC  0x01
#define EXPRF_ROUND 0x02
#define EXPRF_CEIL  0x03
#define EXPRF_FLOOR 0x04
#define EXPRF_PI    0x05
#define EXPRF_EXP   0x06
#define EXPRF_LOG   0x07
#define EXPRF_SQRT  0x08
#define EXPRF_SIN   0x09
#define EXPRF_COS   0x0A
#define EXPRF_TAN   0x0B
#define EXPRF_ASIN  0x0C
#define EXPRF_ACOS  0x0D
#define EXPRF_ATAN  0x0E
#define EXPRF_ATAN2 0x0F
#define EXPRF_SINH  0x10
#define EXPRF_COSH  0x11
#define EXPRF_TANH  0x12
#define EXPRF_POWER 0x13
#define EXPRF_ISNAN 0x14
#define EXPRF_ISINF 0x15

bool evalBoolExpr(byte **ppExpr, CONTEXT *context);
uint8_t evalWord8Expr(byte **ppExpr, CONTEXT *context);
uint16_t evalWord16Expr(byte **ppExpr, CONTEXT *context);
uint32_t evalWord32Expr(byte **ppExpr, CONTEXT *context);
uint8_t *evalList8Expr(byte **ppExpr, CONTEXT *context, bool *alloc);
int8_t evalInt8Expr(byte **ppExpr, CONTEXT *context);
int16_t evalInt16Expr(byte **ppExpr, CONTEXT *context);
int32_t evalInt32Expr(byte **ppExpr, CONTEXT *context);
float evalFloatExpr(byte **ppExpr, CONTEXT *context);
void putBindListPtr(CONTEXT *context, byte bind, byte *newPtr);

#endif /* HaskinoExprH */
