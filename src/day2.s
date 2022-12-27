	section .text
Prob2a:
	endbr64
	lea rsi, [rel .scores]
	jmp TallyRPSThrows

	pushsection .rodata align=16
.scores:
	dd 4, 8, 3, 0
	dd 1, 5, 9, 0
	dd 7, 2, 6, 0
	popsection

Prob2b:
	endbr64
	lea rsi, [rel .scores]
	; fallthrough -- the data doesn't obstruct flow because it's in a different section

	pushsection .rodata align=16
.scores:
	dd 3, 4, 8, 0
	dd 1, 5, 9, 0
	dd 2, 6, 7, 0
	popsection

TallyRPSThrows:
	sub rsp, 48
	mov rdi, rsp
	xor eax, eax
	mov ecx, 6
	rep stosq
	push rsi
.loop:
	call ReadInputLine
	jc .done
	test rdi, rdi
	jz .loop
	cmp rdi, 3
	jnz InvalidInputError
	mov al, [rsi]
	shl al, 2
	add al, [rsi + 2]
	sub al, ("A" * 4 + "X") & 0xff
	movzx eax, al
	cmp eax, 12
	jnc InvalidInputError
	inc dword[rsp + 4 * rax + 8]
	jmp .loop

.done:
	pop rsi
	vmovdqa xmm0, [rsp]
	vmovdqa xmm1, [rsp + 16]
	vmovdqa xmm2, [rsp + 32]
	add rsp, 48
	vpmulld xmm0, xmm0, [rsi]
	vpmulld xmm1, xmm1, [rsi + 16]
	vpaddd xmm0, xmm0, xmm1
	vpmulld xmm2, xmm2, [rsi + 32]
	vpaddd xmm0, xmm0, xmm2
	times 2 vphaddd xmm0, xmm0, xmm0
	vmovd eax, xmm0
	call PrintNumber
	xor edi, edi
	ret
