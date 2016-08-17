# LuPI2 Makefile

# Default compiler settings.
PREFIX?=x86_64-linux-musl

CC = $(PREFIX)-gcc
CFLAGS?=-O2 -std=c99 -fdata-sections -ffunction-sections -pthread
LDFLAGS+= -O2 -Wl,--gc-sections -static -Ldependencies/lib-$(PREFIX) -pthread

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

####

winexe: $(BUILD)$(OUTNAME)
	cp $(BUILD)$(OUTNAME) $(BUILD)$(OUTNAME).exe


win: LIBS+= -lws2_32 -lgdi32
win: all winexe

win-build: LIBS+= -lws2_32 -lgdi32
win-build: build winexe

win-debug: LIBS+= -lws2_32 -lgdi32
win-debug: debug winexe

####

dependencies/v86:
	cd dependencies; git clone https://github.com/magik6k/v86.git

dependencies/v86/build/libv86.js: dependencies/v86
	cd dependencies/v86 && wget -P closure-compiler http://dl.google.com/closure-compiler/compiler-latest.zip
	cd dependencies/v86 && unzip -d closure-compiler closure-compiler/compiler-latest.zip compiler.jar
	cd dependencies/v86 && make build/libv86.js

$(BUILD)web: dependencies/v86/build/libv86.js
	rm -rf bin/web; mkdir -p bin/web

web: iso bin/web


####
ISOKERNEL=linux-4.5.2

dependencies/$(ISOKERNEL).tar.xz:
	cd dependencies && wget https://cdn.kernel.org/pub/linux/kernel/v4.x/$(ISOKERNEL).tar.xz

dependencies/$(ISOKERNEL)/arch/x86/boot/bzImage: $(BUILD)lupi.cpio dependencies/$(ISOKERNEL).tar.xz
	rm -rf dependencies/$(ISOKERNEL)/
	cd dependencies && tar xf $(ISOKERNEL).tar.xz
	cp src/iso/linux.config dependencies/$(ISOKERNEL)/.config
	cd dependencies/$(ISOKERNEL)/ && make -j8

$(BUILD)lupi.cpio: $(BUILDDIRECTORIES) $(BUILD)$(OUTNAME) build
	rm -rf $(BUILD)iso.init; mkdir -p $(BUILD)iso.init
	mkdir -p bin/iso.init/sbin bin/iso.init/proc bin/iso.init/sys bin/iso.init/dev bin/iso.init/tmp
	cp bin/lupi bin/iso.init/sbin/init
	(cd bin/iso.init; find . | fakeroot cpio -o -H newc) > $@

$(BUILD)lupi.iso:  dependencies/$(ISOKERNEL)/arch/x86/boot/bzImage
	rm -rf bin/iso.dir; mkdir -p bin/iso.dir bin/iso.dir/boot
	cp $(BUILD)lupi.cpio bin/iso.dir/boot/lupi.img
	cp dependencies/$(ISOKERNEL)/arch/x86/boot/bzImage bin/iso.dir/boot/vmlinuz
	cp src/iso/isolinux.cfg bin/iso.dir/isolinux.cfg
	mkdir -p bin/iso.dir/syslinux bin/iso.dir/sbin
	cp bin/lupi bin/iso.dir/sbin/init
	cp /usr/lib/syslinux/bios/{isolinux.bin,ldlinux.c32,isohdpfx.bin} bin/iso.dir/syslinux/
	mkisofs -o bin/lupi.iso -b syslinux/isolinux.bin -c syslinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table bin/iso.dir

iso: PREFIX?=i486-linux-musl
iso: build $(BUILD)lupi.iso

####

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

.PHONY: web iso debug clean cleanresourcues resources build smallclean all
