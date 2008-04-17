/*
 * Copyright 2005 Sun Microsystems, Inc.	 All rights reserved.
 * Use is subject to license terms.
 *
 */

#ifndef	_LEXER_TOKENS_H_
#define	_LEXER_TOKENS_H_

#pragma ident	"@(#)lexer.h	1.2	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	T_EOF,
	T_L_Brace,
	T_R_Brace,
	T_L_Bracket,
	T_R_Bracket,
	T_Comma,
	T_S_Colon,

	T_Plus,
	T_Minus,
	T_And,
	T_Not,
	T_Or,
	T_Xor,
	T_LShift,
	T_Multiply,

	T_Equals,
	T_Number,
	T_String,
	T_Token,

	T_KW_node,
	T_KW_arc,

	T_KW_lookup,
	T_KW_proto,
	T_KW_include,
	T_KW_expr,
	T_KW_setprop,

	T_Error
} lexer_tok_t;

typedef struct {
	int		linenum;
	char		*fnamep;
	char		*cleanup_filep;
	uint64_t	val;
	char		*strp;
	bool_t		ungot_available;
	lexer_tok_t	last_token;
} lexer_t;

extern lexer_t lex;

void init_lexer(char *fnamep, FILE *fp, char *cleanup_filep);
lexer_tok_t lex_get_token(void);
void lex_get(lexer_tok_t expected);
void lex_unget(void);
void lex_fatal(char *s, ...);

#ifdef __cplusplus
}
#endif

#endif /* _LEXER_TOKENS_H_ */
