# LuPI2 Makefile

# Default compiler settings.
CC?=cc
CFLAGS?=-O2 -std=c99
LDFLAGS+= -static

# Project specific stuff
BUILD = bin/
SOURCE = src/c

CORELUA = src/lua/core
RESOURCES = resources
LIBS=-lm

INCLUDES=-I$(SOURCE) -Isrc/c/lib/lua -Iinclude

GENERATED=include/luares.h src/c/gen/luares.c include/res.h src/c/gen/res.c
LUAPARAMS = $(CORELUA) include/luares.h src/c/gen/luares.c lua_
RESPARAMS = $(RESOURCES) include/res.h src/c/gen/res.c res_

SRCDIRECTORIES = $(shell find $(SOURCE) -type d)
BUILDDIRECTORIES = $(patsubst $(SOURCE)/%, $(BUILD)%, $(SRCDIRECTORIES))

CFILES = $(shell find $(SOURCE) -type f -name '*.c')
OBJECTS :=	$(patsubst $(SOURCE)/%.c, $(BUILD)%.c.o, $(CFILES))

# Targets

# Pseudo Targets
debug: CFLAGS+= -g

$(BUILDDIRECTORIES):
	mkdir -p $@

build: smallclean $(BUILDDIRECTORIES) resources $(BUILD)lupi

all: clean build

$(BUILD)lupi: $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@ $(LIBS)

$(BUILD)%.c.o: $(SOURCE)/%.c
	$(CC) -c $(CFLAGS) $(INCLUDES) $< -o $@

#Resources
resources: cleanresources
	scripts/txt2c $(LUAPARAMS)
	scripts/txt2c $(RESPARAMS)

# Clean rules
cleanresources:
	-rm -f $(GENERATED)
	mkdir -p $(SOURCE)/gen/
	touch $(SOURCE)/gen/luares.c
	touch include/luares.h

clean: cleanresources
	-rm -rf $(BUILD)

smallclean:
	find . -name '*~' -type f -exec rm {} \;

# Other

.PHONY: clean cleanresourcues resources build smallclean all
