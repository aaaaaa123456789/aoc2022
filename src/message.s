	section .rodata align=16

ErrorMessages:
	.read: message "error: read error"
	.open: message "error: failed to open file"
	.allocation: message "error: failed to allocate memory"
	.invalidinput: message "error: invalid input"
	.highcount: message "error: read count too high"
	.overflow: message "error: overflow"
	.invalidbuffer: message "error: invalid buffer"
	.invalidarg: message "error: invalid argument"

	; errors from individual modes
	.notfound: message "error: entry not found"
	.duplicate: message "error: duplicate entry"
	.invalidtarget: message "error: invalid target"
	.unreachable: message "error: unreachable"
	.fillup: message "error: layout fills up"
	.nolocation: message "error: no available location"
	.manynonzero: message "error: too many non-zero entries"

WarningMessages:
	.invalidmode: withend db "warning: invalid mode: "
	.buffernull: message "warning: buffer is null"
	.bufferleak: message "warning: buffer would be leaked"

UsageMessages:
	.defaultprogname: db "<program name>", 0
	.usage1: withend db "usage: "
	.usage2: withend db ` <mode> <args...>\n\nAvailable modes`
	.script: withend db ` script [<path prefix>]\n`, 0

Newline: equ UsageMessages.end_script - 2

	align 16, db 0
