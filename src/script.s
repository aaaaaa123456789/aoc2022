	section .text
ScriptMode:
	; reads from standard input a script containing lines with a mode and a filename (separated by whitespace) and
	; executes those modes one after another with the files as input; blank lines and lines starting with # are ignored
	endbr64
	cmp qword[rel wScriptPathPrefix], 0
	jnz .pathloaded
	cmp rdi, 1
	jc .pathloaded
	jnz .extraargs
	mov rsi, [rsi]
	call StringLength
	jz .pathloaded
	push rsi
	push rdi
	lea rsi, [rdi + 1024]
	xor edi, edi
	call AllocateMemory
	mov [rel wScriptPathPrefix], rdi
	pop rcx
	pop rsi
	rep movsb
	mov al, "/"
	cmp byte[rdi - 1], al
	jz .gotslash
	stosb
.gotslash:
	mov [rel wScriptPathInsertionPoint], rdi
.pathloaded:
	push 0
.loop:
	call ReadInputLine
	jc .done
	cmp rdi, 1024
	ja InvalidInputError
	lea rcx, [rdi + 1]
	mov rdi, rsi
	mov eax, " "
	repz scasb
	dec rdi
	inc rcx
	cmp byte[rdi], 0
	jz .loop
	cmp byte[rdi], "#"
	jz .loop
	mov rsi, rdi
	repnz scasb
	dec rdi
	inc rcx
	mov rdx, rdi
	sub rdx, rsi
	cmp rdx, 8
	ja InvalidInputError
	repz scasb
	dec rdi
	mov rbx, [rsi]
	neg rdx
	lea rcx, [64 + 8 * rdx]
	shl rbx, cl
	shr rbx, cl
	lea rsi, [rel ModeHandlers - 16]
.modeloop:
	add rsi, 16
	cmp qword[rsi], 0
	jz .invalidmode
	cmp rbx, [rsi]
	jnz .modeloop

	mov eax, [rel wInputFD]
	push rax
	push qword[rsi + 8]
.open:
	push rdi
	mov rsi, [wScriptPathInsertionPoint]
	test rsi, rsi
	jz .gotfilename
	cmp byte[rdi], "/"
	jz .gotfilename
	xchg rdi, rsi
.filenameloop:
	movsb
	cmp byte[rdi - 1], 0
	jnz .filenameloop
	mov rdi, [wScriptPathPrefix]
.gotfilename:
	cmp byte[rdi], 0
	jz InvalidInputError
	assert O_RDONLY == 0
	xor esi, esi
	mov eax, open
	syscall
	pop rdi
	cmp rax, -EINTR
	jz .open
	test rax, rax
	jl .inputerror
	mov [rel wInputFD], eax

	xor edi, edi
	mov esi, READ_BUFFER_SIZE + 4
	call MapMemory
	pop rbx
	push rdi
	lea rsi, [rel wInputBuffer]
	mov ecx, READ_BUFFER_SIZE / 8
	rep movsq
	assert wInputEOF == wInputPosition + 2
	mov eax, [rel wInputPosition]
	mov [rdi], eax
	mov dword[rel wInputPosition], READ_BUFFER_SIZE * 0x10001
	xor edi, edi
	lea esi, [rel NullData]
	xor edx, edx
	call rbx

	pop rsi
	mov rbx, rsi
	lea rdi, [rel wInputBuffer]
	mov ecx, READ_BUFFER_SIZE / 8
	rep movsq
	mov eax, [rsi]
	mov [rel wInputPosition], eax
	mov rdi, rbx
	xor esi, esi
	call MapMemory
.close:
	mov edi, [rel wInputFD]
	mov eax, close
	syscall
	cmp rax, -EINTR
	jz .close
	test rax, rax
	pop rax
	mov [rel wInputFD], eax
	jz .loop
.inputerror:
	lea rsi, [rel ErrorMessages.open]
	jmp ErrorExit

.invalidmode:
	lea rdi, [rel wTextBuffer]
	lea rsi, [rel WarningMessages.invalidmode]
	mov ecx, WarningMessages.end_invalidmode - WarningMessages.invalidmode
	rep movsb
	mov [rdi], rbx
	xor eax, eax
	mov [rdi + 8], al
	repnz scasb
	mov word[rdi - 1], `\n`
	lea rsi, [rel wTextBuffer]
	call PrintMessage
	mov dword[rsp], 2
	jmp .loop

.done:
	mov rdi, [rel wScriptPathPrefix]
	test rdi, rdi
	jz .nofree
	xor esi, esi
	call AllocateMemory
.nofree:
	pop rdi
	ret

.extraargs:
	lea rdi, [rel wTextBuffer]
	lea rsi, [rel UsageMessages.usage1]
	mov ecx, UsageMessages.end_usage1 - UsageMessages.usage1
	rep movsb
	lea rsi, [rel UsageMessages.defaultprogname]
	test rdx, rdx
	cmovnz rsi, rdx
.prognameloop:
	movsb
	cmp byte[rdi - 1], 0
	jnz .prognameloop
	dec rdi
	lea rsi, [rel UsageMessages.script]
	mov ecx, UsageMessages.end_script - UsageMessages.script
	rep movsb
	lea rsi, [rel wTextBuffer]
	jmp ErrorExit
