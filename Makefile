SHELL           := /bin/bash

MUNGE_GRUB_BG   := true

DEFAULT_LANG    :=
NO_1024         :=
NO_SYSLINUX_F1  := true

ADD_TEXT_OPTS   := --position 280,490 --text "press F1 for help"

TOOLS           := Tools
TEMPLATE_FILLER := $(TOOLS)/bootloader-template
BG_MUNGER       := $(TOOLS)/bg-image-text
README          := readme.msg
DISTROS         := antiX MX
COMMON_FILES    := Input/common/isolinux/* fonts/*.fnt po/tr/*.tr
ISO_FILES       := Input/common/iso/*

MKISOFS         := genisoimage

GFXBOOT_BIN     := gfxtheme
CPIO_FILE       := gfx-cpio
CPIO_FILES      := *.tr *.hlp $(GFXBOOT_BIN) *.fnt *.jpg gfxboot.cfg languages *.men *.def

ISOLINUX_CPIO   := isolinux-cpio
SYSLINUX_CPIO   := syslinux-cpio
CPIO_DIRS       := $(ISOLINUX_CPIO) $(SYSLINUX_CPIO)

ADD_TEXT        := bin/add-image-text
TEST_TARGETS    := $(addprefix test-,   $(DISTROS))
XLAT_TARGETS    := $(addprefix xlat-,   $(DISTROS))
OUT_ISO_DIRS    := $(addprefix Output/, $(addsuffix /boot/isolinux, $(DISTROS)))
OUT_SYS_DIRS    := $(addprefix Output/, $(addsuffix /boot/syslinux, $(DISTROS)))
OUT_DIRS        := $(OUT_SYS_DIRS) $(OUT_ISO_DIRS)
IMAGE_GROUPS    := $(addsuffix -images, $(DISTROS))
HELP_DIRS       := $(addprefix Help/,   $(DISTROS))
HELP_FILES      := $(addsuffix /en.hlp, $(HELP_DIRS))

DISTROS_OLD     := $(addsuffix -old, $(DISTROS))

THEME_FILE      := src/main.bin
SRC_FILES       := $(wildcard src/*.inc) src/main.bc

SUB_DIRS        := Help src po

TEST_DIR      	:= iso-dir
TEST_ISOLINUX   := $(TEST_DIR)/boot/isolinux

ISO_FILE     	:= test-gfxboot.iso
ISO_SYMLINK  	:= /data/ISO/test-antiX.iso

SAVE_STATE_SED  := "$$ anostore         \`nostore\nsavestate       \`savestate\nnosavestate     \`nosavestate"
SAVE_STATE_SED2 := "/bootchart/ inostore         \`nostore\nsavestate       \`savestate\nnosavestate     \`nosavestate"

-include Makefile.local

.PHONY: all clean distclean antiX MX $(ANTIX_DIR) $(IMAGE_GROUPS)

help:
	@echo "Targets:"
	@echo ""
	@echo "    all          : both MX and antiX"
	@echo "    MX           : create gfxboot for MX distro"
	@echo "    antiX        : create gfxboot for antiX distro"
	@echo ""
	@echo "    MX-old       : create old version of gfxboot for MX distro"
	@echo "    antiX-old    : create old version gfxboot for antiX distro"
	@echo ""
	@echo "    clean        : delete output files but not intermediate files"
	@echo "    disclean     : delete all created files"
	@echo "    help         : show this help"
	@echo ""
	@echo "    test-antiX   : create iso file to test antiX bootloader"
	@echo "    test-MX      : create iso file to test MX bootloader"
	@echo "    iso-only     : rebuild the iso file"
	@echo ""
	@echo "    antiX-images : Create bg images with text in Input/antiX"
	@echo "    MX-images    : Create bg images with text in Input/MX"
	@echo ""
	@echo "Create a Makefile.local file to modify the variables above"
	@echo ""
	@echo ""


all: $(DISTROS)

$(DISTROS): % : Output/%/boot/isolinux  Output/%/boot/syslinux  Help/%/en.hlp  $(THEME_FILE)
	cp -a $(ISO_FILES) Input/$@/iso/* Output/$@/
	cp -a $(COMMON_FILES) Input/$@/isolinux/* $(word 3,$^) $</
	cp $(THEME_FILE) $</$(GFXBOOT_BIN)
ifdef DEFAULT_LANG
	@echo $(DEFAULT_LANG) > $</lang.def
endif
ifdef NO_1024
	rm -f $</back1024.jpg
endif

	sed -i -r 's/^(\s*UI\s+gfxboot\s+)[^ ]+(\s)/\1$(CPIO_FILE)\2/' $</isolinux.cfg
	rm -rf $(CPIO_DIRS)
	mkdir -p $(CPIO_DIRS)
	# This prevents errors if a * glob has no matches  (sigh)
	for f in $(addprefix $</, $(CPIO_FILES)); do ! test -e $$f || mv $$f $(ISOLINUX_CPIO)/; done
	@# cp $</gfxboot.cfg $(ISOLINUX_CPIO)/
	(cd $(ISOLINUX_CPIO) && find . -depth | cpio -o) > $</$(CPIO_FILE)
	cp -r $(ISOLINUX_CPIO)/* $(SYSLINUX_CPIO)
	rm -rf $(word 2,$^)
	cp -a $< $(word 2,$^)
	mv $(word 2,$^)/isolinux.bin $(word 2,$^)/syslinux.bin
	mv $(word 2,$^)/isolinux.cfg $(word 2,$^)/syslinux.cfg
	sed -i 's/APPEND hd0/APPEND hd1/' $(word 2,$^)/syslinux.cfg

	# I couldn't get ifeq ($@,antiX) to work
	# Only use smaller normal font in antiX LiveUSB. All others use larger normal font
	! echo $@ | grep -q antiX  || \
	sed -r -i "0,/^font\.normal=/ s/^(font\.normal)=.*/\1=16x16.fnt/" $(SYSLINUX_CPIO)/gfxboot.cfg

	if   grep -q "^key\.F7=" $(SYSLINUX_CPIO)/gfxboot.cfg; then \
		sed -r -i  "/^key\.F7/akey.F8=save" $(SYSLINUX_CPIO)/gfxboot.cfg; \
	elif grep -q "^key\.F6=" $(SYSLINUX_CPIO)/gfxboot.cfg; then \
		sed -r -i  "/^key\.F6/akey.F7=save" $(SYSLINUX_CPIO)/gfxboot.cfg; \
	else \
	    echo "key.F8=save" >> $(SYSLINUX_CPIO)/gfxboot.cfg; \
	fi \

ifdef MUNGE_GRUB_BG
	$(BG_MUNGER) --$(@) Input/$@/iso/boot/grub/theme/bg-1024.png Output/$@/boot/grub/theme/bg-1024.png 
	$(BG_MUNGER) --$(@) Input/$@/iso/boot/grub/theme/bg-800.png  Output/$@/boot/grub/theme/bg-800.png 
endif

ifdef NO_SYSLINUX_F1
	sed -i "/^key\.F1=/d" $(SYSLINUX_CPIO)/gfxboot.cfg
endif
	if grep -q bootchart $(SYSLINUX_CPIO)/options.men; then \
		sed -i $(SAVE_STATE_SED2) $(SYSLINUX_CPIO)/options.men; \
	else \
		sed -i $(SAVE_STATE_SED) $(SYSLINUX_CPIO)/options.men; \
	fi

	(cd $(SYSLINUX_CPIO) && find . -depth | cpio -o) > $(word 2,$^)/$(CPIO_FILE)

$(DISTROS_OLD): %-old : Output/%/isolinux Output/%/syslinux Help/%/en.hlp $(THEME_FILE)
	cp -a $(COMMON_FILES) Input/$(subst -old,,$@)/* $(word 3,$^) $</
	cp $(THEME_FILE) $</$(GFXBOOT_BIN)
ifdef DEFAULT_LANG
	@echo $(DEFAULT_LANG) > $</lang.def
endif
ifdef NO_1024
	rm -f $</back1024.jpg
endif
	sed -i -r 's/^(\s*UI\s+gfxboot\s+)[^ ]+(\s)/\1$(GFXBOOT_BIN)\2/' $</isolinux.cfg
	@#bin/make-menu $</isolinux.cfg >> $</isolinux.msg
	rm -rf $(word 2,$^)
	cp -a $< $(word 2,$^)
	mv $(word 2,$^)/isolinux.bin $(word 2,$^)/syslinux.bin
	mv $(word 2,$^)/isolinux.cfg $(word 2,$^)/syslinux.cfg
	echo 1 > $(word 2,$^)/gfxsave.on
	sed -i 's/APPEND hd0/APPEND hd1/' $(word 2,$^)/syslinux.cfg

$(HELP_FILES): %/en.hlp : % %/en.html
	make --directory Help $(<F)

$(THEME_FILE): $(SRC_FILES)
	make --directory $(@D)

$(OUT_DIRS):
	mkdir -p $@

clean:
	rm -rf Output $(ISO_FILE) $(TEST_DIR) $(CPIO_DIRS)

distclean: clean
	@for i in $(SUB_DIRS) ; do [ ! -f $$i/Makefile ] || make -C $$i distclean || break ; done

$(TEST_TARGETS): test-% : % %-data
	rm -rf $(TEST_DIR)
	mkdir -p $(TEST_DIR)
	cp -a Output/$</* $(TEST_DIR)

	$(TEMPLATE_FILLER) -i --data=$(word 2,$^) $(TEST_DIR)

	echo 1 > $(ISOLINUX_CPIO)/REBOOT
	@#echo "desktop=rox-fluxbox" > $(ISOLINUX_CPIO)/desktop.def
	@#sed -i  "/F8=gfx_save/d" $(ISOLINUX_CPIO)/gfxboot.cfg
	$(TOOLS)/make-isolinux-menu < $(TEST_ISOLINUX)/isolinux.cfg >> $(TEST_ISOLINUX)/$(README)
	make iso-only

$(XLAT_TARGETS): xlat-% : %-data
	$(TEMPLATE_FILLER) -i --data=$< Output/$(subst -data,,$<)

$(ISO_FILE):
	[ -L $(ISO_SYMLINK) -o ! -e $(ISO_SYMLINK) ] && ln -sf $$(readlink -f $(ISO_FILE)) $(ISO_SYMLINK) || true
	$(MKISOFS) -l -V gfxboot-test -R -J -pad -no-emul-boot -boot-load-size 4 \
    	-boot-info-table -gid 0 -uid 0 -b boot/isolinux/isolinux.bin \
        -c boot/isolinux/isolinux.cat -o $@ iso-dir

iso-only:
	(cd $(ISOLINUX_CPIO) && find . -depth | cpio -o) > $(TEST_ISOLINUX)/$(CPIO_FILE)
	make -B $(ISO_FILE)

# FIXME: a bit backward
$(IMAGE_GROUPS): %-images : images/%-back.jpg Input/%
	$(ADD_TEXT) $(ADD_TEXT_OPTS) $< $(word 2,$^)/back800.jpg
	$(ADD_TEXT) $(ADD_TEXT_OPTS) $< $(word 2,$^)/back640.jpg
ifndef NO_1024
	$(ADD_TEXT) $(ADD_TEXT_OPTS) $< $(word 2,$^)/back1024.jpg
endif

