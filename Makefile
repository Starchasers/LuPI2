CC=gcc
CFLAGS=-g -std=gnu99 -Isrc/lib/lua -Iinclude

BUILD = bin/
SOURCE = src/c/

CORELUA = src/lua/core
LIBS=-lm

GENERATED=include/luares.h src/c/gen/luares.c
LUAPARAMS = $(CORELUA) include/luares.h src/c/gen/luares.c lua_
LDFLAGS=-static

SRCDIRECTORIES = $(shell find $(SOURCE) -type d)
BUILDDIRECTORIES = $(patsubst $(SOURCE)%, $(BUILD)%, $(SRCDIRECTORIES))

CFILES = $(shell find $(SOURCE) -type f -name '*.c')
OBJECTS :=	$(patsubst $(SOURCE)%.c, $(BUILD)%.c.o, $(CFILES))

#Rules
#Prepare
$(BUILDDIRECTORIES):
	mkdir -p $@

#Clean

#Build
all: smallclean $(BUILDDIRECTORIES) luaresources $(BUILD)lupi

smallclean:
	find . -name '*~' -type f -exec rm {} \;

build: clean all

$(BUILD)lupi: $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@ $(LIBS)

$(BUILD)%.c.o: $(SOURCE)%.c $(BUILD)
	$(CC) -c $(CFLAGS) -I src/c -I src/c/lib/lua $< -o $@

#Resources
luaresources: cleanresourcues
	scripts/txt2c $(LUAPARAMS)

#Clean rules
cleanresourcues:
	-rm -f $(GENERATED)
	mkdir -p src/c/gen/
	touch src/c/gen/luares.c
	touch include/luares.h

clean: cleanresourcues
	-rm -rf $(BUILD)
