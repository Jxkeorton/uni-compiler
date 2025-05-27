all: build/parser.exe
	@echo Running parser...
	build\parser.exe

build/parser.exe: build/lex.yy.c build/grammar.tab.c | output
	@echo Compiling...
	gcc -o build/parser.exe build/lex.yy.c build/grammar.tab.c -lfl

build/lex.yy.c: scanner.l | build
	@echo Generating lexer...
	flex -o build/lex.yy.c scanner.l

build/grammar.tab.c: grammar.y | build
	@echo Generating parser...
	bison -d -o build/grammar.tab.c grammar.y
	@if exist grammar.tab.h move grammar.tab.h build\ >nul

build:
	@if not exist build mkdir build

output:
	@if not exist output mkdir output

clean:
	@if exist build rmdir /s /q build
	@if exist output rmdir /s /q output
	@if exist NUL del NUL

.PHONY: all clean