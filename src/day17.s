	section .text
Prob17a:
	endbr64
	xor edi, edi
	mov esi, (2022 * 13 / 5 + 14) & -8
	call MapMemory
	push rdi
	mov ecx, (2022 * 13 / 5 + 14) >> 3
	mov rax, 0x8080808080808080
	rep stosq
.read:
	call ReadInputLine
	jc InvalidInputError
	test rdi, rdi
	jz .read
	pop rdi
	mov rbp, rsi
	xor ecx, ecx
	mov ebx, 0x0000001e
	mov r11, rbx
	vmovdqa xmm0, [rel .rocks]
	mov edx, 3
	mov r10d, 2022
	mov al, -1
	stosb
.loop:
	cmp byte[rsi], 0
	cmovz rsi, rbp
	mov eax, ebx
	rol eax, 2
	cmp byte[rsi], ">"
	cmovz eax, ebx
	inc rsi
	ror eax, 1
	test eax, [rdi + rdx]
	cmovz ebx, eax
	dec rdx
	test ebx, [rdi + rdx]
	jz .loop
	inc rdx
	or [rdi + rdx], ebx
	mov rbx, rdi
	add rdi, rcx
	mov al, 0x80
	mov rcx, -1
	repnz scasb
	sub edi, ebx
	lea rcx, [rdi - 1]
	mov rdi, rbx
	lea rdx, [rcx + 3]
	vmovd xmm1, r11d
	vmovd r11d, xmm0
	vpalignr xmm0, xmm1, xmm0, 4
	mov rbx, r11
	dec r10
	jnz .loop
	mov r12, rdi
	mov eax, ecx
	call PrintNumber
	lea rdi, [r12 - 1]
	xor esi, esi
	jmp MapMemory

	pushsection .rodata align=16
.rocks:
	; excluding the first one (already loaded)
	dd 0x00081c08, 0x0004041c, 0x10101010, 0x00001818
	popsection
