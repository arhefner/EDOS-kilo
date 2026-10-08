# EDOS-kilo - the kilo full screen editor for ELF-DOS.
#
# Needs Asm/02 and Link/02. "make" assembles everything in src/ and
# links the editor as ./kilo, ready to copy onto an ELF-DOS volume.

ASM     ?= /opt/elfc/asm02
LINK    ?= /opt/elfc/link02

ASMFLAGS ?= -L -C -I../elfdos-sdk
LFLAGS   ?= -b -be

# kilo.prg must be first: it holds the program header at PROG_BASE.
# kilo_data.prg must be last: the text buffer starts where the program
# ends and grows upward from there.
MODULES = kilo kilo_util kilo_cfg kilo_line kilo_str kilo_buf kilo_keys \
	kilo_text kilo_move kilo_edit kilo_input kilo_kbio kilo_prmpt \
	kilo_file kilo_spill kilo_dos kilo_data

PRGS = $(patsubst %,src/%.prg,$(MODULES))

HEADERS = src/include/kilo_def.inc src/kilo_dbg.inc \
	elfdos-sdk/include/opcodes.def elfdos-sdk/include/bios.inc \
	elfdos-sdk/include/kernel_api.inc

.PHONY: all clean

all: kilo

kilo: $(PRGS)
	$(LINK) $(LFLAGS) -o kilo $(PRGS)
	rm -f kilo.lkb

src/%.prg: src/%.asm $(HEADERS)
	cd src && $(ASM) $(ASMFLAGS) $*.asm

clean:
	rm -f kilo kilo.lkb
	rm -f src/*.prg src/*.lst src/*.build
