/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

//function declarations
bool add_character_to_string_buffer(char);
int string_too_long();

//the following macro tries to add the given character to the string buffer. If the string becomes too long, it calls a function to handle it appropriately
#define ADD_CHAR(c) if(!add_character_to_string_buffer( (c) )) return string_too_long()

//integer to maintain the depth of nested comments
int comment_depth=0;
%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
LE				<=
ASSIGN			<-
LETTER			[a-zA-Z]
DIGIT			[0-9]
ULETTER			[A-Z]
LLETTER			[a-z]
WHITESPACE		[ \n\f\r\t\v]
TYPEID			{ULETTER}({LETTER}|{DIGIT}|_)*
OBJECTID		{LLETTER}({LETTER}|{DIGIT}|_)*

%x COMMENT STRING IGNORE_STRING
%%

 /*
  *  Nested comments
  */

--.*	{	/*single line comment*/ }
"*)"	{
		cool_yylval.error_msg="Unmatched *)";	// *) outside any comment block
		return (ERROR);
		}
"(*"	{
		BEGIN(COMMENT);	//comment begins
		comment_depth=1;	//Note: a simple comment_depth++ actually causes problems when there are multiple files, as the counter is not reset by default
		}
<COMMENT>"(*"	{
				comment_depth++;
				}
<COMMENT>"*)"	{
				comment_depth--;
				if(!comment_depth)
					BEGIN(INITIAL);	//comments ends
				}
<COMMENT>\n		{ curr_lineno++; }
<COMMENT>.	{	/*ignore text inside comments*/ }
<COMMENT><<EOF>>	{
					BEGIN(INITIAL);	//so as to exit gracefully
					cool_yylval.error_msg="EOF in comment";
					return (ERROR);
					}


 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{LE}			{ return (LE); }
{ASSIGN}		{ return (ASSIGN); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
[iI][fF]	{return (IF); }
[tT][hH][eE][nN]	{return {THEN};}
[eE][lL][sS][eE]	{return (ELSE);}
[fF][iI]	{ return (FI); }

[wW][hH][iI][lL][eE]	{ return (WHILE); }
[lL][oO][oO][pP]	{ return (LOOP); }
[pP][oO][oO][lL]	{ return (POOL); }

[lL][eE][tT]	{ return (LET); }
[iI][nN]	{ return (IN); }

[cC][aA][sS][eE]	{ return (CASE); }
[oO][fF]	{ return (OF); }
[eE][sS][aA][cC]	{ return (ESAC); }

[nN][eE][wW]	{ return (NEW); }

[iI][sS][vV][oO][iI][dD]	{ return (ISVOID); }

[nN][oO][tT]	{ return (NOT); }

[cC][lL][aA][sS][sS]	{ return (CLASS); }
[iI][nN][hH][eE][rR][iI][tT][sS]	{ return (INHERITS); }

t[rR][uU][eE]	{ cool_yylval.boolean=true; return (BOOL_CONST); }
f[aA][lL][sS][eE]	{ cool_yylval.boolean=false; return (BOOL_CONST); }

 /*
  *  TypeID and ObjectID. TypeID must begin with an uppercase letter while ObjectID must begin with a lowercase letter.
  */

{TYPEID}	{
			cool_yylval.symbol=idtable.add_string(yytext);	//add the string to the ID table
			return (TYPEID);
			}
{OBJECTID}	{
			cool_yylval.symbol=idtable.add_string(yytext);	//add the string to the ID table
			return (OBJECTID);
			}

 /*
  * Integer constants consist of strings of one or more continuous digits.
  */
{DIGIT}+	{
			cool_yylval.symbol=inttable.add_string(yytext);	//add the string to the INT table
			return (INT_CONST);
			}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
\"	{
	BEGIN(STRING);	//string begins
	string_buf_ptr=string_buf;	//set the buffer pointer to the beginning of the buffer
	}
<STRING>\"	{	//end of string constant
			if(string_buf_ptr-string_buf>=MAX_STR_CONST)
				{
				cool_yylval.error_msg="String constant too long";
				BEGIN(INITIAL);
				return (ERROR);
				}
			*string_buf_ptr='\0';	//terminate the formed string
			cool_yylval.symbol=stringtable.add_string(string_buf);	//add the string to the STRING table
			BEGIN(INITIAL);	//end of string state
			return (STR_CONST);
			}
<STRING>\n	{	// newline within a string
			cool_yylval.error_msg="Unterminated string constant";
			curr_lineno++;	//increment line no.
			BEGIN(INITIAL);	//end of string state, assuming that the programmer forgot to terminate the string
			return (ERROR);
			}
<STRING>\\n	{	//escaped n to mean newline
			ADD_CHAR('\n');
			}
<STRING>\\t	{	//escaped t to mean horizontal tab
			ADD_CHAR('\t');
			}
<STRING>\\b	{	//escaped b to mean backspace
			ADD_CHAR('\b');
			}
<STRING>\\f	{	//escaped f to mean formfeed
			ADD_CHAR('\f');
			}
<STRING>\\\n	{	//escaped newline
				curr_lineno++;	//increment line number
				ADD_CHAR('\n');
				}
<STRING>\\\0	{
				BEGIN(IGNORE_STRING);	//ignore the rest of the string
				cool_yylval.error_msg="String contains escaped null character.";
				return (ERROR);
				}
<STRING>\\(.|\n)	{	//any escaped character
				ADD_CHAR(yytext[1]);	//ignore the backslash and add the character after that. Note - The special case of escaped newline has already been handled above
				}
<STRING>\0	{	//null character
			BEGIN(IGNORE_STRING);	//ignore the rest of the string
			cool_yylval.error_msg="String contains null character.";
			return (ERROR);
			}
<STRING><<EOF>>	{
				BEGIN(INITIAL);	//so as to exit gracefully
				cool_yylval.error_msg="EOF in string constant";
				return (ERROR);
				}
				
<STRING>.	{	//for every character(other than \n, ofcourse). Note - The special case of \n has been handled above.
			ADD_CHAR(yytext[0]);//get the first(and only) character
			}

 /*
  * Ignore characters of the string in case of long string or invalid character
  */
<IGNORE_STRING>\n	{ curr_lineno++; BEGIN(INITIAL); }
<IGNORE_STRING>\\\n	{ curr_lineno++; /* escaped newline */ }
<IGNORE_STRING>\\\"	{ /* Ignore escaped quote */ }
<IGNORE_STRING>\\\\	{ /* Ignore escaped backslash */ }
<IGNORE_STRING>\"	{ BEGIN(INITIAL); }
<IGNORE_STRING>.	{ /* Any other character */ }

 /*
  * Counting line number
  */
\n	{ curr_lineno++; }
 /*
  *  Whitespace characters
  */
{WHITESPACE}	{ /* Ignore all whitespaces. Note that adding a '*' at the end would stop us from counting the lines */ }

 /*
  * Allowed single characters
  */
[-+*/~<=(){};:,.@]	{	//return the single character
					return yytext[0];
					}
.	{	//all other characters
	cool_yylval.error_msg=yytext;
	return (ERROR);
	}
	
%%
/*
 * This function adds the given character literal to the string buffer.
 * Then it checks if the string has exceeded the maximum length. If it has, it returns false. Otherwise it returns true
 */
bool add_character_to_string_buffer(char c) {
	if(string_buf_ptr-string_buf>=MAX_STR_CONST)
		return false;
	*string_buf_ptr++=c;
	return true;
}

/*
 * This function sets the error flag as "String constant too long" and goes to the IGNORE_STRING state to skip the remaining characters
 */
int string_too_long() {
	cool_yylval.error_msg="String constant too long";
	BEGIN(IGNORE_STRING);
	return (ERROR);
}