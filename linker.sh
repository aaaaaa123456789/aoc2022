#!/bin/bash

# This script acts as the linker for the release build, linking the .o file into the final ELF executable.
# This sets up the sections in the way the loader expects, generates the relocation information it needs, and sets the
# loader to run as the entry point, which will reload the rest of the binary at a random address and unload the fixed
# address copy (effectively applying ASLR on the main program).

# This is NOT a generic script by any means; it makes many assumptions about the section layout that this particular
# program holds: no .data section, a loader section with a loader program that fits in the gap before .text, a
# loaddata section where relocation data will be added, and a .text section with an entry point at its very beginning.

# Normally I would've written this in a language like C (or even assembly itself), but I'm deliberately avoiding all
# use of C for this project. Using a language not suited for the task is part of the fun!

set -e
set -u
set -o pipefail
OBJ="$1"
DST="$2"
LOAD=$(( $3 ))
(( !($3 & 0xfff) ))
ELF="`mktemp`"
TEMP="`mktemp`"
trap -- 'rm -- "$TEMP" "$ELF"' EXIT

declare -A sectnum
declare -A sectsize
declare -A sectoffset
declare -A sectalign
declare -A sectrela
declare -A sectsymtab
declare -A sectsym
declare -A outoffset

function sizeof {
	stat -c '%s' -- "$1"
}

function readobj {
	local length=4
	if (( $# > 1 )); then length=$(( $2 )); fi
	hexdump -s $(( $1 )) -n $length -e "1/$length \"%u\\n\"" "$OBJ"
}

function readobj64 {
	local low=`hexdump -s $(( $1 )) -n 4 -e '1/4 "%d\n"' "$OBJ"`
	local high=`hexdump -s $(( $1 + 4 )) -n 4 -e '1/4 "%d\n"' "$OBJ"`
	(( (low < 0 && high == -1) || (low >= 0 && ! high) ))
	echo $low
}

function readstring {
	local buf='0:'
	local address=$(( $1 ))
	while true; do
		local byte=`readobj $address 1`
		if (( byte == 0 )); then break; fi
		buf="`printf '%s %02x' "$buf" $byte`"
		(( address ++ )) || true
	done
	echo "$buf" | xxd -r -
}

function writevalue {
	local length=4
	if (( $# > 3 )); then length=$(( $4 )); fi
	local value=$(( $3 ))
	local output=`printf '%x:' $(( $2 ))`
	for (( byte = 0; byte < length; byte ++ )); do
		output=`printf '%s %02x' "$output" $(( value & 0xff ))`
		(( value >>= 8 )) || true
	done
	echo "$output" | xxd -r - "$1"
}

function writeout {
	writevalue "$ELF" "$@"
}

function appendtemp {
	local size=`sizeof "$TEMP"`
	writevalue "$TEMP" $(( size )) "$@"
}

function copybytes {
	xxd -l $(( $5 )) -s $(( $4 )) "$3" | sort | xxd -r -seek $(( ($2) - ($4) )) - "$1"
}

function copysection {
	copybytes "$ELF" ${outoffset[$1]} "$OBJ" ${sectoffset[$1]} ${sectsize[$1]}
}

function relocate {
	# $1: section, $2: relocation
	local type=`readobj $(( $2 + 8 ))`
	local symbol=`readobj $(( $2 + 12 ))`
	local offset=`readobj64 $(( $2 ))`
	local addend=`readobj64 $(( $2 + 16 ))`
	(( type < 3 ))
	if (( ! type )); then return 0; fi
	local section=unknown
	local inloader=false
	if [ "$1" == "loader" ]; then inloader=true; fi
	if [ "$1" == "loaddata" ]; then inloader=true; fi
	for name in .text .rodata .bss; do
		if (( symbol == sectsym[$name] )); then section="$name"; fi
	done
	if $inloader; then
		# only the loader sections can have references to loader sections, and only relative
		(( type == 2 ))
		for name in loader loaddata; do
			if (( symbol == sectsym[$name] )); then section="$name"; fi
		done
	fi
	[ "$section" != "unknown" ]
	local address=$(( outoffset[$section] + addend ))
	local file="$ELF"
	local target=$(( offset + outoffset[$1] ))
	if [ "$1" == "loaddata" ]; then
		file="$TEMP"
	else
		offset=$(( target ))
	fi
	if (( type == 1 )); then
		# 64-bit absolute relocation
		writevalue "$file" $(( offset )) $(( address + LOAD ))
		writevalue "$file" $(( offset + 4 )) 0
		appendtemp $(( target + LOAD ))
	else
		# 32-bit RIP-relative relocation
		writevalue "$file" $(( offset )) $(( address - target ))
	fi
}

for section in .text .rodata .bss loader loaddata; do sectnum[$section]=-1; done

# check the ELF header, file type and version
(( `readobj 0` == 0x464c457f ))
(( `readobj 4` == 0x00010102 ))
(( `readobj 16` == 0x003e0001 ))
(( `readobj 20` == 1 ))

# read section header values and validate them
(( `readobj 52 2` >= 64 ))
sectheaders=$(( `readobj 40` ))
sectsize=$(( `readobj 58 2` ))
sectcount=$(( `readobj 60 2` ))
(( sectsize >= 56 ))
(( sectheaders + sectsize * sectcount <= `sizeof "$OBJ"` ))
shstrsect=$(( `readobj 62 2` ))
(( shstrsect && shstrsect < sectcount ))
shstrtab=$(( `readobj $(( sectheaders + sectsize * shstrsect + 24 ))` ))

# read and validate section data
totalread=0
for (( section = 1; section < sectcount; section ++ )); do
	sectoffset=$(( sectheaders + section * sectsize ))
	p=$(( shstrtab + `readobj $sectoffset` ))
	name="`readstring $p`"
	skip=true
	for tname in .text .rodata .bss loader loaddata; do
		if [ "$name" = "$tname" ]; then
			skip=false
			break
		fi
	done
	if $skip; then continue; fi
	(( sectnum[$name] == -1 ))
	sectnum[$name]=$(( section ))
	p=$(( `readobj $(( sectoffset + 4 ))` ))
	if [ "$name" == ".bss" ]; then
		(( p == 8 ))
	else
		(( p == 1 ))
	fi
	sectsize[$name]=$(( `readobj $(( sectoffset + 32 ))` ))
	sectoffset[$name]=$(( `readobj $(( sectoffset + 24 ))` ))
	sectalign[$name]=$(( `readobj $(( sectoffset + 48 ))` ))
	if (( ! sectalign[$name] )); then
		sectalign[$name]=1
	fi
	(( sectalign[$name] <= 0x1000 && !(sectalign[$name] & (sectalign[$name] - 1)) ))
	sectrela[$name]=0
	(( totalread ++ )) || true
done
(( totalread == 5 ))
(( sectsize[loader] <= 0xfc0 && !(sectsize[loader] % sectalign[loader]) ))
(( sectalign[loaddata] >= 4 ))
(( !(sectsize[loaddata] & 3) ))

# locate relocation sections that apply to relevant sections
for (( section = 1; section < sectcount; section ++ )); do
	sectoffset=$(( sectheaders + section * sectsize ))
	p=$(( `readobj $(( sectoffset + 4 ))` ))
	if (( p != 4 && p != 9 )); then continue; fi
	valid=$(( p != 9 ))
	p=$(( `readobj $(( sectoffset + 44 ))` ))
	for name in .text .rodata .bss loader loaddata; do
		if (( p != sectnum[$name] )); then continue; fi
		(( valid ))
		sectrela[$name]=$(( section ))
		sectsymtab[$name]=$(( `readobj $(( sectoffset + 40 ))` ))
	done
done

# begin by writing the ELF header and program headers to the output file
truncate -s 0 -- "$ELF"
xxd -r - "$ELF" <<-END
	00: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
	10: 02 00 3e 00 01 00 00 00 00 00 00 00 00 00 00 00
	20: 40 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	30: 00 00 00 00 40 00 38 00 02 00 40 00 07 00 06 00
	40: 01 00 00 00 05 00 00 00 00 00 00 00 00 00 00 00
	50: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	60: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	70: 00 10 00 00 00 00 00 00 01 00 00 00 06 00 00 00
	80: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	90: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	a0: 00 00 00 00 00 00 00 00 00 10 00 00 00 00 00 00
END
writeout $(( 0x50 )) $(( LOAD ))
writeout $(( 0x58 )) $(( LOAD ))
writeout $(( 0xa0 )) $(( (sectsize[.bss] + 0xfff) / 0x1000 * 0x1000 ))
# pending fields: 0x18: entry point, 0x28: section headers, 0x60, 0x68: filesize, 0x88, 0x90: load address of BSS

# define the initial gap and place the sections with guaranteed placement locations
outoffset[.text]=$(( 0x1000 ))
outoffset[loader]=$(( 0x1000 - sectsize[loader] ))
outoffset[.rodata]=$(( (outoffset[.text] + sectsize[.text] + sectalign[.rodata] - 1) / sectalign[.rodata] * sectalign[.rodata] ))
filesize=$(( (outoffset[.rodata] + sectsize[.rodata] + sectalign[.rodata] - 1) / sectalign[.rodata] * sectalign[.rodata] ))
outoffset[.bss]=$(( (filesize + 0xfff) / 0x1000 * 0x1000 ))
copysection .text
copysection .rodata
copysection loader
gapstart=$(( 0xb0 ))
gapend=$(( outoffset[loader] ))

# truncate the temp file and copy the loaddata section to it; absolute relocations will be appended to it
length=$(( (sectsize[loaddata] + sectalign[loaddata] - 1) / sectalign[loaddata] * sectalign[loaddata] ))
if (( sectsize[loaddata] )); then copybytes "$TEMP" 0 "$OBJ" ${sectoffset[loaddata]} ${sectsize[loaddata]}; fi
truncate -s $length -- "$TEMP"

# count the number of absolute relocations (across all sections), to determine the final size of loaddata
relocs=0
for section in .text .rodata .bss loader loaddata; do
	if (( ! sectrela[$section] )); then continue; fi
	relheader=$(( sectheaders + sectrela[$section] * sectsize ))
	entrysize=$(( `readobj $(( relheader + 56 ))` ))
	(( entrysize ))
	entrycount=$(( `readobj $(( relheader + 32 ))` / entrysize ))
	offset=$(( `readobj $(( relheader + 24 ))` ))
	for (( entry = 0; entry < entrycount; entry ++ )); do
		if (( `readobj $(( offset + entry * entrysize + 8 ))` == 1 )); then (( relocs ++ )) || true; fi
	done
done
relocsize=$(( ((relocs + 1) * 4 + sectalign[loaddata] - 1) / sectalign[loaddata] * sectalign[loaddata] ))
loaddatasize=$(( length + relocsize ))

# determine the final loading address of loaddata
outoffset[loaddata]=$(( (gapend - loaddatasize) & -sectalign[loaddata] ))
if (( outoffset[loaddata] < gapstart )); then
	outoffset[loaddata]=$(( (filesize + sectalign[loaddata] - 1) / sectalign[loaddata] * sectalign[loaddata] ))
	filesize=$(( outoffset[loaddata] + loaddatasize ))
else
	gapend=$(( outoffset[loaddata] ))
fi

# perform all relocations
for section in .text .rodata .bss loader loaddata; do
	if (( ! sectrela[$section] )); then continue; fi
	# locate references to sections in the symbol table
	for name in .text .rodata .bss loader loaddata; do sectsym[$name]=-1; done
	(( sectsymtab[$section] ))
	tabheader=$(( sectheaders + sectsymtab[$section] * sectsize ))
	entrysize=$(( `readobj $(( tabheader + 56 ))` ))
	(( entrysize ))
	entrycount=$(( `readobj $(( tabheader + 32 ))` / entrysize ))
	offset=$(( `readobj $(( tabheader + 24 ))` ))
	for (( entry = 0; entry < entrycount; entry ++ )); do
		pos=$(( offset + entry * entrysize ))
		if (( (`readobj $(( pos + 4 )) 1` & 15) != 3 )); then continue; fi
		value=$(( `readobj $(( pos + 6 )) 2` ))
		for name in .text .rodata .bss loader loaddata; do
			if (( value == sectnum[$name] )); then
				(( sectsym[$name] == -1 ))
				sectsym[$name]=$(( entry ))
			fi
		done
	done
	# apply relocations to section
	tabheader=$(( sectheaders + sectrela[$section] * sectsize ))
	entrysize=$(( `readobj $(( tabheader + 56 ))` ))
	(( entrysize ))
	entrycount=$(( `readobj $(( tabheader + 32 ))` / entrysize ))
	offset=$(( `readobj $(( tabheader + 24 ))` ))
	for (( entry = 0; entry < entrycount; entry ++ )); do
		relocate "$section" $(( offset + entry * entrysize ))
	done
done

# finalize the loaddata section and copy it to the output file
appendtemp 0
copybytes "$ELF" ${outoffset[loaddata]} "$TEMP" 0 $loaddatasize
sectsize[loaddata]=$(( loaddatasize ))

# define the final location of the section headers and their string table and complete the ELF+program headers
writeout $(( 0x18 )) $(( LOAD + outoffset[loader] ))
writeout $(( 0x60 )) $(( filesize ))
writeout $(( 0x68 )) $(( filesize ))
writeout $(( 0x88 )) $(( LOAD + outoffset[.bss] ))
writeout $(( 0x90 )) $(( LOAD + outoffset[.bss] ))
outsectheaders=$(( gapstart ))
if (( gapstart + 0x1c0 > gapend )); then
	outsectheaders=$(( filesize ))
	(( filesize += 0x1c0 )) || true
else
	(( gapstart += 0x1c0 )) || true
fi
writeout $(( 0x28 )) $(( outsectheaders ))
shstrtab=$(( gapstart ))
if (( gapstart + 0x30 > gapend )); then
	shstrtab=$(( filesize ))
	(( filesize += 0x30 )) || true
else
	(( gapstart += 0x30 )) || true
fi

# write the section headers and their string table
xxd -r -seek $(( shstrtab )) - "$ELF" <<-END
	00: 00 2e 74 65 78 74 00 2e 72 6f 64 61 74 61 00 2e
	10: 62 73 73 00 6c 6f 61 64 65 72 00 6c 6f 61 64 64
	20: 61 74 61 00 2e 73 68 73 74 72 74 61 62 00 00 00
END
# 0x01: .text, 0x07: .rodata, 0x0f: .bss, 0x14: loader, 0x1b: loaddata, 0x24: .shstrtab
xxd -r -seek $(( outsectheaders )) - "$ELF" <<-END
	000: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	020: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	030: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	040: 01 00 00 00 01 00 00 00 86 00 00 00 00 00 00 00
	050: 00 00 00 00 00 00 00 00 00 10 00 00 00 00 00 00
	060: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	070: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	080: 07 00 00 00 01 00 00 00 82 00 00 00 00 00 00 00
	090: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	0a0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	0b0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	0c0: 0f 00 00 00 08 00 00 00 83 00 00 00 00 00 00 00
	0d0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	0e0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	0f0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	100: 14 00 00 00 01 00 00 00 86 00 00 00 00 00 00 00
	110: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	120: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	130: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	140: 1b 00 00 00 01 00 00 00 82 00 00 00 00 00 00 00
	150: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	160: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	170: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	180: 24 00 00 00 03 00 00 00 20 00 00 00 00 00 00 00
	190: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	1a0: 2e 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	1b0: 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
END
writeout $(( outsectheaders + 0x50 )) $(( LOAD + outoffset[.text] ))
writeout $(( outsectheaders + 0x60 )) $(( sectsize[.text] ))
writeout $(( outsectheaders + 0x70 )) $(( sectalign[.text] ))
writeout $(( outsectheaders + 0x90 )) $(( LOAD + outoffset[.rodata] ))
writeout $(( outsectheaders + 0x98 )) $(( outoffset[.rodata] ))
writeout $(( outsectheaders + 0xa0 )) $(( sectsize[.rodata] ))
writeout $(( outsectheaders + 0xb0 )) $(( sectalign[.rodata] ))
writeout $(( outsectheaders + 0xd0 )) $(( LOAD + outoffset[.bss] ))
writeout $(( outsectheaders + 0xd8 )) $(( outoffset[.bss] ))
writeout $(( outsectheaders + 0xe0 )) $(( sectsize[.bss] ))
writeout $(( outsectheaders + 0xf0 )) $(( sectalign[.bss] ))
writeout $(( outsectheaders + 0x110 )) $(( LOAD + outoffset[loader] ))
writeout $(( outsectheaders + 0x118 )) $(( outoffset[loader] ))
writeout $(( outsectheaders + 0x120 )) $(( sectsize[loader] ))
writeout $(( outsectheaders + 0x130 )) $(( sectalign[loader] ))
writeout $(( outsectheaders + 0x150 )) $(( LOAD + outoffset[loaddata] ))
writeout $(( outsectheaders + 0x158 )) $(( outoffset[loaddata] ))
writeout $(( outsectheaders + 0x160 )) $(( sectsize[loaddata] ))
writeout $(( outsectheaders + 0x170 )) $(( sectalign[loaddata] ))
writeout $(( outsectheaders + 0x198 )) $(( shstrtab ))

# ...and it's all done! Copy the temporary $ELF file to the output
cp -- "$ELF" "$DST"
chmod +x -- "$DST"
