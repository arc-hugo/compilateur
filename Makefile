SHELL=/bin/bash

SRC=src
COMP=fascc
INTER=fastinterp

TESTDIR=test
TESTFILES=$(shell find $(TESTDIR) -name '*.c')
BUILDDIR=build

CC=gcc
CFLAGS=-Wall -g
YFALGS=-d -v

OBJCOM=$(BUILDDIR)/asmtab.o
OBJCOMP=$(BUILDDIR)/symtab.o $(BUILDDIR)/condtab.o $(BUILDDIR)/function.o $(BUILDDIR)/funtab.o $(BUILDDIR)/export.o $(BUILDDIR)/fascc.tab.o $(BUILDDIR)/fascc.yy.o
OBJINTER=$(BUILDDIR)/execute.o $(BUILDDIR)/fastinterp.tab.o $(BUILDDIR)/fastinterp.yy.o

all: $(COMP) $(INTER)

$(BUILDDIR):
	if [[ ! -d ./$(BUILDDIR) ]]; then\
		mkdir $(BUILDDIR);\
	fi

$(BUILDDIR)/%.o: $(SRC)/%.c
	@mkdir -p $(@D)
	$(CC) -c $(CFLAGS) $< -o $@

$(SRC)/%.tab.c: $(SRC)/%.y
	yacc $(YFALGS) -t $< -o $@

$(SRC)/%.yy.c: $(SRC)/%.l
	flex -o $@ $<

$(COMP): $(OBJCOM) $(OBJCOMP)
	$(CC) $(CFLAGS) $^ -o $@

$(INTER): $(OBJCOM) $(OBJINTER)
	$(CC) $(CFLAGS) $^ -o $@

clean:
	rm $(COMP) $(INTER) $(OBJCOM) $(OBJCOMP) $(OBJINTER) $(SRC)/{*.tab.h,*.output}

test: all
	for f in $(TESTFILES); do\
		echo "-------------------------------$$f--------------------------------";\
		./$(COMP) $$f;\
		printf "\nCODE C:\n\n"; nl $$f;\
		printf "\nCODE ASM:\n\n"; nl -v 0 out;\
		printf "\nINTERPRETATION:\n\n"; ./$(INTER) out; echo; \
	done
	rm out
