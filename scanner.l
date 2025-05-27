%{
#include "grammar.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Enhanced error tracking
extern int current_line;
extern int current_column;
extern void report_error();
extern void report_warning();

void writetofile(char *ty, char *data);
void update_position(char* text);
void handle_newline();
%}

%option yylineno

%%

"let"           { update_position(yytext); writetofile("LET", yytext); return LET; }
"if"            { update_position(yytext); writetofile("IF", yytext); return IF; }
"else"          { update_position(yytext); writetofile("ELSE", yytext); return ELSE; }
"console"       { update_position(yytext); writetofile("CONSOLE", yytext); return CONSOLE; }
"log"           { update_position(yytext); writetofile("LOG", yytext); return LOG; }

"=="            { update_position(yytext); writetofile("EQ", yytext); return EQ; }
"==="           { update_position(yytext); writetofile("STRICTEQ", yytext); return STRICTEQ; }
"!="            { update_position(yytext); writetofile("NE", yytext); return NE; }
"<="            { update_position(yytext); writetofile("LE", yytext); return LE; }
">="            { update_position(yytext); writetofile("GE", yytext); return GE; }
"<"             { update_position(yytext); writetofile("LT", yytext); return '<'; }
">"             { update_position(yytext); writetofile("GT", yytext); return '>'; }

[a-zA-Z_][a-zA-Z0-9_]* { 
    update_position(yytext);
    
    // Check for overly long identifiers
    if (strlen(yytext) > 255) {
        report_warning("Identifier '%s' is very long (%zu characters)", 
                      yytext, strlen(yytext));
    }
    
    // Check for reserved words that might be typos
    if (strcmp(yytext, "var") == 0) {
        report_warning("Found 'var' - did you mean 'let'?");
    } else if (strcmp(yytext, "function") == 0) {
        report_warning("'function' keyword not supported in this subset");
    } else if (strcmp(yytext, "const") == 0) {
        report_warning("'const' keyword not supported - use 'let' instead");
    }
    
    writetofile("IDENTIFIER", yytext); 
    yylval.identifier = strdup(yytext);
    if (!yylval.identifier) {
        report_error(ERROR_MEMORY, "Failed to allocate memory for identifier");
        return 0;
    }
    return IDENTIFIER; 
}

[0-9]+          { 
    update_position(yytext);
    
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
    update_position(yytext);
    report_warning("Floating point numbers not supported - treating as error");
    report_error(ERROR_SYNTAX, "Floating point literal '%s' not supported in this subset", yytext);
    return 0;
}

"+"             { update_position(yytext); writetofile("PLUS", yytext); return '+'; }
"-"             { update_position(yytext); writetofile("MINUS", yytext); return '-'; }
"*"             { update_position(yytext); writetofile("MUL", yytext); return '*'; }
"/"             { update_position(yytext); writetofile("DIV", yytext); return '/'; }
"%"             { update_position(yytext); writetofile("MOD", yytext); return '%'; }
"="             { update_position(yytext); writetofile("ASSIGN", yytext); return '='; }
";"             { update_position(yytext); writetofile("SEMICOLON", yytext); return ';'; }
"{"             { update_position(yytext); writetofile("LBRACE", yytext); return '{'; }
"}"             { update_position(yytext); writetofile("RBRACE", yytext); return '}'; }
"("             { update_position(yytext); writetofile("LPAREN", yytext); return '('; }
")"             { update_position(yytext); writetofile("RPAREN", yytext); return ')'; }
","             { update_position(yytext); writetofile("COMMA", yytext); return ','; }
"."             { update_position(yytext); writetofile("DOT", yytext); return '.'; }
":"             { update_position(yytext); writetofile("COLON", yytext); return ':'; }

\'([^\'\\]|\\.)*\'  { 
    update_position(yytext);
    
    // Check for unterminated string
    if (yytext[strlen(yytext)-1] != '\'') {
        report_error(ERROR_SYNTAX, "Unterminated string literal starting with %c", yytext[0]);
        return 0;
    }
    
    // Check for very long strings
    if (strlen(yytext) > 1000) {
        report_warning("String literal is very long (%zu characters)", strlen(yytext));
    }
    
    writetofile("STRING", yytext); 
    yylval.identifier = strdup(yytext);
    if (!yylval.identifier) {
        report_error(ERROR_MEMORY, "Failed to allocate memory for string");
        return 0;
    }
    return STRING; 
}

\"([^\"\\]|\\.)*\"  { 
    update_position(yytext);
    
    // Check for unterminated string
    if (yytext[strlen(yytext)-1] != '"') {
        report_error(ERROR_SYNTAX, "Unterminated string literal starting with %c", yytext[0]);
        return 0;
    }
    
    // Check for very long strings
    if (strlen(yytext) > 1000) {
        report_warning("String literal is very long (%zu characters)", strlen(yytext));
    }
    
    writetofile("STRING", yytext); 
    yylval.identifier = strdup(yytext);
    if (!yylval.identifier) {
        report_error(ERROR_MEMORY, "Failed to allocate memory for string");
        return 0;
    }
    return STRING; 
}

[ \t]+          { 
    // Update column position for whitespace
    for (int i = 0; i < yyleng; i++) {
        if (yytext[i] == '\t') {
            current_column += 8 - (current_column % 8); // Tab = 8 spaces
        } else {
            current_column++;
        }
    }
}

[\n\r]+         { 
    handle_newline(); 
}

"//".*          { 
    update_position(yytext);
    /* Ignore single-line comments but count them for debugging */
}

"/*"            {
    update_position(yytext);
    report_warning("Block comments (/* */) not fully supported - use // instead");
    int c;
    int start_line = current_line;
    while ((c = input()) != 0) {
        if (c == '\n') {
            current_line++;
            current_column = 1;
        } else {
            current_column++;
        }
        if (c == '*') {
            if ((c = input()) == '/') {
                current_column++;
                break;
            } else {
                unput(c);
            }
        }
    }
    if (c == 0) {
        report_error(ERROR_SYNTAX, "Unterminated block comment starting at line %d", start_line);
        return 0;
    }
}

\'([^\'\\]|\\.)*$   {
    report_error(ERROR_SYNTAX, "Unterminated string literal (missing closing quote)");
    return 0;
}

\"([^\"\\]|\\.)*$   {
    report_error(ERROR_SYNTAX, "Unterminated string literal (missing closing quote)");
    return 0;
}

[0-9]+[a-zA-Z_][a-zA-Z0-9_]*  {
    update_position(yytext);
    report_error(ERROR_SYNTAX, "Invalid identifier '%s' (cannot start with digit)", yytext);
    return 0;
}

.               { 
    update_position(yytext);
    report_error(ERROR_SYNTAX, "Unknown character: '%c' (ASCII: %d)", yytext[0], yytext[0]); 
    return 0;
}

<<EOF>>         {
    printf("End of file reached\n");
    return 0;
}

%%

int yywrap() {
    return 1;
}

void writetofile(char *ty, char *data) {
    FILE *fptr = fopen("token.txt", "a");
    if (!fptr) {
        report_error(ERROR_FILE_IO, "Cannot open token.txt for writing");
        return;
    }
    
    if (fprintf(fptr, "<%s,%s> at line %d, column %d\n", ty, data, current_line, current_column) < 0) {
        report_error(ERROR_FILE_IO, "Failed to write to token.txt");
    }
    
    fclose(fptr);
    printf("<%s,%s> at line %d, column %d\n", ty, data, current_line, current_column);
}

void update_position(char* text) {
    current_column += strlen(text);
}

void handle_newline() {
    current_line++;
    current_column = 1;
}