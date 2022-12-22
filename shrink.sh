#!/bin/bash

# This little script is just for fun! All it does is repack the ELF binary a little better by moving headers around
# so that they fit into the gap in the first page. It can be safely removed (or replaced with a blank script).
# Normally I would write this in C, but I'm deliberately avoiding all use of C for this project. Bash will have to do.

set -e
set -o pipefail
ELF="$1"

function readvalue {
	hexdump -s "$1" -n 4 -e '1/4 "%u\n"' "$ELF"
}

function writevalue {
	(( val = ($2) ))
	printf '0: %02x %02x %02x %02x\n' $(( val & 0xff )) $(( (val >> 8) & 0xff )) $(( (val >> 16) & 0xff )) $(( (val >> 24) & 0xff )) |
		xxd -r -seek "$1" - "$ELF"
}

function copybytes {
	xxd -l "$3" -s "$2" "$ELF" | sort | xxd -r -seek $(( ($1) - ($2) )) - "$ELF"
}

# check the ELF header and version
(( `readvalue 0` == 0x464c457f ))
(( `readvalue 4` == 0x00010102 ))
(( `readvalue 20` == 1 ))

# read relevant values from the header
(( progheaders = `readvalue 32` ))
(( progsize = `readvalue 54` & 0xffff ))
(( progcount = `readvalue 56` & 0xffff ))
(( sectheaders = `readvalue 40` ))
(( sectsize = `readvalue 58` & 0xffff ))
(( sectcount = `readvalue 60` & 0xffff ))
(( filesize = `stat -c '%s' "$ELF"` ))

# verify that the values read are reasonable
(( filesize >= progheaders + progsize * progcount ))
(( filesize >= sectheaders + sectsize * sectcount ))
(( progsize >= 40 ))
(( sectsize >= 56 ))

# compute the start and end of the first page gap
(( start = `readvalue 52` & 0xffff ))
while (( progheaders == start || sectheaders == start )); do
	if (( progheaders == start )); then (( start += progsize * progcount )); fi
	if (( sectheaders == start )); then (( start += sectsize * sectcount )); fi
done
(( start = start & -4 ))

(( end = filesize ))
for (( header = 0; header < progcount; header ++ )); do
	if (( `readvalue $(( progheaders + header * progsize + 32 ))` )); then
		(( blockstart = `readvalue $(( progheaders + header * progsize + 8 ))` ))
		if (( blockstart < end )); then (( end = blockstart )); fi
	fi
done
(( end = end & -4 ))

# find movable components and move them to the gap if they will fit
shrink=true
while $shrink; do
	shrink=false
	(( size = (progsize * progcount + 3) & -4 ))
	if (( (progheaders + size == filesize) && (size <= end - start) )); then
		writevalue 32 $start
		copybytes $start $progheaders $size
		filesize=$progheaders
		progheaders=$start
		(( start += size ))
		shrink=true
	fi
	(( size = (sectsize * sectcount + 3) & -4 ))
	if (( (sectheaders + size == filesize) && (size <= end - start) )); then
		writevalue 40 $start
		copybytes $start $sectheaders $size
		filesize=$sectheaders
		sectheaders=$start
		(( start += size ))
		shrink=true
	fi
	for (( section = 0; section < sectcount; section ++ )); do
		(( header = sectheaders + section * sectsize ))
		if (( `readvalue $(( header + 4 ))` < 2 )); then continue; fi
		(( size = (`readvalue $(( header + 32 ))` + 3) & -4 ))
		if (( (size == 0) || (`readvalue $(( header + 48 ))` > 4) )); then continue; fi
		position=`readvalue $(( header + 24 ))`
		if (( (position + size == filesize) && (size <= end - start) )); then
			writevalue $(( header + 24 )) $start
			copybytes $start $position $size
			filesize=$position
			(( start += size ))
			shrink=true
		fi
	done
done
truncate -s $filesize -- "$ELF"
