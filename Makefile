# TARGET=arm-none-eabi

#CC=$(TARGET)-gcc
CC=gcc

CFLAGS=-O2 -g -std=c99 -Isrc/lib/lua -Iinclude

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

#Build
all: smallclean $(BUILDDIRECTORIES) luaresources $(BUILD)lupi

build: clean all

$(BUILD)lupi: $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@ $(LIBS)

$(BUILD)%.c.o: $(SOURCE)%.c
	$(CC) -c $(CFLAGS) -I /usr/include -I src/c -I src/c/lib/lua $< -o $@

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

smallclean:
	find . -name '*~' -type f -exec rm {} \;

# Other

.PHONY: clean cleanresourcues luaresources build smallclean all