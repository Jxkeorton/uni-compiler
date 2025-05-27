%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>

extern int yylex();
void yyerror(const char *s);

// Add current_line variable
int current_line = 1;

// Error type constants
#define ERROR_MEMORY 1
#define ERROR_REDECLARATION 2
#define ERROR_UNDECLARED_VAR 3
#define ERROR_SEMANTIC 4
#define ERROR_SYNTAX 5
#define ERROR_FILE_IO 6

// Symbol table structure
typedef struct Symbol {
    char* name;
    int value;
    int is_initialized;
    int line_declared;        // Line where variable was declared
    int times_used;          // Usage counter
    int is_assigned;         // Has been assigned after declaration
    struct Symbol* next;
} Symbol;

// Symbol table functions
Symbol* symbol_table = NULL;
int symbol_count = 0;

// Error reporting functions
void report_error(int error_type, const char* format, ...);
void report_warning(const char* format, ...);

// Enhanced symbol table functions
int add_symbol_safe(char* name, int value, int is_initialized);
Symbol* lookup_symbol_safe(char* name);
int is_declared_safe(char* name);
int mark_symbol_used(char* name);
int mark_symbol_assigned(char* name);
void validate_symbol_usage();
void free_symbol_table_safe();
void print_symbol_table_enhanced();

// Memory safety helpers
char* safe_strdup(const char* str);
int validate_identifier(const char* name);

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

/* Statements with Safe Symbol Table Integration */
statement:
      LET IDENTIFIER '=' expression ';'     { 
          // Safe symbol table integration
          if (!add_symbol_safe($2, 
                              ($4 && $4->type == NODE_LITERAL) ? $4->value : 0,
                              ($4 && $4->type == NODE_LITERAL) ? 1 : 0)) {
              YYERROR;
          }
          $$ = createASTNode(NODE_VARIABLE_DECL, strdup($2), 0, $4, NULL); 
      }
    | IDENTIFIER '=' expression ';'         { 
          // Check if variable exists and mark as assigned
          if (!is_declared_safe($1)) {
              YYERROR;
          }
          if (!mark_symbol_assigned($1)) {
              YYERROR;
          }
          $$ = createASTNode(NODE_ASSIGNMENT, strdup($1), 0, $3, NULL); 
      }
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
  | CONSOLE '.' LOG '(' STRING ',' IDENTIFIER ')'           { 
      if (!mark_symbol_used($7)) {
          YYERROR;
      }
      $$ = createASTNode(NODE_CONSOLE_LOG, strdup($5), 0, createASTNode(NODE_VARIABLE, strdup($7), 0, NULL, NULL), NULL); 
  }
  | CONSOLE '.' LOG '(' STRING ',' INTEGER ')'              { $$ = createASTNode(NODE_CONSOLE_LOG, strdup($5), 0, createASTNode(NODE_LITERAL, NULL, $7, NULL, NULL), NULL); }
  | CONSOLE '.' LOG '(' IDENTIFIER ')'                      { 
      if (!mark_symbol_used($5)) {
          YYERROR;
      }
      $$ = createASTNode(NODE_CONSOLE_LOG, NULL, 0, createASTNode(NODE_VARIABLE, strdup($5), 0, NULL, NULL), NULL); 
  }
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
    | IDENTIFIER                            { 
          // Safe variable usage checking
          if (!mark_symbol_used($1)) {
              YYERROR;
          }
          $$ = createASTNode(NODE_VARIABLE, strdup($1), 0, NULL, NULL); 
      }
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

/* C Code Section - Implementation of all functions */

// Error reporting functions
void report_error(int error_type, const char* format, ...) {
    va_list args;
    va_start(args, format);
    
    const char* error_types[] = {
        "Info", 
        "Memory Error", 
        "Redeclaration Error", 
        "Undeclared Variable Error",
        "Semantic Error",
        "Syntax Error",
        "File I/O Error"
    };
    
    fprintf(stderr, "%s at line %d: ", 
            (error_type < 7) ? error_types[error_type] : "Error", 
            current_line);
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    
    va_end(args);
}

void report_warning(const char* format, ...) {
    va_list args;
    va_start(args, format);
    
    fprintf(stderr, "Warning at line %d: ", current_line);
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    
    va_end(args);
}

// Memory safety helpers
char* safe_strdup(const char* str) {
    if (!str) {
        report_error(ERROR_MEMORY, "Attempting to duplicate NULL string");
        return NULL;
    }
    
    char* dup = strdup(str);
    if (!dup) {
        report_error(ERROR_MEMORY, "Memory allocation failed for string duplication");
        return NULL;
    }
    
    return dup;
}

int validate_identifier(const char* name) {
    if (!name) {
        report_error(ERROR_SEMANTIC, "Identifier name is NULL");
        return 0;
    }
    
    if (strlen(name) == 0) {
        report_error(ERROR_SEMANTIC, "Identifier name is empty");
        return 0;
    }
    
    if (strlen(name) > 255) {
        report_warning("Identifier '%s' is very long (%zu characters)", name, strlen(name));
    }
    
    // Check if it starts with a letter or underscore
    if (!((name[0] >= 'a' && name[0] <= 'z') || 
          (name[0] >= 'A' && name[0] <= 'Z') || 
          name[0] == '_')) {
        report_error(ERROR_SEMANTIC, "Invalid identifier '%s': must start with letter or underscore", name);
        return 0;
    }
    
    // Check for reserved keywords
    const char* reserved[] = {"var", "function", "const", "class", "return", "while", "for", NULL};
    for (int i = 0; reserved[i]; i++) {
        if (strcmp(name, reserved[i]) == 0) {
            report_error(ERROR_SEMANTIC, "'%s' is a reserved keyword and cannot be used as an identifier", name);
            return 0;
        }
    }
    
    return 1;
}

// Enhanced symbol table functions
int add_symbol_safe(char* name, int value, int is_initialized) {
    if (!validate_identifier(name)) {
        return 0;
    }
    
    if (is_declared_safe(name)) {
        Symbol* existing = lookup_symbol_safe(name);
        if (existing) {
            report_error(ERROR_REDECLARATION, "Variable '%s' is already declared at line %d", 
                        name, existing->line_declared);
        } else {
            report_error(ERROR_REDECLARATION, "Variable '%s' is already declared", name);
        }
        return 0;
    }
    
    Symbol* new_symbol = (Symbol*)malloc(sizeof(Symbol));
    if (!new_symbol) {
        report_error(ERROR_MEMORY, "Memory allocation failed for symbol '%s'", name);
        return 0;
    }
    
    new_symbol->name = safe_strdup(name);
    if (!new_symbol->name) {
        free(new_symbol);
        return 0;
    }
    
    new_symbol->value = value;
    new_symbol->is_initialized = is_initialized;
    new_symbol->line_declared = current_line;
    new_symbol->times_used = 0;
    new_symbol->is_assigned = is_initialized;
    new_symbol->next = symbol_table;
    
    symbol_table = new_symbol;
    symbol_count++;
    
    printf("✓ Added symbol: %s = %d (initialized: %s) at line %d\n", 
           name, value, is_initialized ? "yes" : "no", current_line);
    
    return 1;
}

Symbol* lookup_symbol_safe(char* name) {
    if (!validate_identifier(name)) {
        return NULL;
    }
    
    Symbol* current = symbol_table;
    while (current) {
        if (strcmp(current->name, name) == 0) {
            return current;
        }
        current = current->next;
    }
    
    return NULL;
}

int is_declared_safe(char* name) {
    if (!name) {
        report_error(ERROR_SEMANTIC, "Checking declaration of NULL identifier");
        return 0;
    }
    
    return lookup_symbol_safe(name) != NULL;
}

int mark_symbol_used(char* name) {
    if (!validate_identifier(name)) {
        return 0;
    }
    
    Symbol* symbol = lookup_symbol_safe(name);
    if (!symbol) {
        report_error(ERROR_UNDECLARED_VAR, "Variable '%s' is not declared", name);
        return 0;
    }
    
    symbol->times_used++;
    
    if (!symbol->is_initialized && !symbol->is_assigned) {
        report_warning("Variable '%s' may be used before initialization (declared at line %d)", 
                      name, symbol->line_declared);
    }
    
    return 1;
}

int mark_symbol_assigned(char* name) {
    if (!validate_identifier(name)) {
        return 0;
    }
    
    Symbol* symbol = lookup_symbol_safe(name);
    if (!symbol) {
        report_error(ERROR_UNDECLARED_VAR, "Cannot assign to undeclared variable '%s'", name);
        return 0;
    }
    
    symbol->is_assigned = 1;
    symbol->is_initialized = 1;
    
    return 1;
}

void validate_symbol_usage() {
    printf("\n=== Symbol Usage Validation ===\n");
    
    Symbol* current = symbol_table;
    int unused_count = 0;
    int uninitialized_count = 0;
    
    while (current) {
        if (current->times_used == 0) {
            report_warning("Variable '%s' declared at line %d is never used", 
                          current->name, current->line_declared);
            unused_count++;
        }
        
        if (!current->is_initialized) {
            report_warning("Variable '%s' declared at line %d is never initialized", 
                          current->name, current->line_declared);
            uninitialized_count++;
        }
        
        current = current->next;
    }
    
    printf("Unused variables: %d\n", unused_count);
    printf("Uninitialized variables: %d\n", uninitialized_count);
    printf("Total symbols: %d\n", symbol_count);
    printf("==============================\n\n");
}

void print_symbol_table_enhanced() {
    printf("\n=== Enhanced Symbol Table ===\n");
    
    if (!symbol_table) {
        printf("(empty)\n");
        printf("============================\n\n");
        return;
    }
    
    printf("%-15s %-8s %-12s %-8s %-8s %-8s\n", 
           "Name", "Value", "Initialized", "Line", "Used", "Assigned");
    printf("%-15s %-8s %-12s %-8s %-8s %-8s\n", 
           "----", "-----", "-----------", "----", "----", "--------");
    
    Symbol* current = symbol_table;
    while (current) {
        printf("%-15s %-8d %-12s %-8d %-8d %-8s\n", 
               current->name, 
               current->value,
               current->is_initialized ? "yes" : "no",
               current->line_declared,
               current->times_used,
               current->is_assigned ? "yes" : "no");
        current = current->next;
    }
    
    printf("============================\n");
    printf("Total symbols: %d\n\n", symbol_count);
}

void free_symbol_table_safe() {
    Symbol* current = symbol_table;
    int freed_count = 0;
    
    while (current) {
        Symbol* temp = current;
        current = current->next;
        
        if (temp->name) {
            free(temp->name);
        }
        
        free(temp);
        freed_count++;
    }
    
    symbol_table = NULL;
    symbol_count = 0;
    
    printf("✓ Freed %d symbols from symbol table\n", freed_count);
}

void get_symbol_statistics() {
    int total = 0;
    int initialized = 0;
    int used = 0;
    int assigned = 0;
    
    Symbol* current = symbol_table;
    while (current) {
        total++;
        if (current->is_initialized) initialized++;
        if (current->times_used > 0) used++;
        if (current->is_assigned) assigned++;
        current = current->next;
    }
    
    printf("\n=== Symbol Statistics ===\n");
    printf("Total symbols: %d\n", total);
    printf("Initialized: %d (%.1f%%)\n", initialized, total ? (100.0 * initialized / total) : 0);
    printf("Used: %d (%.1f%%)\n", used, total ? (100.0 * used / total) : 0);
    printf("Assigned: %d (%.1f%%)\n", assigned, total ? (100.0 * assigned / total) : 0);
    printf("========================\n\n");
}

// Function to create AST nodes
ASTNode* createASTNode(NodeType type, char* identifier, int value, ASTNode* left, ASTNode* right) {
    ASTNode* newNode = (ASTNode*)malloc(sizeof(ASTNode));
    if (!newNode) {
        report_error(ERROR_MEMORY, "Failed to allocate memory for AST node");
        return NULL;
    }
    newNode->type = type;
    newNode->identifier = identifier;
    newNode->value = value;
    newNode->left = left;
    newNode->right = right;
    return newNode;
}

void yyerror(const char *s) {
    report_error(ERROR_SYNTAX, "%s", s);
}

// Updated generateCode function
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
            // Symbol was already added safely during parsing
            fprintf(output, "    int %s = ", node->identifier);
            generateCode(node->left, output);
            fprintf(output, ";\n");
            break;
            
        case NODE_ASSIGNMENT:
            // Variable existence was already checked during parsing
            Symbol* sym = lookup_symbol_safe(node->identifier);
            if (sym && node->left && node->left->type == NODE_LITERAL) {
                sym->value = node->left->value;
            }
            fprintf(output, "    %s = ", node->identifier);
            generateCode(node->left, output);
            fprintf(output, ";\n");
            break;
            
        case NODE_CONSOLE_LOG:
            fprintf(output, "    printf(");
            if (node->identifier) {
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

// Updated main function
int main() {
    extern FILE *yyin;
    
    // Initialize current_line
    current_line = 1;
    
    yyin = fopen("input.txt", "r");
    if (!yyin) {
        fprintf(stderr, "Error: Could not open input.txt\n");
        return 1;
    }
    
    printf("Starting compilation...\n");
    
    if (yyparse() == 0) {
        printf("✓ Parsing successful!\n");
        
        // Enhanced symbol table reporting
        print_symbol_table_enhanced();
        
        // Validate symbol usage patterns
        validate_symbol_usage();
        
        // Get statistics
        get_symbol_statistics();
        
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
            printf("✓ C code generated in output.c\n");
        }
        
        freeAST(root);
        free_symbol_table_safe();
    } else {
        fprintf(stderr, "✗ Parsing failed!\n");
        print_symbol_table_enhanced();
        free_symbol_table_safe();
    }
    
    fclose(yyin);
    return 0;
}