CC=gcc
CFLAGS=-g -Isrc/lib/lua -Iinclude
SRCDIR=src/c
CORELUA = src/lua/core
LIBS=-llua

GENERATED=include/luares.h src/c/gen/luares.c
LUAPARAMS = $(CORELUA) include/luares.h src/c/gen/luares.c lua_
LFLAGS=$(LIBS)
OBJ=\
$(SRCDIR)/main.o \
$(SRCDIR)/gen/luares.o

BUILDDIRECTORIES = $(patsubst $(SOURCE)%, $(BUILD)%, $(SRCDIRECTORIES))
#Rules
#Build
all: smallclean $(BUILDDIRECTORIES) luaresources lupi

smallclean:
	find . -name '*~' -type f -exec rm {} \;

build: clean all

lupi: $(OBJ)
	$(CC) $(LFLAGS) $^ -o $@

$(OBJ): %.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

#Resources
luaresources: cleanresourcues
	scripts/txt2c $(LUAPARAMS)

$(BUILDDIRECTORIES):
	mkdir $@

#Clean rules
cleanresourcues:
	-rm -f $(GENERATED)

	mkdir -p src/c/gen/
	touch src/c/gen/luares.c
	touch include/luares.h

clean : cleanresourcues
	-rm -f $(OBJ)