%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex();
void yyerror(const char *s);

// Symbol table structure
typedef struct Symbol {
    char* name;
    int value;
    int is_initialized;
    struct Symbol* next;
} Symbol;

// Symbol table functions
Symbol* symbol_table = NULL;
void add_symbol(char* name, int value, int is_initialized);
Symbol* lookup_symbol(char* name);
int is_declared(char* name);
void free_symbol_table();
void print_symbol_table();

// Simplified AST node types
typedef enum { 
    NODE_PROGRAM, NODE_VARIABLE_DECL, NODE_ASSIGNMENT, NODE_BINARY_OP, 
    NODE_IF, NODE_CONSOLE_LOG, NODE_LITERAL, NODE_VARIABLE,
    NODE_STATEMENT_LIST
} NodeType;

typedef struct ASTNode {
    NodeType type;
    struct ASTNode* left;
    struct ASTNode* right;
    char* identifier;
    int value;
} ASTNode;

// Function prototypes
ASTNode* createASTNode(NodeType type, char* identifier, int value, ASTNode* left, ASTNode* right);
void generateCode(ASTNode* node, FILE* output);
void freeAST(ASTNode* node);

// Global AST root
ASTNode* root = NULL;
%}

%token <integer> INTEGER 
%token <identifier> IDENTIFIER
%token <identifier> STRING
%token LET IF ELSE
%token EQ NE LE GE STRICTEQ
%token CONSOLE LOG

%union {
    int integer;
    char* identifier;
    struct ASTNode* ast_node;
}

%type <ast_node> program statement expression console_log statement_list arithmetic_expr if_statement

%right '='
%left EQ STRICTEQ NE '<' '>' LE GE
%left '+' '-'
%left '*'

%%

/* Program Structure */
program: statement_list { root = $1; $$ = $1; }

/* Statements */
statement:
      LET IDENTIFIER '=' expression ';'     { $$ = createASTNode(NODE_VARIABLE_DECL, strdup($2), 0, $4, NULL); }
    | IDENTIFIER '=' expression ';'         { $$ = createASTNode(NODE_ASSIGNMENT, strdup($1), 0, $3, NULL); }
    | console_log ';'                       { $$ = $1; }
    | if_statement                          { $$ = $1; }
    ;

statement_list:
    statement_list statement { $$ = createASTNode(NODE_STATEMENT_LIST, NULL, 0, $1, $2); }
    | statement              { $$ = $1; }
    ;

/* Console.log */
console_log:
    CONSOLE '.' LOG '(' STRING ')'                          { $$ = createASTNode(NODE_CONSOLE_LOG, strdup($5), 0, NULL, NULL); }
  | CONSOLE '.' LOG '(' STRING ',' IDENTIFIER ')'           { $$ = createASTNode(NODE_CONSOLE_LOG, strdup($5), 0, createASTNode(NODE_VARIABLE, strdup($7), 0, NULL, NULL), NULL); }
  | CONSOLE '.' LOG '(' STRING ',' INTEGER ')'              { $$ = createASTNode(NODE_CONSOLE_LOG, strdup($5), 0, createASTNode(NODE_LITERAL, NULL, $7, NULL, NULL), NULL); }
  | CONSOLE '.' LOG '(' IDENTIFIER ')'                      { $$ = createASTNode(NODE_CONSOLE_LOG, NULL, 0, createASTNode(NODE_VARIABLE, strdup($5), 0, NULL, NULL), NULL); }
    ;

/* Expressions */
expression:
      arithmetic_expr                       { $$ = $1; }
    | expression EQ arithmetic_expr         { $$ = createASTNode(NODE_BINARY_OP, strdup("=="), 0, $1, $3); }
    | expression STRICTEQ arithmetic_expr   { $$ = createASTNode(NODE_BINARY_OP, strdup("==="), 0, $1, $3); }
    | expression NE arithmetic_expr         { $$ = createASTNode(NODE_BINARY_OP, strdup("!="), 0, $1, $3); }
    | expression '<' arithmetic_expr        { $$ = createASTNode(NODE_BINARY_OP, strdup("<"), 0, $1, $3); }
    | expression '>' arithmetic_expr        { $$ = createASTNode(NODE_BINARY_OP, strdup(">"), 0, $1, $3); }
    | expression LE arithmetic_expr         { $$ = createASTNode(NODE_BINARY_OP, strdup("<="), 0, $1, $3); }
    | expression GE arithmetic_expr         { $$ = createASTNode(NODE_BINARY_OP, strdup(">="), 0, $1, $3); }
    ;

arithmetic_expr:
      INTEGER                               { $$ = createASTNode(NODE_LITERAL, NULL, $1, NULL, NULL); }
    | IDENTIFIER                            { $$ = createASTNode(NODE_VARIABLE, strdup($1), 0, NULL, NULL); }
    | arithmetic_expr '+' arithmetic_expr   { $$ = createASTNode(NODE_BINARY_OP, strdup("+"), 0, $1, $3); }
    | arithmetic_expr '-' arithmetic_expr   { $$ = createASTNode(NODE_BINARY_OP, strdup("-"), 0, $1, $3); }
    | arithmetic_expr '*' arithmetic_expr   { $$ = createASTNode(NODE_BINARY_OP, strdup("*"), 0, $1, $3); }
    | '(' expression ')'                    { $$ = $2; }
    ;

/* If statements */
if_statement:
    IF '(' expression ')' '{' statement_list '}'                    { $$ = createASTNode(NODE_IF, NULL, 0, $3, $6); }
  | IF '(' expression ')' '{' statement_list '}' ELSE '{' statement_list '}' { $$ = createASTNode(NODE_IF, NULL, 0, $3, createASTNode(NODE_IF, NULL, 1, $6, $10)); }
    ;

%%

/* C Code Section */

// Function to create AST nodes
ASTNode* createASTNode(NodeType type, char* identifier, int value, ASTNode* left, ASTNode* right) {
    ASTNode* newNode = (ASTNode*)malloc(sizeof(ASTNode));
    newNode->type = type;
    newNode->identifier = identifier;
    newNode->value = value;
    newNode->left = left;
    newNode->right = right;
    return newNode;
}

void yyerror(const char *s) {
    fprintf(stderr, "Parser error: %s\n", s);
}

void generateCode(ASTNode* node, FILE* output) {
    if (!node) return;

    switch (node->type) {
        case NODE_PROGRAM:
            generateCode(node->left, output);
            break;
            
        case NODE_STATEMENT_LIST:
            generateCode(node->left, output);
            generateCode(node->right, output);
            break;
            
        case NODE_VARIABLE_DECL:
            if (is_declared(node->identifier)) {
                fprintf(stderr, "Error: Variable '%s' already declared\n", node->identifier);
                return;
            }
            // Add to symbol table
            if (node->left && node->left->type == NODE_LITERAL) {
                add_symbol(node->identifier, node->left->value, 1);
            } else {
                add_symbol(node->identifier, 0, 0); // Unknown value at compile time
            }
            fprintf(output, "    int %s = ", node->identifier);
            generateCode(node->left, output);
            fprintf(output, ";\n");
            break;
            
        case NODE_ASSIGNMENT:
            if (!is_declared(node->identifier)) {
                fprintf(stderr, "Error: Variable '%s' not declared\n", node->identifier);
                return;
            }
            // Update symbol table value if it's a literal
            Symbol* sym = lookup_symbol(node->identifier);
            if (sym && node->left && node->left->type == NODE_LITERAL) {
                sym->value = node->left->value;
                sym->is_initialized = 1;
            }
            fprintf(output, "    %s = ", node->identifier);
            generateCode(node->left, output);
            fprintf(output, ";\n");
            break;
            
        case NODE_CONSOLE_LOG:
            fprintf(output, "    printf(");
            if (node->identifier) {
                // String with possible variable
                char* str = node->identifier;
                fprintf(output, "\"");
                for (int i = 1; i < strlen(str) - 1; i++) {
                    if (str[i] == '%') fprintf(output, "%%");
                    else fprintf(output, "%c", str[i]);
                }
                if (node->left) {
                    fprintf(output, " %%d");
                }
                fprintf(output, "\\n\"");
                if (node->left) {
                    fprintf(output, ", ");
                    generateCode(node->left, output);
                }
            } else if (node->left) {
                // Just a variable or number
                if (node->left->type == NODE_VARIABLE) {
                    fprintf(output, "\"%%d\\n\", ");
                    generateCode(node->left, output);
                } else {
                    fprintf(output, "\"%d\\n\"", node->left->value);
                }
            }
            fprintf(output, ");\n");
            break;
            
        case NODE_BINARY_OP:
            fprintf(output, "(");
            generateCode(node->left, output);
            if (strcmp(node->identifier, "===") == 0) {
                fprintf(output, " == ");
            } else {
                fprintf(output, " %s ", node->identifier);
            }
            generateCode(node->right, output);
            fprintf(output, ")");
            break;
            
        case NODE_LITERAL:
            fprintf(output, "%d", node->value);
            break;
            
        case NODE_VARIABLE:
            if (!is_declared(node->identifier)) {
                fprintf(stderr, "Error: Variable '%s' not declared\n", node->identifier);
                return;
            }
            fprintf(output, "%s", node->identifier);
            break;
            
        case NODE_IF:
            fprintf(output, "    if (");
            generateCode(node->left, output);
            fprintf(output, ") {\n");
            if (node->right) {
                if (node->right->type == NODE_IF && node->right->value == 1) {
                    // This is if-else
                    generateCode(node->right->left, output);
                    fprintf(output, "    } else {\n");
                    generateCode(node->right->right, output);
                } else {
                    // Simple if
                    generateCode(node->right, output);
                }
            }
            fprintf(output, "    }\n");
            break;
            
        default:
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

// Symbol table implementation
void add_symbol(char* name, int value, int is_initialized) {
    Symbol* new_symbol = (Symbol*)malloc(sizeof(Symbol));
    new_symbol->name = strdup(name);
    new_symbol->value = value;
    new_symbol->is_initialized = is_initialized;
    new_symbol->next = symbol_table;
    symbol_table = new_symbol;
    printf("Added symbol: %s = %d (initialized: %s)\n", name, value, is_initialized ? "yes" : "no");
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

int is_declared(char* name) {
    return lookup_symbol(name) != NULL;
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

void print_symbol_table() {
    printf("\n=== Symbol Table ===\n");
    Symbol* current = symbol_table;
    if (!current) {
        printf("(empty)\n");
        return;
    }
    while (current) {
        printf("Variable: %s, Value: %d, Initialized: %s\n", 
               current->name, current->value, current->is_initialized ? "yes" : "no");
        current = current->next;
    }
    printf("==================\n\n");
}

int main() {
    extern FILE *yyin;
    yyin = fopen("input.txt", "r");
    if (!yyin) {
        fprintf(stderr, "Error: Could not open input.txt\n");
        return 1;
    }
    
    if (yyparse() == 0) {
        printf("Parsing successful!\n");
        
        // Print symbol table for debugging
        print_symbol_table();
        
        // Generate C code
        FILE* output = fopen("output.c", "w");
        if (output) {
            fprintf(output, "#include <stdio.h>\n");
            fprintf(output, "#include <stdlib.h>\n\n");
            
            fprintf(output, "int main() {\n");
            
            generateCode(root, output);
            
            fprintf(output, "    return 0;\n");
            fprintf(output, "}\n");
            
            fclose(output);
            printf("C code generated in output.c\n");
        }
        
        freeAST(root);
        free_symbol_table();
    } else {
        fprintf(stderr, "Parsing failed!\n");
        free_symbol_table();
    }
    
    fclose(yyin);
    return 0;
}