section .bss align=16

wInputBuffer: resb READ_BUFFER_SIZE
wTextBuffer: resb 0x800

section .data align=16

wInputPosition: dw READ_BUFFER_SIZE
wInputEOF: dw READ_BUFFER_SIZE

	align 16, db 0

section .text

ReadInputLine:
	; input: none
	; output: rsi = pointer to line (null terminated); edi = line length; carry flag = EOF (rsi and rdi invalid)
	; assumes lines are shorter than READ_BUFFER_SIZE and will split longer lines
	movzx ecx, word[rel wInputEOF]
	movzx eax, word[rel wInputPosition]
	sub ecx, eax
	jbe .doread
.readline:
	lea rdi, [rel wInputBuffer]
	add rdi, rax
	mov rsi, rdi
	mov al, `\n`
	repnz scasb
	jnz .doread
.gotline:
	dec rdi
	mov byte[rdi], 0
	sub rdi, rsi
	movzx eax, word[rel wInputPosition]
	lea rax, [rax + rdi + 1]
	mov [rel wInputPosition], ax
	ret

.doread:
	movzx ecx, word[rel wInputEOF]
	cmp ecx, READ_BUFFER_SIZE
	jb .atEOF
	movzx edx, word[rel wInputPosition]
	sub cx, dx
	mov word[rel wInputPosition], 0
	lea rdi, [rel wInputBuffer]
	jz .nocopy
	rep movsb
.nocopy:
	mov rsi, rdi
.readloop:
	push rsi
	push rdx
	xor edi, edi
	assert read == 0
	xor eax, eax
	syscall
	pop rdx
	pop rsi
	cmp rax, -EINTR
	jz .readloop
	cmp eax, 0
	jz .EOF
	jl .error
	add rsi, rax
	sub edx, eax
	jnz .readloop
	; same as above, but assume the terminator is found somewhere
	lea rdi, [rel wInputBuffer]
	mov rsi, rdi
	mov al, `\n`
	mov ecx, READ_BUFFER_SIZE
	repnz scasb
	jmp .gotline

.EOF:
	mov byte[rsi], `\n` ; in case the last line of the file doesn't end in a newline
	lea rdi, [rel wInputBuffer]
	sub rsi, rdi
	mov [rel wInputEOF], si
	jmp ReadInputLine

.error:
	mov edi, 2
	lea rsi, [rel .errormessage]
	call OutputMessage
	mov word[rel wInputEOF], 0
.atEOF:
	xor edi, edi
	xor esi, esi
	stc
	ret

.errormessage: db `standard input error\n`, 0

PrintMessage:
	mov edi, 1
OutputMessage:
	; in: edi: file descriptor, rsi: string
	push rdi
	xor eax, eax
	mov rcx, -1
	mov rdi, rsi
	repnz scasb
	sub rdi, rsi
	lea rdx, [rdi - 1]
.writeloop:
	mov edi, [rsp]
	push rsi
	push rdx
	mov eax, write
	syscall
	pop rdx
	pop rsi
	cmp rax, -EINTR
	jz .writeloop
	cmp rax, 0
	jle .done
	add rsi, rax
	sub rdx, rax
	jnz .writeloop
.done:
	add rsp, 8
	ret
