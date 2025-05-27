%{
#include "grammar.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

// Error type constants
#define ERROR_MEMORY 1
#define ERROR_REDECLARATION 2
#define ERROR_UNDECLARED_VAR 3
#define ERROR_SEMANTIC 4
#define ERROR_SYNTAX 5
#define ERROR_FILE_IO 6

// External variables and functions
extern int current_line;
extern void report_error(int error_type, const char* format, ...);
extern void report_warning(const char* format, ...);

void writetofile(char *ty, char *data);
%}

%option yylineno

%%

"let"           { writetofile("LET", yytext); return LET; }
"if"            { writetofile("IF", yytext); return IF; }
"else"          { writetofile("ELSE", yytext); return ELSE; }
"console"       { writetofile("CONSOLE", yytext); return CONSOLE; }
"log"           { writetofile("LOG", yytext); return LOG; }

"=="            { writetofile("EQ", yytext); return EQ; }
"==="           { writetofile("STRICTEQ", yytext); return STRICTEQ; }
"!="            { writetofile("NE", yytext); return NE; }
"<="            { writetofile("LE", yytext); return LE; }
">="            { writetofile("GE", yytext); return GE; }
"<"             { writetofile("LT", yytext); return '<'; }
">"             { writetofile("GT", yytext); return '>'; }

[a-zA-Z_][a-zA-Z0-9_]* { 
    writetofile("IDENTIFIER", yytext); 
    yylval.identifier = strdup(yytext);
    if (!yylval.identifier) {
        report_error(ERROR_MEMORY, "Failed to allocate memory for identifier");
        return 0;
    }
    return IDENTIFIER; 
}

[0-9]+          { 
    // Check for integer overflow
    long long value = atoll(yytext);
    if (value > INT_MAX) {
        report_error(ERROR_SEMANTIC, "Integer literal %s exceeds maximum value (%d)", 
                    yytext, INT_MAX);
        return 0;
    }
    
    writetofile("INTEGER", yytext); 
    yylval.integer = (int)value;
    return INTEGER; 
}

[0-9]+\.[0-9]+  {
    report_warning("Floating point numbers not supported - treating as error");
    report_error(ERROR_SYNTAX, "Floating point literal '%s' not supported in this subset", yytext);
    return 0;
}

"+"             { writetofile("PLUS", yytext); return '+'; }
"-"             { writetofile("MINUS", yytext); return '-'; }
"*"             { writetofile("MUL", yytext); return '*'; }
"="             { writetofile("ASSIGN", yytext); return '='; }
";"             { writetofile("SEMICOLON", yytext); return ';'; }
"{"             { writetofile("LBRACE", yytext); return '{'; }
"}"             { writetofile("RBRACE", yytext); return '}'; }
"("             { writetofile("LPAREN", yytext); return '('; }
")"             { writetofile("RPAREN", yytext); return ')'; }
","             { writetofile("COMMA", yytext); return ','; }
"."             { writetofile("DOT", yytext); return '.'; }
":"             { writetofile("COLON", yytext); return ':'; }

\'([^\'\\]|\\.)*\'  { 
    writetofile("STRING", yytext); 
    yylval.identifier = strdup(yytext);
    if (!yylval.identifier) {
        report_error(ERROR_MEMORY, "Failed to allocate memory for string");
        return 0;
    }
    return STRING; 
}

\"([^\"\\]|\\.)*\"  { 
    writetofile("STRING", yytext); 
    yylval.identifier = strdup(yytext);
    if (!yylval.identifier) {
        report_error(ERROR_MEMORY, "Failed to allocate memory for string");
        return 0;
    }
    return STRING; 
}

[ \t\r]+        { /* skip whitespace */ }

\n              { 
    current_line++; 
}

"//".*          { /* Ignore single-line comments */ }

.               { 
    report_error(ERROR_SYNTAX, "Unknown character: '%c' (ASCII: %d)", yytext[0], yytext[0]); 
}

%%

int yywrap() {
    return 1;
}

void writetofile(char *ty, char *data) {    
    FILE *fptr = fopen("output/token.txt", "a");
    if (fptr) {
        fprintf(fptr, "<%s,%s>\n", ty, data);
        fclose(fptr);
    }
    printf("<%s,%s>\n", ty, data);
}