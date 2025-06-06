%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

extern int yylex();
void yyerror(const char *s);

int current_line = 1;

// Symbol table structure
typedef struct Symbol {
    char* name;
    int value;
    int is_initialized;
    int times_used;
    int line_declared;          // Keep line tracking for better errors
    struct Symbol* next;
} Symbol;

Symbol* symbol_table = NULL;

// AST node types
typedef enum { 
    NODE_VARIABLE_DECL, NODE_ASSIGNMENT, NODE_BINARY_OP, 
    NODE_IF, NODE_CONSOLE_LOG, NODE_LITERAL, NODE_VARIABLE,
    NODE_STATEMENT_LIST, NODE_ARGUMENT_LIST
} NodeType;

typedef struct ASTNode {
    NodeType type;
    struct ASTNode* left;
    struct ASTNode* right;
    char* identifier;
    int value;
} ASTNode;

ASTNode* createASTNode(NodeType type, char* identifier, int value, ASTNode* left, ASTNode* right);
void generateCode(ASTNode* node, FILE* output);
void freeAST(ASTNode* node);

// Enhanced but simple error reporting
void error(const char* format, ...);
void warning(const char* format, ...);

// Symbol table functions
int add_symbol(char* name, int value, int is_initialized);
Symbol* lookup_symbol(char* name);
int mark_symbol_used(char* name);
void check_unused_variables();

ASTNode* root = NULL;
%}

%token <integer> INTEGER 
%token <identifier> IDENTIFIER
%token <identifier> STRING
%token LET IF ELSE
%token EQ
%token CONSOLE LOG

%union {
    int integer;
    char* identifier;
    struct ASTNode* ast_node;
}

%type <ast_node> program statement expression console_log statement_list if_statement
%type <ast_node> argument_list primary block

%right '='
%left EQ '<' '>'
%left '+' '-'
%left '*'

%%

program: statement_list { root = $1; $$ = $1; }

statement:
      LET IDENTIFIER '=' expression ';'     { 
          if (!add_symbol($2, ($4 && $4->type == NODE_LITERAL) ? $4->value : 0, 1)) {
              YYERROR;
          }
          $$ = createASTNode(NODE_VARIABLE_DECL, strdup($2), 0, $4, NULL); 
      }
    | IDENTIFIER '=' expression ';'         { 
          if (!lookup_symbol($1)) {
              error("Variable '%s' is not declared", $1);
              YYERROR;
          }
          $$ = createASTNode(NODE_ASSIGNMENT, strdup($1), 0, $3, NULL); 
      }
    | console_log ';'                       { $$ = $1; }
    | if_statement                          { $$ = $1; }
    ;

statement_list:
      statement_list statement              { $$ = createASTNode(NODE_STATEMENT_LIST, NULL, 0, $1, $2); }
    | statement                             { $$ = $1; }
    ;

console_log:
    CONSOLE '.' LOG '(' argument_list ')'   { $$ = createASTNode(NODE_CONSOLE_LOG, NULL, 0, $5, NULL); }
    ;

argument_list:
      /* empty */                           { $$ = NULL; }
    | expression                            { $$ = $1; }
    | argument_list ',' expression          { $$ = createASTNode(NODE_ARGUMENT_LIST, NULL, 0, $1, $3); }
    ;

expression:
      primary                               { $$ = $1; }
    | expression '+' expression             { $$ = createASTNode(NODE_BINARY_OP, strdup("+"), 0, $1, $3); }
    | expression '-' expression             { $$ = createASTNode(NODE_BINARY_OP, strdup("-"), 0, $1, $3); }
    | expression '*' expression             { $$ = createASTNode(NODE_BINARY_OP, strdup("*"), 0, $1, $3); }
    | expression EQ expression              { $$ = createASTNode(NODE_BINARY_OP, strdup("=="), 0, $1, $3); }
    | expression '<' expression             { $$ = createASTNode(NODE_BINARY_OP, strdup("<"), 0, $1, $3); }
    | expression '>' expression             { $$ = createASTNode(NODE_BINARY_OP, strdup(">"), 0, $1, $3); }
    | '(' expression ')'                    { $$ = $2; }
    ;

primary:
      INTEGER                               { $$ = createASTNode(NODE_LITERAL, NULL, $1, NULL, NULL); }
    | STRING                                { $$ = createASTNode(NODE_LITERAL, strdup($1), 0, NULL, NULL); }
    | IDENTIFIER                            { 
          if (!mark_symbol_used($1)) {
              YYERROR;
          }
          $$ = createASTNode(NODE_VARIABLE, strdup($1), 0, NULL, NULL); 
      }
    ;

if_statement:
      IF '(' expression ')' block                           { $$ = createASTNode(NODE_IF, NULL, 0, $3, $5); }
    | IF '(' expression ')' block ELSE block                { $$ = createASTNode(NODE_IF, NULL, 0, $3, createASTNode(NODE_IF, NULL, 1, $5, $7)); }
    ;

block:
      '{' statement_list '}'                { $$ = $2; }
    | '{' '}'                               { $$ = NULL; }
    ;

%%

// Enhanced but simple error reporting
void error(const char* format, ...) {
    va_list args;
    va_start(args, format);
    fprintf(stderr, "Error at line %d: ", current_line);
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    va_end(args);
}

void warning(const char* format, ...) {
    va_list args;
    va_start(args, format);
    fprintf(stderr, "Warning at line %d: ", current_line);
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    va_end(args);
}

// Symbol Table Functions with better error reporting
int add_symbol(char* name, int value, int is_initialized) {
    Symbol* existing = lookup_symbol(name);
    if (existing) {
        error("Variable '%s' is already declared at line %d", name, existing->line_declared);
        return 0;
    }
    
    Symbol* new_symbol = malloc(sizeof(Symbol));
    new_symbol->name = strdup(name);
    new_symbol->value = value;
    new_symbol->is_initialized = is_initialized;
    new_symbol->times_used = 0;
    new_symbol->line_declared = current_line;
    new_symbol->next = symbol_table;
    symbol_table = new_symbol;
    
    printf("✓ Added symbol: %s = %d at line %d\n", name, value, current_line);
    return 1;
}

Symbol* lookup_symbol(char* name) {
    Symbol* current = symbol_table;
    while (current) {
        if (strcmp(current->name, name) == 0) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

int mark_symbol_used(char* name) {
    Symbol* symbol = lookup_symbol(name);
    if (!symbol) {
        error("Variable '%s' is not declared", name);
        return 0;
    }
    symbol->times_used++;
    return 1;
}

void check_unused_variables() {
    printf("\n=== Checking for unused variables ===\n");
    Symbol* current = symbol_table;
    int unused_count = 0;
    
    while (current) {
        if (current->times_used == 0) {
            warning("Variable '%s' declared at line %d is never used", 
                   current->name, current->line_declared);
            unused_count++;
        }
        current = current->next;
    }
    
    if (unused_count == 0) {
        printf("✓ No unused variables found\n");
    } else {
        printf("Found %d unused variable(s)\n", unused_count);
    }
}

void free_symbol_table() {
    Symbol* current = symbol_table;
    while (current) {
        Symbol* temp = current;
        current = current->next;
        free(temp->name);
        free(temp);
    }
    symbol_table = NULL;
}

// AST Functions (unchanged)
ASTNode* createASTNode(NodeType type, char* identifier, int value, ASTNode* left, ASTNode* right) {
    ASTNode* newNode = malloc(sizeof(ASTNode));
    newNode->type = type;
    newNode->identifier = identifier;
    newNode->value = value;
    newNode->left = left;
    newNode->right = right;
    return newNode;
}

void generateCode(ASTNode* node, FILE* output) {
    if (!node) return;

    switch (node->type) {            
        case NODE_STATEMENT_LIST:
            generateCode(node->left, output);
            generateCode(node->right, output);
            break;
            
        case NODE_VARIABLE_DECL:
            fprintf(output, "    int %s = ", node->identifier);
            generateCode(node->left, output);
            fprintf(output, ";\n");
            break;
            
        case NODE_ASSIGNMENT:
            fprintf(output, "    %s = ", node->identifier);
            generateCode(node->left, output);
            fprintf(output, ";\n");
            break;
            
        case NODE_CONSOLE_LOG:
            fprintf(output, "    printf(");
            if (node->left) {
                if (node->left->type == NODE_LITERAL && node->left->identifier) {
                    // String literal
                    char* str = node->left->identifier;
                    fprintf(output, "\"");
                    for (int i = 1; i < strlen(str) - 1; i++) {
                        fprintf(output, "%c", str[i]);
                    }
                    fprintf(output, "\\n\"");
                } else if (node->left->type == NODE_LITERAL) {
                    // Integer literal
                    fprintf(output, "\"%d\\n\"", node->left->value);
                } else {
                    // Variable or expression
                    fprintf(output, "\"%%d\\n\", ");
                    generateCode(node->left, output);
                }
            }
            fprintf(output, ");\n");
            break;
            
        case NODE_ARGUMENT_LIST:
            generateCode(node->left, output);
            if (node->right) {
                fprintf(output, ", ");
                generateCode(node->right, output);
            }
            break;
            
        case NODE_BINARY_OP:
            fprintf(output, "(");
            generateCode(node->left, output);
            fprintf(output, " %s ", node->identifier);
            generateCode(node->right, output);
            fprintf(output, ")");
            break;
            
        case NODE_LITERAL:
            if (node->identifier) {
                fprintf(output, "\"%s\"", node->identifier);
            } else {
                fprintf(output, "%d", node->value);
            }
            break;
            
        case NODE_VARIABLE:
            fprintf(output, "%s", node->identifier);
            break;
            
        case NODE_IF:
            fprintf(output, "    if (");
            generateCode(node->left, output);
            fprintf(output, ") {\n");
            if (node->right) {
                if (node->right->type == NODE_IF && node->right->value == 1) {
                    generateCode(node->right->left, output);
                    fprintf(output, "    } else {\n");
                    generateCode(node->right->right, output);
                } else {
                    generateCode(node->right, output);
                }
            }
            fprintf(output, "    }\n");
            break;
    }
}

void freeAST(ASTNode* node) {
    if (!node) return;
    freeAST(node->left);
    freeAST(node->right);
    if (node->identifier) free(node->identifier);
    free(node);
}

void yyerror(const char *s) {
    error("Syntax error: %s", s);
}

// Main function
int main() {
    extern FILE *yyin;
    
    current_line = 1;
    
    yyin = fopen("input.txt", "r");
    if (!yyin) {
        error("Could not open input.txt");
        return 1;
    }
    
    printf("=== Starting Compilation ===\n");
    
    if (yyparse() == 0) {
        printf("✓ Parsing successful!\n");
        
        // Check for unused variables
        check_unused_variables();
        
        // Generate C code
        FILE* output = fopen("output/output.c", "w");
        if (output) {
            fprintf(output, "#include <stdio.h>\n\n");
            fprintf(output, "int main() {\n");
            generateCode(root, output);
            fprintf(output, "    return 0;\n");
            fprintf(output, "}\n");
            fclose(output);
            printf("✓ C code generated in output/output.c\n");
            
            // Compile and run
            if (system("gcc -o output/program.exe output/output.c") == 0) {
                printf("✓ Executable created!\n");
                printf("--- Program Output ---\n");
                system("output/program.exe");
                printf("--- End Output ---\n");
                printf("✓ Compilation complete!\n");
            } else {
                error("C compilation failed");
            }
        }
        
        freeAST(root);
        free_symbol_table();
    } else {
        error("Parsing failed");
        free_symbol_table();
        return 1;
    }
    
    fclose(yyin);
    return 0;
}