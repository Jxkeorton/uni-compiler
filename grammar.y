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
            fprintf(output, "; console.log() implementation\n");
            if (node->left) {
                // Generate code for arguments
                ASTNode* arg = node->left;
                while (arg) {
                    if (arg->type == NODE_ARGUMENT_LIST) {
                        ASTNode* current_arg = arg->left;
                        if (current_arg) {
                            if (current_arg->type == NODE_LITERAL) {
                                if (current_arg->identifier) {
                                    // String literal
                                    fprintf(output, "    ; Print string: %s\n", current_arg->identifier);
                                    fprintf(output, "    mov eax, 4          ; sys_write\n");
                                    fprintf(output, "    mov ebx, 1          ; stdout\n");
                                    fprintf(output, "    mov ecx, str_%p     ; string address\n", (void*)current_arg);
                                    fprintf(output, "    mov edx, %d         ; string length\n", (int)strlen(current_arg->identifier) - 2); // -2 for quotes
                                    fprintf(output, "    int 0x80            ; call kernel\n");
                                } else {
                                    // Integer literal
                                    fprintf(output, "    ; Print integer: %d\n", current_arg->value);
                                    fprintf(output, "    mov eax, %d\n", current_arg->value);
                                    fprintf(output, "    call print_integer\n");
                                }
                            } else if (current_arg->type == NODE_VARIABLE) {
                                // Variable
                                fprintf(output, "    ; Print variable: %s\n", current_arg->identifier);
                                fprintf(output, "    mov eax, [%s]\n", current_arg->identifier);
                                fprintf(output, "    call print_integer\n");
                            }
                        }
                        arg = arg->right;
                    } else {
                        break;
                    }
                }
            }
            // Print newline
            fprintf(output, "    mov eax, 4          ; sys_write\n");
            fprintf(output, "    mov ebx, 1          ; stdout\n");
            fprintf(output, "    mov ecx, newline    ; newline character\n");
            fprintf(output, "    mov edx, 1          ; length\n");
            fprintf(output, "    int 0x80            ; call kernel\n");
            break;
            
        case NODE_ASSIGNMENT:
            if (node->left) {
                generateCode(node->left, output);
            }
            if (node->identifier) {
                fprintf(output, "mov [%s], eax\n", node->identifier);
            }
            break;
            
        case NODE_BINARY_OP:
            generateCode(node->left, output);
            fprintf(output, "push eax\n");
            generateCode(node->right, output);
            fprintf(output, "pop ebx\n");
            if (strcmp(node->identifier, "+") == 0) {
                fprintf(output, "add eax, ebx\n");
            } else if (strcmp(node->identifier, "-") == 0) {
                fprintf(output, "sub ebx, eax\nmov eax, ebx\n");
            } else if (strcmp(node->identifier, "*") == 0) {
                fprintf(output, "imul eax, ebx\n");
            } else if (strcmp(node->identifier, "/") == 0) {
                fprintf(output, "xchg eax, ebx\ncdq\nidiv ebx\n");
            } else if (strcmp(node->identifier, "%") == 0) {
                fprintf(output, "xchg eax, ebx\ncdq\nidiv ebx\nmov eax, edx\n");
            } else if (strcmp(node->identifier, "<") == 0) {
                fprintf(output, "cmp ebx, eax\nsetl al\nmovzx eax, al\n");
            } else if (strcmp(node->identifier, ">") == 0) {
                fprintf(output, "cmp ebx, eax\nsetg al\nmovzx eax, al\n");
            } else if (strcmp(node->identifier, "==") == 0) {
                fprintf(output, "cmp ebx, eax\nsete al\nmovzx eax, al\n");
            }
            break;
            
        case NODE_LITERAL:
            if (node->identifier) {
                fprintf(output, "; String literal: %s\n", node->identifier);
                fprintf(output, "mov eax, str_%p\n", (void*)node);
            } else {
                fprintf(output, "mov eax, %d\n", node->value);
            }
            break;
            
        case NODE_VARIABLE:
            if (node->identifier) {
                fprintf(output, "mov eax, [%s]\n", node->identifier);
            }
            break;
            
        case NODE_RETURN:
            if (node->left) {
                generateCode(node->left, output);
            }
            fprintf(output, "ret\n");
            break;
            
        case NODE_FUNCTION:
            if (node->identifier) {
                fprintf(output, "%s:\n", node->identifier);
                fprintf(output, "push ebp\nmov ebp, esp\n");
            }
            if (node->right) {
                generateCode(node->right, output); // function body
            }
            if (node->identifier) {
                fprintf(output, "pop ebp\nret\n");
            }
            break;
            
        case NODE_BLOCK:
            generateCode(node->left, output);
            break;
            
        case NODE_IF:
            fprintf(output, "; IF statement\n");
            if (node->left) {
                generateCode(node->left, output); // condition
                fprintf(output, "cmp eax, 0\nje if_else_%p\n", (void*)node);
            }
            if (node->right) {
                generateCode(node->right, output); // then/else statements
            }
            fprintf(output, "if_else_%p:\n", (void*)node);
            break;
            
        case NODE_FOR:
            fprintf(output, "; FOR loop - simplified\n");
            if (node->left) {
                generateCode(node->left, output); // initialization
            }
            fprintf(output, "for_start_%p:\n", (void*)node);
            if (node->right) {
                generateCode(node->right, output); // body and update
            }
            fprintf(output, "jmp for_start_%p\n", (void*)node);
            fprintf(output, "for_end_%p:\n", (void*)node);
            break;
            
        case NODE_FUNCTION_CALL:
            fprintf(output, "; Function call: %s\n", node->identifier ? node->identifier : "unknown");
            if (node->left) {
                generateCode(node->left, output); // arguments
            }
            if (node->identifier) {
                fprintf(output, "call %s\n", node->identifier);
            }
            break;
            
        case NODE_ARRAY:
            fprintf(output, "; Array initialization\n");
            if (node->left) {
                generateCode(node->left, output);
            }
            break;
            
        case NODE_ARRAY_ACCESS:
            fprintf(output, "; Array access: %s[]\n", node->identifier ? node->identifier : "expr");
            if (node->left) {
                generateCode(node->left, output); // index
            }
            if (node->identifier) {
                fprintf(output, "mov ebx, %s\nadd ebx, eax\nmov eax, [ebx]\n", node->identifier);
            }
            break;
            
        case NODE_PROPERTY_ACCESS:
            fprintf(output, "; Property access\n");
            if (node->left) {
                generateCode(node->left, output);
            }
            if (node->right) {
                generateCode(node->right, output);
            }
            break;
            
        case NODE_METHOD_CALL:
            fprintf(output, "; Method call\n");
            if (node->left) {
                generateCode(node->left, output);
            }
            if (node->right) {
                generateCode(node->right, output);
            }
            break;
            
        case NODE_PARAMETER:
            fprintf(output, "; Parameter: %s\n", node->identifier ? node->identifier : "unknown");
            break;
            
        case NODE_PARAMETER_LIST:
            generateCode(node->left, output);
            generateCode(node->right, output);
            break;
            
        case NODE_ARGUMENT_LIST:
            if (node->left) {
                generateCode(node->left, output);
                fprintf(output, "push eax\n");
            }
            if (node->right) {
                generateCode(node->right, output);
            }
            break;
            
        default:
            fprintf(output, "; Unhandled AST Node Type: %d\n", node->type);
            break;
    }
}

void generateStringLiterals(ASTNode* node, FILE* output) {
    if (!node) return;
    
    if (node->type == NODE_LITERAL && node->identifier) {
        // Generate string literal data
        fprintf(output, "str_%p: db ", (void*)node);
        // Remove quotes and print each character
        char* str = node->identifier;
        int len = strlen(str);
        for (int i = 1; i < len - 1; i++) { // Skip quotes
            fprintf(output, "%d", (int)str[i]);
            if (i < len - 2) fprintf(output, ", ");
        }
        fprintf(output, "\n");
    }
    
    generateStringLiterals(node->left, output);
    generateStringLiterals(node->right, output);
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
        
        // Generate code
        FILE* output = fopen("output.asm", "w");
        if (output) {
            fprintf(output, "section .data\n");
            fprintf(output, "    ; Variables will be allocated here\n");
            fprintf(output, "    alphabet resb 100\n");
            fprintf(output, "    result resb 100\n");
            fprintf(output, "    text resb 100\n");
            fprintf(output, "    newline db 10   ; newline character\n");
            fprintf(output, "    ; String literals\n");
            generateStringLiterals(root, output);
            fprintf(output, "\n");
            
            fprintf(output, "section .text\n");
            fprintf(output, "global _start\n\n");
            
            // Add print_integer function
            fprintf(output, "print_integer:\n");
            fprintf(output, "    ; Simple integer to ASCII conversion and print\n");
            fprintf(output, "    ; This is a simplified version - only handles single digits\n");
            fprintf(output, "    add eax, 48         ; Convert to ASCII\n");
            fprintf(output, "    mov [temp_char], eax\n");
            fprintf(output, "    mov eax, 4          ; sys_write\n");
            fprintf(output, "    mov ebx, 1          ; stdout\n");
            fprintf(output, "    mov ecx, temp_char  ; character address\n");
            fprintf(output, "    mov edx, 1          ; length\n");
            fprintf(output, "    int 0x80            ; call kernel\n");
            fprintf(output, "    ret\n\n");
            
            fprintf(output, "_start:\n");
            fprintf(output, "    ; Initialize variables and call main logic\n");
            
            generateCode(root, output);
            
            fprintf(output, "\n    ; Exit program\n");
            fprintf(output, "    mov eax, 1      ; sys_exit\n");
            fprintf(output, "    mov ebx, 0      ; exit status\n");
            fprintf(output, "    int 0x80        ; call kernel\n");
            
            fprintf(output, "\nsection .bss\n");
            fprintf(output, "    temp_char resb 1    ; temporary character storage\n");
            
            fclose(output);
            printf("Assembly code generated in output.asm\n");
        }
        
        freeAST(root);
    } else {
        fprintf(stderr, "Parsing failed!\n");
    }
    
    fclose(yyin);
    return 0;
}