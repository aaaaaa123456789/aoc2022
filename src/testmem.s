	absolute wModeData
wMemoryTestBuffers: resq 100
wMemoryTestCurrentBuffer: resw 1
wMemoryTestCurrentMode: resb 1
	resb 5 ; padding

	assert $ <= wModeData.end

	section .text
TestMemory:
	; reads a script from standard input and performs the allocations, reads and writes indicated there
	; a## size: allocates a buffer, assigned to ##
	; d## [size = 0]: reallocates/deallocates a buffer, assigned to ##
	; r## [offset = 0]: reads a string from buffer ##
	; w## offset string: writes string to buffer ##
	; m## size: maps memory, assigned to ##
	; u## [size = 0]: remaps/unmaps memory at buffer ##
	; p##: print status of buffer ##
	; blank lines and lines starting with # are ignored
	endbr64
	xor eax, eax
	lea rdi, [rel wMemoryTestBuffers]
	mov ecx, 100
	rep stosq
.loop:
	call ReadInputLine
	jc ExitSuccess
	call SkipSpaces
	lodsb
	test al, al
	jz .loop
	cmp al, "#"
	jz .loop
	mov [rel wMemoryTestCurrentMode], al
	call ParseNumber
	jc .badbuffer
	cmp rdi, 100
	jnc .badbuffer
	mov [rel wMemoryTestCurrentBuffer], di
	call SkipSpaces
	movzx eax, byte[rel wMemoryTestCurrentMode]
	lea rbx, [rel wMemoryTestBuffers]
	movzx edx, word[rel wMemoryTestCurrentBuffer]
	mov rdi, [rbx + 8 * rdx]
	cmp eax, "a"
	jz .allocate
	cmp eax, "d"
	jz .deallocate
	cmp eax, "r"
	jz .read
	cmp eax, "w"
	jz .write
	cmp eax, "m"
	jz .map
	cmp eax, "u"
	jz .unmap
	cmp eax, "p"
	jnz InvalidInputError
	cmp byte[rsi], 0
	jnz InvalidInputError
	test rdi, rdi
	jz .nullbuffer
	push rdi
	mov rax, rdi
	lea rdi, [rel wTextBuffer]
	call NumberToString
	mov eax, " "
	stosb
	mov rax, [rsp]
	mov rax, [rax - 16]
	call NumberToString
	mov eax, " "
	stosb
	pop rsi
	mov rax, [rsi - 8]
	test rax, rax
	jz .printnumber
	push rsi
	call NumberToString
	mov eax, " "
	stosb
	mov rax, [rsp]
	mov rax, [rax - 32]
	call NumberToString
	mov eax, " "
	stosb
	pop rax
	mov rax, [rax - 24]
	jmp .printnumber

.allocate:
	test rdi, rdi
	jnz .wouldleak
	call ParseNumber
	jc InvalidInputError
	push rdi
	call SkipSpaces
	cmp byte[rsi], 0
	pop rsi
	jnz InvalidInputError
	xor edi, edi
.allocateprint:
	call AllocateMemory
.allocated:
	lea rbx, [rel wMemoryTestBuffers]
	movzx edx, word[rel wMemoryTestCurrentBuffer]
	mov [rbx + 8 * rdx], rdi
	push rsi
	mov rax, rdi
	lea rdi, [rel wTextBuffer]
	call NumberToString
	mov eax, " "
	stosb
	pop rax
.printnumber:
	call NumberToString
	mov word[rdi], `\n`
	lea rsi, [rel wTextBuffer]
.print:
	call PrintMessage
	jmp .loop

.deallocate:
	test rdi, rdi
	jz .nullbuffer
	push rdi
	xor eax, eax
	cmp byte[rsi], 0
	jz .noreallocate
	call ParseNumber
	jc InvalidInputError
	push rdi
	call SkipSpaces
	cmp byte[rsi], 0
	jc InvalidInputError
	pop rax
.noreallocate:
	mov rsi, rax
	pop rdi
	jmp .allocateprint

.read:
	test rdi, rdi
	jz .nullbuffer
	cmp byte[rsi], 0
	jz .readaddress
	push rdi
	call ParseNumber
	jc InvalidInputError
	add [rsp], rdi
	call SkipSpaces
	cmp byte[rsi], 0
	jnz InvalidInputError
	pop rdi
.readaddress:
	mov rsi, rdi
	call PrintMessage
	lea rsi, [rel Newline]
	jmp .print

.write:
	test rdi, rdi
	jz .nullbuffer
	cmp byte[rsi], 0
	jz InvalidInputError
	push rdi
	call ParseNumber
	jc InvalidInputError
	add [rsp], rdi
	call SkipSpaces
	mov rdi, rsi
	xor eax, eax
	mov rcx, -1
	repnz scasb
	sub rdi, rsi
	push rsi
	push rdi
	mov rax, rdi
	call PrintNumber
	pop rcx
	pop rsi
	pop rdi
	rep movsb
	jmp .loop

.wouldleak:
	lea rsi, [rel .leakmessage]
	jmp .print

.map:
	test rdi, rdi
	jnz .wouldleak
	call ParseNumber
	jc InvalidInputError
	push rdi
	call SkipSpaces
	cmp byte[rsi], 0
	pop rsi
	jnz InvalidInputError
	xor edi, edi
.mapprint:
	call MapMemory
	jmp .allocated

.unmap:
	test rdi, rdi
	jz .nullbuffer
	push rdi
	xor edi, edi
	cmp byte[rsi], 0
	jz .noremap
	call ParseNumber
	jc InvalidInputError
	push rdi
	call SkipSpaces
	cmp byte[rsi], 0
	jc InvalidInputError
	pop rax
.noremap:
	mov rsi, rax
	pop rdi
	jmp .mapprint

.nullbuffer:
	lea rsi, [rel .nullmessage]
	jmp .print

.badbuffer:
	lea rsi, [rel .buffermessage]
	jmp ErrorExit

.buffermessage: db `error: invalid buffer number\n`, 0
.nullmessage: db `warning: buffer is null\n`, 0
.leakmessage: db `warning: buffer would be leaked\n`, 0
