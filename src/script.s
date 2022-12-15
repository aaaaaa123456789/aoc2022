	section .text
ScriptMode:
	; reads from standard input a script containing lines with a mode and a filename (separated by whitespace) and
	; executes those modes one after another with the files as input; blank lines and lines starting with # are ignored
	endbr64
	push 0
.loop:
	call ReadInputLine
	jc .done
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
	cmp byte[rdi], 0
	jz InvalidInputError
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
	assert O_RDONLY == 0
	xor esi, esi
	; rdi already points to the filename
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
	lea rsi, [rel .errormessage]
	jmp ErrorExit

.invalidmode:
	lea rdi, [rel wTextBuffer]
	lea rsi, [rel .invalidmessage]
	mov ecx, .end_invalidmessage - .invalidmessage
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

.errormessage: db `error: I/O error\n`, 0
.invalidmessage: withend db "warning: invalid mode: "

.done:
	pop rdi
	ret
