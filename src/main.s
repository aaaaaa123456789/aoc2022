section .text

	global _start:function
_start:
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
	mov edi, 2
	call OutputMessage
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

.message: db `error: invalid input\n`, 0

section .rodata align=16

ModeHandlers:
	; all called with rdi = argument count, rsi = argument array (after skipping), rdx = program name (or null)
	; returning exit status in edi
	dq "1a",       Prob1a
	dq "testcat",  TestCat
	dq 0,          InvalidModeHandler
