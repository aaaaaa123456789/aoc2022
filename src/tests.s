	section .text

TestCat:
	; simple test cat program, to make sure input and output work correctly
	endbr64
.loop:
	call ReadInputLine
	jc ExitSuccess
	call PrintMessage
	; inefficient, but this is just a test
	lea rsi, [rel Newline]
	call PrintMessage
	jmp .loop

TestMap:
	; tests memory mappings by reading commands from standard input
	; ID len: allocate; <ID[+/-offset] [count]: read words; >ID[+/-offset] data data data...: write words; # indicates a comment
	endbr64
	xor eax, eax
	mov ecx, (wModeData.end - wModeData) / 8
	lea rdi, [rel wModeData]
	rep stosq
.loop:
	call ReadInputLine
	jc ExitSuccess
	call SkipSpaces
	cmp byte[rdi - 1], 0
	jz .loop
	cmp byte[rdi - 1], "#"
	jz .loop
	cmp byte[rdi - 1], "<"
	jz .read
	cmp byte[rdi - 1], ">"
	jz .write
	lea rsi, [rdi - 1]
	call ParseNumber
	jc InvalidInputError
	push rdi
	call SkipSpaces
	call ParseNumber
	jc InvalidInputError
	mov rsi, rdi
	pop rdi
	test rdi, rdi
	lea rax, [rel wModeData]
	mov rax, [rax + 8 * rdi]
	cmovnz rdi, rax
	call MapMemory
	push rsi
	push rdi
	mov rdx, rdi
	lea rdi, [rel wTextBuffer]
	lea rsi, [rel wModeData]
	inc qword[rsi]
	mov rax, [rsi]
	mov [rsi + 8 * rax], rdx
	call NumberToString
	mov eax, ": "
	stosw
	pop rax
	call NumberToString
	mov al, " "
	stosb
	pop rax
	call NumberToString
	mov word[rdi], `\n`
	lea rsi, [rel wTextBuffer]
	call PrintMessage
	jmp .loop

.read:
	mov rsi, rdi
	call SkipSpaces
	call .readaddress
	push rdi
	call SkipSpaces
	mov ecx, 1
	cmp byte[rsi], 0
	jz .nocount
	call ParseNumber
	jc InvalidInputError
	mov rcx, rdi
	cmp rcx, 187
	lea rsi, [rel ErrorMessages.highcount]
	jnc .popprint
	test ecx, ecx
	jz .loop
.nocount:
	push rcx
	lea rdi, [rel wTextBuffer]
.readloop:
	mov rsi, [rsp + 8]
	mov eax, [rsi]
	call NumberToString
	mov al, " "
	stosb
	add qword[rsp + 8], 4
	dec qword[rsp]
	jnz .readloop
	mov word[rdi - 1], `\n`
	lea rsi, [rel wTextBuffer]
	add rsp, 16
	call PrintMessage
	jmp .loop

.write:
	mov rsi, rdi
	call SkipSpaces
	call .readaddress
.writeloop:
	push rdi
	call SkipSpaces
	cmp byte[rsi], 0
	jz .popprint ; will print a blank line
	call ParseNumber
	jc InvalidInputError
	mov eax, edi
	sar rdi, 32
	inc edi
	cmp edi, 2
	jnc .overflow
	pop rdi
	stosd
	jmp .writeloop

.readaddress:
	call ParseNumber
	jc InvalidInputError
	lea rax, [rel wModeData]
	mov rdi, [rax + 8 * rdi]
	cmp byte[rsi], "+"
	jz .readoffset
	cmp byte[rsi], "-"
	jnz .return
.readoffset:
	push rdi
	call ParseNumber
	pop rax
	add rdi, rax
.return:
	ret

.overflow:
	lea rsi, [rel ErrorMessages.overflow]
.popprint:
	add rsp, 8
	call PrintMessage
	jmp .loop
