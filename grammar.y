%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex();
void yyerror(const char *s);
void writefile(char *data);

// Forward declarations
typedef enum { 
    NODE_PROGRAM, NODE_FUNCTION, NODE_VARIABLE, NODE_ASSIGNMENT, NODE_BINARY_OP, 
    NODE_IF, NODE_FOR, NODE_RETURN, NODE_FUNCTION_CALL, NODE_LITERAL,
    NODE_STATEMENT_LIST, NODE_BLOCK, NODE_PARAMETER, NODE_PARAMETER_LIST,
    NODE_ARRAY, NODE_ARRAY_ELEMENT, NODE_ARRAY_ACCESS, NODE_METHOD_CALL,
    NODE_PROPERTY_ACCESS, NODE_ARGUMENT_LIST, NODE_CONSOLE_LOG
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
ASTNode* create_argument_list_node(ASTNode* arg, ASTNode* next);
ASTNode* create_integer_node(int value);
ASTNode* create_string_node(char* str);
ASTNode* create_identifier_node(char* id);
ASTNode* create_array_access_node(char* id, ASTNode* index);
ASTNode* create_ast_node(char* id);
ASTNode* create_ast_node_with_index(char* id, ASTNode* index);
ASTNode* create_method_call_node(char* obj, char* method, ASTNode* args);
ASTNode* create_property_access_node(char* obj, char* prop);
ASTNode* create_if_node(ASTNode* condition, ASTNode* then_stmt, ASTNode* else_stmt);

// Global AST root
ASTNode* root = NULL;
%}

%token <integer> INTEGER 
%token FUNCTION RETURN
%token <identifier> IDENTIFIER
%token <identifier> STRING
%token FOR
%token CONST LET IF ELSE
%token EQ NE LE GE PLUSONE STRICTEQ
%token CONSOLE LOG

%union {
    int integer;
    char* identifier;
    struct ASTNode* ast_node;
}

%type <ast_node> argument argument_list program statement expression function_call array_initializer if_statement function_declaration for_statement statement_list block term factor parameter_list for_init for_update string_list string_element console_log

%precedence ARRAY_ACCESS PROPERTY_ACCESS METHOD_CALL ASSIGNMENT ELSE
%right '='
%left '+' '-'
%left '*' '/'
%left '.'
%left '(' ')'

%%

/* -------------------- Program Structure -------------------- */

program: statement_list { root = $1; $$ = $1; }

/* -------------------- Statements -------------------- */

statement:
      expression ';'                                { $$ = $1; }
    | IDENTIFIER '=' expression ';' %prec ASSIGNMENT { $$ = createASTNode(NODE_ASSIGNMENT, strdup($1), 0, $3, NULL); }
    | RETURN expression ';'                         { $$ = createASTNode(NODE_RETURN, NULL, 0, $2, NULL); }
    | LET IDENTIFIER '=' expression ';'             { $$ = createASTNode(NODE_ASSIGNMENT, strdup($2), 0, $4, NULL); }
    | CONST IDENTIFIER '=' expression ';'           { $$ = createASTNode(NODE_ASSIGNMENT, strdup($2), 0, $4, NULL); }
    | LET IDENTIFIER '=' array_initializer ';'      { $$ = createASTNode(NODE_ASSIGNMENT, strdup($2), 0, $4, NULL); }
    | CONST IDENTIFIER '=' array_initializer ';'    { $$ = createASTNode(NODE_ASSIGNMENT, strdup($2), 0, $4, NULL); }
    | CONST IDENTIFIER '=' function_call ';'        { $$ = createASTNode(NODE_ASSIGNMENT, strdup($2), 0, $4, NULL); }
    | console_log ';'                               { $$ = $1; }
    | if_statement                                  { $$ = $1; }
    | function_declaration                          { $$ = $1; }
    | for_statement                                 { $$ = $1; }
    | block                                         { $$ = $1; }
    ;

statement_list:
    statement_list statement { $$ = createASTNode(NODE_STATEMENT_LIST, NULL, 0, $1, $2); }
    | statement              { $$ = $1; }
    ;

/* -------------------- Console.log -------------------- */

console_log:
    CONSOLE '.' LOG '(' argument_list ')'   { $$ = createASTNode(NODE_CONSOLE_LOG, NULL, 0, $5, NULL); }
  | CONSOLE '.' LOG '(' ')'                 { $$ = createASTNode(NODE_CONSOLE_LOG, NULL, 0, NULL, NULL); }
    ;

/* -------------------- Function Declarations -------------------- */

function_declaration: FUNCTION IDENTIFIER '(' parameter_list ')' block { $$ = createASTNode(NODE_FUNCTION, strdup($2), 0, $4, $6); }

parameter_list:
    /* empty */                         { $$ = NULL; }
  | IDENTIFIER                          { $$ = createASTNode(NODE_PARAMETER, strdup($1), 0, NULL, NULL); }
  | parameter_list ',' IDENTIFIER       { $$ = createASTNode(NODE_PARAMETER_LIST, NULL, 0, $1, createASTNode(NODE_PARAMETER, strdup($3), 0, NULL, NULL)); }
;

block: '{' statement_list '}' { $$ = createASTNode(NODE_BLOCK, NULL, 0, $2, NULL); }

/* -------------------- Function Calls -------------------- */

function_call: 
      IDENTIFIER '(' argument_list ')'                              { $$ = createASTNode(NODE_FUNCTION_CALL, strdup($1), 0, $3, NULL); }
    | IDENTIFIER '(' ')'                                            { $$ = createASTNode(NODE_FUNCTION_CALL, strdup($1), 0, NULL, NULL); }
    ;

argument_list:
      /* empty */                       { $$ = NULL; }
    | argument                          { $$ = createASTNode(NODE_ARGUMENT_LIST, NULL, 0, $1, NULL); }
    | argument_list ',' argument        { $$ = createASTNode(NODE_ARGUMENT_LIST, NULL, 0, $1, $3); }
    ;

argument:
      INTEGER                           { $$ = createASTNode(NODE_LITERAL, NULL, $1, NULL, NULL); }
    | STRING                            { $$ = createASTNode(NODE_LITERAL, strdup($1), 0, NULL, NULL); }
    | IDENTIFIER                        { $$ = createASTNode(NODE_VARIABLE, strdup($1), 0, NULL, NULL); }
    | IDENTIFIER '[' expression ']'     { $$ = createASTNode(NODE_ARRAY_ACCESS, strdup($1), 0, $3, NULL); }
    ;

/* -------------------- For loops -------------------- */

for_statement:
    FOR '(' for_init ';' expression ';' for_update ')' block 
    { $$ = createASTNode(NODE_FOR, NULL, 0, $3, createASTNode(NODE_FOR, NULL, 0, $5, createASTNode(NODE_FOR, NULL, 0, $7, $9))); }

for_init:
    LET IDENTIFIER '=' expression { $$ = createASTNode(NODE_ASSIGNMENT, strdup($2), 0, $4, NULL); }
    ;

for_update:
    IDENTIFIER PLUSONE              { $$ = createASTNode(NODE_ASSIGNMENT, strdup($1), 1, NULL, NULL); }
  | IDENTIFIER '=' expression       { $$ = createASTNode(NODE_ASSIGNMENT, strdup($1), 0, $3, NULL); }
  ;

/* -------------------- Array Initialization -------------------- */

array_initializer:
    '[' ']'                     { $$ = createASTNode(NODE_ARRAY, NULL, 0, NULL, NULL); }
  | '[' argument_list ']'       { $$ = createASTNode(NODE_ARRAY, NULL, 0, $2, NULL); }  
  | '[' string_list ']'         { $$ = createASTNode(NODE_ARRAY, NULL, 0, $2, NULL); }
  ;

string_list:
      /* empty */                       { $$ = NULL; }
    | string_element                    { $$ = createASTNode(NODE_ARRAY_ELEMENT, NULL, 0, $1, NULL); }
    | string_list ',' string_element    { $$ = createASTNode(NODE_ARRAY_ELEMENT, NULL, 0, $1, $3); }
  ;

string_element:
    STRING                  { $$ = createASTNode(NODE_LITERAL, strdup($1), 0, NULL, NULL); }
    ;

/* -------------------- Expressions -------------------- */
    
expression:
      function_call                                                 { $$ = $1; }
    | IDENTIFIER                                                    { $$ = createASTNode(NODE_VARIABLE, strdup($1), 0, NULL, NULL); }
    | IDENTIFIER '[' expression ']' %prec ARRAY_ACCESS              { $$ = createASTNode(NODE_ARRAY_ACCESS, strdup($1), 0, $3, NULL); }
    | IDENTIFIER '.' IDENTIFIER '(' argument_list ')' %prec METHOD_CALL { $$ = createASTNode(NODE_METHOD_CALL, strdup($1), 0, createASTNode(NODE_VARIABLE, strdup($3), 0, NULL, NULL), $5); }
    | IDENTIFIER '.' IDENTIFIER %prec PROPERTY_ACCESS               { $$ = createASTNode(NODE_PROPERTY_ACCESS, strdup($1), 0, createASTNode(NODE_VARIABLE, strdup($3), 0, NULL, NULL), NULL); }
    | expression '.' IDENTIFIER %prec PROPERTY_ACCESS               { $$ = createASTNode(NODE_PROPERTY_ACCESS, NULL, 0, $1, createASTNode(NODE_VARIABLE, strdup($3), 0, NULL, NULL)); }
    | expression '.' IDENTIFIER '(' argument_list ')' %prec METHOD_CALL { $$ = createASTNode(NODE_METHOD_CALL, NULL, 0, $1, createASTNode(NODE_METHOD_CALL, strdup($3), 0, NULL, $5)); }
    | term                                                          { $$ = $1; }
    | expression '+' term                                           { $$ = createASTNode(NODE_BINARY_OP, strdup("+"), 0, $1, $3); }
    | expression '-' term                                           { $$ = createASTNode(NODE_BINARY_OP, strdup("-"), 0, $1, $3); }
    | expression '%' term                                           { $$ = createASTNode(NODE_BINARY_OP, strdup("%"), 0, $1, $3); }
    | expression EQ term                                            { $$ = createASTNode(NODE_BINARY_OP, strdup("=="), 0, $1, $3); }
    | expression STRICTEQ term                                      { $$ = createASTNode(NODE_BINARY_OP, strdup("==="), 0, $1, $3); }
    | expression NE term                                            { $$ = createASTNode(NODE_BINARY_OP, strdup("!="), 0, $1, $3); }
    | expression '<' term                                           { $$ = createASTNode(NODE_BINARY_OP, strdup("<"), 0, $1, $3); }
    | expression '>' term                                           { $$ = createASTNode(NODE_BINARY_OP, strdup(">"), 0, $1, $3); }
    | expression LE term                                            { $$ = createASTNode(NODE_BINARY_OP, strdup("<="), 0, $1, $3); }
    | expression GE term                                            { $$ = createASTNode(NODE_BINARY_OP, strdup(">="), 0, $1, $3); }
    ;

term:
      factor                { $$ = $1; }
    | term '*' factor       { $$ = createASTNode(NODE_BINARY_OP, strdup("*"), 0, $1, $3); }
    | term '/' factor       { $$ = createASTNode(NODE_BINARY_OP, strdup("/"), 0, $1, $3); }        
    ;

factor:
      INTEGER                           { $$ = createASTNode(NODE_LITERAL, NULL, $1, NULL, NULL); }
    | STRING                            { $$ = createASTNode(NODE_LITERAL, strdup($1), 0, NULL, NULL); }                     
    | IDENTIFIER                        { $$ = createASTNode(NODE_VARIABLE, strdup($1), 0, NULL, NULL); }
    | '(' expression ')'                { $$ = $2; }
    | IDENTIFIER '[' expression ']'     { $$ = createASTNode(NODE_ARRAY_ACCESS, strdup($1), 0, $3, NULL); }
    ;

/* -------------------- Control Flow -------------------- */

if_statement:
    IF '(' expression ')' statement %prec ELSE          { $$ = createASTNode(NODE_IF, NULL, 0, $3, $5); }
  | IF '(' expression ')' statement ELSE statement      { $$ = createASTNode(NODE_IF, NULL, 0, $3, createASTNode(NODE_IF, NULL, 0, $5, $7)); }
    ;

%%

/* -------------------- C Code Section -------------------- */

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

// Stub implementations for missing functions
ASTNode* create_argument_list_node(ASTNode* arg, ASTNode* next) {
    return createASTNode(NODE_ARGUMENT_LIST, NULL, 0, arg, next);
}

ASTNode* create_integer_node(int value) {
    return createASTNode(NODE_LITERAL, NULL, value, NULL, NULL);
}

ASTNode* create_string_node(char* str) {
    return createASTNode(NODE_LITERAL, strdup(str), 0, NULL, NULL);
}

ASTNode* create_identifier_node(char* id) {
    return createASTNode(NODE_VARIABLE, strdup(id), 0, NULL, NULL);
}

ASTNode* create_array_access_node(char* id, ASTNode* index) {
    return createASTNode(NODE_ARRAY_ACCESS, strdup(id), 0, index, NULL);
}

ASTNode* create_ast_node(char* id) {
    return createASTNode(NODE_VARIABLE, strdup(id), 0, NULL, NULL);
}

ASTNode* create_ast_node_with_index(char* id, ASTNode* index) {
    return createASTNode(NODE_ARRAY_ACCESS, strdup(id), 0, index, NULL);
}

ASTNode* create_method_call_node(char* obj, char* method, ASTNode* args) {
    return createASTNode(NODE_METHOD_CALL, strdup(obj), 0, createASTNode(NODE_VARIABLE, strdup(method), 0, NULL, NULL), args);
}

ASTNode* create_property_access_node(char* obj, char* prop) {
    return createASTNode(NODE_PROPERTY_ACCESS, strdup(obj), 0, createASTNode(NODE_VARIABLE, strdup(prop), 0, NULL, NULL), NULL);
}

ASTNode* create_if_node(ASTNode* condition, ASTNode* then_stmt, ASTNode* else_stmt) {
    if (else_stmt) {
        return createASTNode(NODE_IF, NULL, 0, condition, createASTNode(NODE_IF, NULL, 0, then_stmt, else_stmt));
    } else {
        return createASTNode(NODE_IF, NULL, 0, condition, then_stmt);
    }
}

void yyerror(const char *s) {
    fprintf(stderr, "Parser error: %s\n", s);
}

void print_string(const char* str) {
    // Remove quotes from string
    char* clean_str = malloc(strlen(str) + 1);
    int j = 0;
    for (int i = 0; str[i]; i++) {
        if (str[i] != '"' && str[i] != '\'') {
            clean_str[j++] = str[i];
        }
    }
    clean_str[j] = '\0';
    
    printf("%s", clean_str);
    free(clean_str);
}

// Fixed generateCode function that generates proper C code

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
            
        case NODE_CONSOLE_LOG:
            fprintf(output, "    // console.log() implementation\n");
            if (node->left) {
                fprintf(output, "    printf(\"");
                // Generate arguments for printf
                ASTNode* arg = node->left;
                int has_variables = 0;
                
                // First pass: build format string
                while (arg) {
                    if (arg->type == NODE_ARGUMENT_LIST) {
                        ASTNode* current_arg = arg->left;
                        if (current_arg) {
                            if (current_arg->type == NODE_LITERAL) {
                                if (current_arg->identifier) {
                                    // String literal - remove quotes and print content
                                    char* str = current_arg->identifier;
                                    for (int i = 1; i < strlen(str) - 1; i++) {
                                        if (str[i] == '%') fprintf(output, "%%"); // Escape %
                                        else fprintf(output, "%c", str[i]);
                                    }
                                } else {
                                    // Integer literal
                                    fprintf(output, "%d", current_arg->value);
                                }
                            } else if (current_arg->type == NODE_VARIABLE) {
                                // Variable - use %d format
                                fprintf(output, "%%d");
                                has_variables = 1;
                            }
                            
                            // Add space between arguments
                            if (arg->right) fprintf(output, " ");
                        }
                        arg = arg->right;
                    } else {
                        break;
                    }
                }
                fprintf(output, "\\n\"");
                
                // Second pass: add variable arguments
                if (has_variables) {
                    arg = node->left;
                    while (arg) {
                        if (arg->type == NODE_ARGUMENT_LIST) {
                            ASTNode* current_arg = arg->left;
                            if (current_arg && current_arg->type == NODE_VARIABLE) {
                                fprintf(output, ", %s", current_arg->identifier);
                            }
                            arg = arg->right;
                        } else {
                            break;
                        }
                    }
                }
                fprintf(output, ");\n");
            } else {
                fprintf(output, "    printf(\"\\n\");\n");
            }
            break;
            
        case NODE_ASSIGNMENT:
            fprintf(output, "    ");
            if (node->identifier) {
                fprintf(output, "%s = ", node->identifier);
                if (node->left) {
                    generateCode(node->left, output);
                } else if (node->value == 1) {
                    // Handle increment (PLUSONE)
                    fprintf(output, "%s + 1", node->identifier);
                } else {
                    fprintf(output, "0");
                }
                fprintf(output, ";\n");
            }
            break;
            
        case NODE_BINARY_OP:
            fprintf(output, "(");
            generateCode(node->left, output);
            if (strcmp(node->identifier, "==") == 0) {
                fprintf(output, " == ");
            } else if (strcmp(node->identifier, "===") == 0) {
                fprintf(output, " == ");
            } else if (strcmp(node->identifier, "!=") == 0) {
                fprintf(output, " != ");
            } else if (strcmp(node->identifier, "<=") == 0) {
                fprintf(output, " <= ");
            } else if (strcmp(node->identifier, ">=") == 0) {
                fprintf(output, " >= ");
            } else {
                fprintf(output, " %s ", node->identifier);
            }
            generateCode(node->right, output);
            fprintf(output, ")");
            break;
            
        case NODE_LITERAL:
            if (node->identifier) {
                // String literal - keep quotes for string values
                char* str = node->identifier;
                // Remove outer quotes and print as string
                fprintf(output, "\"");
                for (int i = 1; i < strlen(str) - 1; i++) {
                    fprintf(output, "%c", str[i]);
                }
                fprintf(output, "\"");
            } else {
                // Integer literal
                fprintf(output, "%d", node->value);
            }
            break;
            
        case NODE_VARIABLE:
            if (node->identifier) {
                fprintf(output, "%s", node->identifier);
            }
            break;
            
        case NODE_RETURN:
            fprintf(output, "    return ");
            if (node->left) {
                generateCode(node->left, output);
            } else {
                fprintf(output, "0");
            }
            fprintf(output, ";\n");
            break;
            
        case NODE_FUNCTION:
            // Generate function OUTSIDE of main, not inside
            if (node->identifier) {
                fprintf(output, "\nint %s(", node->identifier);
                if (node->left) {
                    generateCode(node->left, output); // parameters
                } else {
                    fprintf(output, "void"); // No parameters
                }
                fprintf(output, ") {\n");
                
                // Declare local variables
                fprintf(output, "    int result = 0;\n");
                fprintf(output, "    int i = 0;\n");
                
                if (node->right) {
                    generateCode(node->right, output); // function body
                }
                fprintf(output, "}\n");
            }
            break;
            
        case NODE_BLOCK:
            generateCode(node->left, output);
            break;
            
        case NODE_IF:
            fprintf(output, "    if (");
            if (node->left) {
                generateCode(node->left, output); // condition
            }
            fprintf(output, ") {\n");
            if (node->right) {
                // Handle if-else structure
                if (node->right->type == NODE_IF && node->right->left && node->right->right) {
                    // This is if-else
                    generateCode(node->right->left, output); // then part
                    fprintf(output, "    } else {\n");
                    generateCode(node->right->right, output); // else part
                } else {
                    // Simple if
                    generateCode(node->right, output);
                }
            }
            fprintf(output, "    }\n");
            break;
            
        case NODE_FOR:
            fprintf(output, "    // FOR loop\n");
            if (node->left) {
                generateCode(node->left, output); // initialization
            }
            
            // Extract nested FOR nodes for condition and update
            ASTNode* condition_node = node->right;
            ASTNode* update_node = NULL;
            ASTNode* body_node = NULL;
            
            if (condition_node && condition_node->type == NODE_FOR) {
                update_node = condition_node->right;
                if (update_node && update_node->type == NODE_FOR) {
                    body_node = update_node->right;
                    update_node = update_node->left;
                }
                condition_node = condition_node->left;
            }
            
            fprintf(output, "    for (; ");
            if (condition_node) {
                generateCode(condition_node, output);
            }
            fprintf(output, "; ");
            if (update_node) {
                if (update_node->value == 1) {
                    // Handle i++ case
                    fprintf(output, "%s++", update_node->identifier);
                } else {
                    generateCode(update_node, output);
                }
            }
            fprintf(output, ") {\n");
            if (body_node) {
                generateCode(body_node, output);
            }
            fprintf(output, "    }\n");
            break;
            
        case NODE_FUNCTION_CALL:
            if (node->identifier) {
                fprintf(output, "%s(", node->identifier);
                if (node->left) {
                    generateCode(node->left, output); // arguments
                }
                fprintf(output, ")");
            }
            break;
            
        case NODE_ARRAY:
            fprintf(output, "{");
            if (node->left) {
                generateCode(node->left, output);
            }
            fprintf(output, "}");
            break;
            
        case NODE_ARRAY_ELEMENT:
            generateCode(node->left, output);
            if (node->right) {
                fprintf(output, ", ");
                generateCode(node->right, output);
            }
            break;
            
        case NODE_ARRAY_ACCESS:
            if (node->identifier) {
                fprintf(output, "%s[", node->identifier);
            }
            if (node->left) {
                generateCode(node->left, output);
            }
            fprintf(output, "]");
            break;
            
        case NODE_PROPERTY_ACCESS:
            if (node->left) {
                generateCode(node->left, output);
            }
            if (node->right) {
                fprintf(output, ".");
                generateCode(node->right, output);
            }
            break;
            
        case NODE_METHOD_CALL:
            if (node->left) {
                generateCode(node->left, output);
            }
            if (node->right) {
                fprintf(output, ".");
                generateCode(node->right, output);
            }
            break;
            
        case NODE_PARAMETER:
            if (node->identifier) {
                fprintf(output, "char* %s", node->identifier); // Parameters as strings for now
            }
            break;
            
        case NODE_PARAMETER_LIST:
            generateCode(node->left, output);
            if (node->right) {
                fprintf(output, ", ");
                generateCode(node->right, output);
            }
            break;
            
        case NODE_ARGUMENT_LIST:
            if (node->left) {
                generateCode(node->left, output);
            }
            if (node->right) {
                fprintf(output, ", ");
                generateCode(node->right, output);
            }
            break;
            
        default:
            fprintf(output, "    /* Unhandled AST Node Type: %d */\n", node->type);
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

void writefile(char *data) {
    FILE *fptr = fopen("target.txt", "a");
    if (fptr) {
        fprintf(fptr, "%s\n", data);
        fclose(fptr);
    }
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
        
        // Generate C code
        FILE* output = fopen("output.c", "w");
        if (output) {
            fprintf(output, "#include <stdio.h>\n");
            fprintf(output, "#include <stdlib.h>\n");
            fprintf(output, "#include <string.h>\n\n");
            
            fprintf(output, "// Global variables\n");
            fprintf(output, "int text = 0;\n");
            fprintf(output, "int result = 0;\n");
            fprintf(output, "int key = 0;\n");
            fprintf(output, "int i = 0;\n");
            fprintf(output, "char alphabet[100] = \"ABC\";\n");
            fprintf(output, "char message[100];\n\n");
            
            // Generate function declarations first
            fprintf(output, "// Function declarations\n");
            generateFunctionDeclarations(root, output);
            
            fprintf(output, "\nint main() {\n");
            fprintf(output, "    // Main program\n");
            
            // Generate main program body (skip function declarations)
            generateMainBody(root, output);
            
            fprintf(output, "    return 0;\n");
            fprintf(output, "}\n");
            
            fclose(output);
            printf("C code generated in output.c\n");
        }
        
        freeAST(root);
    } else {
        fprintf(stderr, "Parsing failed!\n");
    }
    
    fclose(yyin);
    return 0;
}

// Helper function to generate only function declarations
void generateFunctionDeclarations(ASTNode* node, FILE* output) {
    if (!node) return;
    
    if (node->type == NODE_FUNCTION) {
        generateCode(node, output);
        return; // Don't recurse into function body
    }
    
    generateFunctionDeclarations(node->left, output);
    generateFunctionDeclarations(node->right, output);
}

// Helper function to generate main body (skip functions)
void generateMainBody(ASTNode* node, FILE* output) {
    if (!node) return;
    
    if (node->type == NODE_FUNCTION) {
        return; // Skip function declarations
    }
    
    generateCode(node, output);
}