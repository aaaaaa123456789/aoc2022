	absolute wModeData
; points to an array of pointers to the stacks themselves, which are sequences of characters, bottom to top
; the stacks contain a dword count before the pointer (at ptr - 4) and no terminator
wStackLayoutStacks: resq 1

wStackLayoutBuffer: resq 1
wStackLayoutPosition: resq 1
wStackLayoutLimit: resq 1
wStackLayoutCurrentStack: resb 1
wStackLayoutStackCount: resb 1
	resb 6 ; padding

	assert $ <= wModeData.end

	section .text
Prob5a:
	endbr64
	call ReadStartingStackLayout
.loop:
	call ReadNextStackMovement
	jc PrintStackTops
	mov rbx, [rel wStackLayoutStacks]
	mov rsi, [rbx + 8 * rsi]
	sub [rsi - 4], ecx
	jc InvalidInputError
	mov eax, [rsi - 4]
	lea rsi, [rsi + rax - 1]
	mov rdi, [rbx + 8 * rdi]
	mov eax, [rdi - 4]
	add [rdi - 4], ecx
	add rdi, rax
.copy:
	mov al, [rsi + rcx]
	stosb
	dec ecx
	jnz .copy
	jmp .loop

Prob5b:
	endbr64
	call ReadStartingStackLayout
.loop:
	call ReadNextStackMovement
	jc PrintStackTops
	mov rbx, [rel wStackLayoutStacks]
	mov rsi, [rbx + 8 * rsi]
	sub [rsi - 4], ecx
	jc InvalidInputError
	mov eax, [rsi - 4]
	add rsi, rax
	mov rdi, [rbx + 8 * rdi]
	mov eax, [rdi - 4]
	add [rdi - 4], rcx
	add rdi, rax
	rep movsb
	jmp .loop

PrintStackTops:
	mov rsi, [rel wStackLayoutStacks]
	lea rdi, [rel wTextBuffer]
	movzx ecx, byte[rel wStackLayoutStackCount]
.loop:
	lodsq
	mov edx, [rax - 4]
	test edx, edx
	jz .skip
	mov al, [rax + rdx - 1]
	stosb
.skip:
	dec ecx
	jnz .loop
	mov word[rdi], `\n`
	lea rsi, [rel wTextBuffer]
	call PrintMessage
	xor edi, edi
	ret

ReadStartingStackLayout:
	mov byte[rel wStackLayoutStackCount], 0
	xor edi, edi
	mov esi, 16
	; allocate the minimal possible buffer
	call MapMemory
	mov [rel wStackLayoutBuffer], rdi
	mov [rel wStackLayoutPosition], rdi
	add rsi, rdi
	mov [rel wStackLayoutLimit], rsi
.loop:
	call ReadInputLine
	jc InvalidInputError
	test rdi, rdi
	jz .done
	mov byte[rel wStackLayoutCurrentStack], 0
.innerloop:
	lodsb
	cmp al, "["
	lodsw
	jnz .skip
	mov ah, [rel wStackLayoutCurrentStack]
	mov rdi, [rel wStackLayoutPosition]
	stosw
	mov [rel wStackLayoutPosition], rdi
	cmp rdi, [rel wStackLayoutLimit]
	jc .skip
	mov rsi, rdi
	mov rdi, [rel wStackLayoutBuffer]
	sub rsi, rdi
	push rsi
	add rsi, 16
	call MapMemory
	mov [rel wStackLayoutBuffer], rdi
	add rsi, rdi
	mov [rel wStackLayoutLimit], rsi
	pop rsi
	add rsi, rdi
	mov [rel wStackLayoutPosition], rsi
.skip:
	inc byte[rel wStackLayoutCurrentStack]
	lodsb
	test al, al
	jnz .innerloop
	mov al, [rel wStackLayoutCurrentStack]
	cmp al, [rel wStackLayoutStackCount]
	jbe .loop
	mov [rel wStackLayoutStackCount], al
	jmp .loop

.done:
	mov rdi, [rel wStackLayoutPosition]
	sub rdi, [rel wStackLayoutBuffer]
	movzx esi, byte[rel wStackLayoutStackCount]
	test esi, esi
	jz InvalidInputError
	add rdi, 15
	and rdi, -4
	imul rsi, rdi
	push rdi
	xor edi, edi
	call MapMemory
	mov [rel wStackLayoutStacks], rdi
	pop rsi
	sub rsi, 8
	movzx ecx, byte[rel wStackLayoutStackCount]
	lea rax, [rdi + rcx * 8 + 4]
.initloop:
	stosq
	mov dword[rax - 4], 0
	add rax, rsi
	dec ecx
	jnz .initloop

	mov rdi, [rel wStackLayoutStacks]
	mov rsi, [rel wStackLayoutPosition]
	sub rsi, 2
	std
.loadloop:
	lodsw
	movzx ecx, ah
	mov rcx, [rdi + 8 * rcx]
	mov edx, [rcx - 4]
	inc dword[rcx - 4]
	mov [rcx + rdx], al
	cmp rsi, [rel wStackLayoutBuffer]
	jnc .loadloop
	cld
	mov rdi, [rel wStackLayoutBuffer]
	xor esi, esi
	jmp MapMemory

ReadNextStackMovement:
	call ReadInputLine
	jc .done
	cmp dword[rsi], "move"
	jnz InvalidInputError
	cmp byte[rsi + 4], " "
	jnz InvalidInputError
	add rsi, 5
	call ParseNumber
	jc InvalidInputError
	test rdi, rdi
	jle InvalidInputError
	push rdi
	cmp dword[rsi], " fro"
	jnz InvalidInputError
	cmp word[rsi + 4], "m "
	jnz InvalidInputError
	add rsi, 6
	call ParseNumber
	call .checkstack
	push rdi
	cmp dword[rsi], " to "
	jnz InvalidInputError
	add rsi, 4
	call ParseNumber
	call .checkstack
	cmp byte[rsi], 0
	jnz InvalidInputError
	; carry is clear here
	pop rsi
	pop rcx
.done:
	ret

.checkstack:
	jc InvalidInputError
	dec rdi
	test rdi, -0x100
	jnz InvalidInputError
	cmp dil, [rel wStackLayoutStackCount]
	jnc InvalidInputError
	ret
