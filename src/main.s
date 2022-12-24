	section .text

	global _start:function
_start:
	; check that stdin, stdout and stderr are open - die immediately (exit status 122) if they aren't
	xor edi, edi
	mov esi, F_GETFD
	mov eax, fcntl
	syscall
	cmp eax, -EBADF
	jz .badfd
	mov edi, 1
	mov esi, F_GETFD
	mov eax, fcntl
	syscall
	cmp eax, -EBADF
	jz .badfd
	mov edi, 2
	mov esi, F_GETFD
	mov eax, fcntl
	syscall
	cmp eax, -EBADF
	jnz .goodfd
.badfd:
	mov edi, 122
	mov eax, exit_group
	syscall
.goodfd:

	; initialize non-zero variables
	mov dword[rel wOutputFD], 1
	assert wInputEOF == wInputPosition + 2
	mov dword[rel wInputPosition], READ_BUFFER_SIZE * 0x10001

	; handle command-line arguments
	pop rdi
	sub rdi, 2
	pop rdx
	jc InvalidModeHandler
	pop rsi
	; this is a C string, so read byte by byte, because reading 8 bytes at once *can* segfault
	xor ebx, ebx
	xor ebp, ebp
.readloop:
	lodsb
	test al, al
	jz .gotmode
	mov ecx, ebp
	movzx eax, al
	shl rax, cl
	or rbx, rax
	add ebp, 8
	cmp ebp, 64
	jc .readloop
	xor eax, eax
.gotmode:
	lea rcx, [rel ModeHandlers - 16]
.modeloop:
	add rcx, 16
	mov rax, [rcx]
	cmp rax, rbx
	jz .foundmode
	test rax, rax
	jnz .modeloop
.foundmode:
	mov rsi, rsp
	; align the stack
	sub rsp, 8
	test rsp, 8
	cmovz rsp, rsi
	call [rcx + 8]
	mov eax, exit_group
	syscall

InvalidModeHandler:
	endbr64
	lea rdi, [rel wTextBuffer]
	lea rsi, [rel UsageMessages.defaultprogname]
	test rdx, rdx
	cmovz rdx, rsi
	lea rsi, [rel UsageMessages.usage1]
	mov ecx, UsageMessages.end_usage1 - UsageMessages.usage1
	rep movsb
	mov rsi, rdx
.prognameloop:
	movsb
	cmp byte[rdi - 1], 0
	jnz .prognameloop
	dec rdi
	lea rsi, [rel UsageMessages.usage2]
	mov ecx, UsageMessages.end_usage2 - UsageMessages.usage2
	rep movsb
	mov eax, ": "
	lea rdx, [rel ModeHandlers]
	mov rbx, [rdx]
.modeloop:
	stosw
	mov [rdi], rbx
	xor eax, eax
	mov ecx, 9
	repnz scasb
	dec rdi
	add rdx, 16
	mov rbx, [rdx]
	mov eax, ", "
	test rbx, rbx
	jnz .modeloop
	mov eax, `\n`
	stosw
	lea rsi, [rel wTextBuffer]
ErrorExit:
	; in: rsi = error message
	mov dword[rel wOutputFD], 2
	call PrintMessage
	mov edi, 1
	mov eax, exit_group
	syscall

UsageMessages:
	.defaultprogname: db "<program name>", 0
	.usage1: withend db "usage: "
	.usage2: withend db ` <mode> <args...>\n\nAvailable modes`

InvalidInputError:
	lea rsi, [rel .message]
	jmp ErrorExit

.message: db "error: invalid input" ; followed by Newline

Newline: db `\n`, 0
