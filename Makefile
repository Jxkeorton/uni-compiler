all: build/parser.exe
	@echo "Running parser..."
	./build/parser.exe

build/parser.exe: build/lex.yy.c build/grammar.tab.c | output
	@echo "Compiling..."
	gcc -o build/parser.exe build/lex.yy.c build/grammar.tab.c -lfl

build/lex.yy.c: scanner.l | build
	@echo "Generating lexer..."
	flex -o build/lex.yy.c scanner.l

build/grammar.tab.c: grammar.y | build
	@echo "Generating parser..."
	bison -d -o build/grammar.tab.c grammar.y
	@move grammar.tab.h build\ 2>NUL || echo Header moved

build output:
	@mkdir $@ 2>NUL || echo Directory exists

clean:
	@rmdir /s /q build output 2>NUL || echo Already clean

.PHONY: all clean