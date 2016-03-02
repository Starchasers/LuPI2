# LuPI2 Makefile

# Default compiler settings.
PREFIX?=x86_64-linux-musl

CC = $(PREFIX)-gcc
CFLAGS?=-O2 -std=c99 -fdata-sections -ffunction-sections
LDFLAGS+= -O2 -Wl,--gc-sections -static -Ldependencies/lib-$(PREFIX)

# Project specific stuff
BUILD = bin/
SOURCE = src/c

CORELUA = src/lua/core
RESOURCES = resources
LIBS=-lm -llua -lssl -lcrypto -levent_core

INCLUDES=-I$(SOURCE) -Iinclude -Idependencies/include -Idependencies/include-$(PREFIX)

GENERATED=include/luares.h src/c/gen/luares.c include/res.h src/c/gen/res.c
LUAPARAMS = $(CORELUA) include/luares.h src/c/gen/luares.c lua_
RESPARAMS = $(RESOURCES) include/res.h src/c/gen/res.c res_

SRCDIRECTORIES = $(shell find $(SOURCE) -type d)
BUILDDIRECTORIES = $(patsubst $(SOURCE)/%, $(BUILD)%, $(SRCDIRECTORIES))

CFILES = $(shell find $(SOURCE) -type f -name '*.c')
OBJECTS :=	$(patsubst $(SOURCE)/%.c, $(BUILD)%.c.o, $(CFILES))

OUTNAME = lupi

# Targets

# Pseudo Targets
debug: CFLAGS+= -g -DLOGGING -DDEBUG
debug: build

winexe: $(BUILD)$(OUTNAME)
	cp $(BUILD)$(OUTNAME) $(BUILD)$(OUTNAME).exe


win: LIBS+= -lws2_32 -lgdi32
win: all winexe

win-build: LIBS+= -lws2_32 -lgdi32
win-build: build winexe

win-debug: LIBS+= -lws2_32 -lgdi32
win-debug: debug winexe

$(BUILDDIRECTORIES):
	mkdir -p $@

build: smallclean $(BUILDDIRECTORIES) resources $(BUILD)$(OUTNAME)

all: clean build

$(BUILD)$(OUTNAME): $(OBJECTS)
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

.PHONY: debug clean cleanresourcues resources build smallclean all
