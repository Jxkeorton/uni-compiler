%{
#include "grammar.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void writetofile(char *ty, char *data);
%}

%%

"function"      { writetofile("FUNCTION", yytext); return FUNCTION; }
"const"         { writetofile("CONST", yytext); return CONST; }
"let"           { writetofile("LET", yytext); return LET; }
"if"            { writetofile("IF", yytext); return IF; }
"else"          { writetofile("ELSE", yytext); return ELSE; }
"for"           { writetofile("FOR", yytext); return FOR; }
"return"        { writetofile("RETURN", yytext); return RETURN; }
"console"       { writetofile("CONSOLE", yytext); return CONSOLE; }
"log"           { writetofile("LOG", yytext); return LOG; }

"=="            { writetofile("EQ", yytext); return EQ; }
"==="           { writetofile("STRICTEQ", yytext); return STRICTEQ; }
"!="            { writetofile("NE", yytext); return NE; }
"<="            { writetofile("LE", yytext); return LE; }
">="            { writetofile("GE", yytext); return GE; }
"<"             { writetofile("LT", yytext); return '<'; }
">"             { writetofile("GT", yytext); return '>'; }
"++"            { writetofile("PLUSONE", yytext); return PLUSONE; }

[a-zA-Z_][a-zA-Z0-9_]* { 
    writetofile("IDENTIFIER", yytext); 
    yylval.identifier = strdup(yytext); 
    return IDENTIFIER; 
}

[0-9]+          { 
    writetofile("INTEGER", yytext); 
    yylval.integer = atoi(yytext); 
    return INTEGER; 
}

"%"             { writetofile("MOD", yytext); return '%'; }
"+"             { writetofile("PLUS", yytext); return '+'; }
"-"             { writetofile("MINUS", yytext); return '-'; }
"*"             { writetofile("MUL", yytext); return '*'; }
"/"             { writetofile("DIV", yytext); return '/'; }
"="             { writetofile("ASSIGN", yytext); return '='; }
";"             { writetofile("SEMICOLON", yytext); return ';'; }
"{"             { writetofile("LBRACE", yytext); return '{'; }
"}"             { writetofile("RBRACE", yytext); return '}'; }
"["             { writetofile("LSQBRACKET", yytext); return '['; }
"]"             { writetofile("RSQBRACKET", yytext); return ']'; }
"("             { writetofile("LPAREN", yytext); return '('; }
")"             { writetofile("RPAREN", yytext); return ')'; }
","             { writetofile("COMMA", yytext); return ','; }
"."             { writetofile("DOT", yytext); return '.'; }

\'([^\'\\]|\\.)*\'  { 
    writetofile("STRING", yytext); 
    yylval.identifier = strdup(yytext); 
    return STRING; 
}

\"([^\"\\]|\\.)*\"  { 
    writetofile("STRING", yytext); 
    yylval.identifier = strdup(yytext); 
    return STRING; 
}

[ \t\n\r]+      { /* skip whitespace */ }
"//".*          { /* Ignore single-line comments */ }
"/*"([^*]|\*+[^*/])*\*+"/"  { /* Ignore multi-line comments */ }

.               { 
    printf("Unknown character: '%c' (ASCII: %d)\n", yytext[0], yytext[0]); 
}

%%

int yywrap() {
    return 1;
}

void writetofile(char *ty, char *data) {
    FILE *fptr = fopen("token.txt", "a");
    if (fptr) {
        fprintf(fptr, "<%s,%s>\n", ty, data);
        fclose(fptr);
    }
    printf("<%s,%s>\n", ty, data);
}