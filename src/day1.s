	section .text
Prob1a:
	endbr64
	push 0
.outerloop:
	push 0
.innerloop:
	call ReadInputLine
	jc .done
	test edi, edi
	jz .endgroup
	call ParseNumber
	cmp byte[rsi], 0
	jnz InvalidInputError
	add [rsp], rdi
	jmp .innerloop

.endgroup:
	pop rax
	cmp rax, [rsp]
	cmovb rax, [rsp]
	mov [rsp], rax
	jmp .outerloop

.done:
	pop rax
	pop rsi
	cmp rax, rsi
	cmovb rax, rsi
	call PrintNumber
	xor edi, edi
	ret

Prob1b:
	endbr64
	push 0
	push 0
.outerloop:
	push 0
.innerloop:
	call ReadInputLine
	jc .endgroup
	test edi, edi
	jz .endgroup
	call ParseNumber
	cmp byte[rsi], 0
	jnz InvalidInputError
	add [rsp], rdi
	jmp .innerloop

.endgroup:
	sbb edx, edx
	pop rax
	mov edi, 0xffffffff
	cmp rax, rdi
	lea rdi, [rel .overflow]
	ja ErrorExit
	movdqa xmm0, [rsp]
	vpinsrd xmm0, xmm0, eax, 3
	vpshufd xmm1, xmm0, 0xff
	vpcmpgtd xmm1, xmm1, xmm0
	vpmovmskb eax, xmm1
	inc eax
	bsf eax, eax
	lea rdi, [rel .swapmasks]
	vpshufb xmm0, xmm0, [rdi + rax * 4]
	movdqa [rsp], xmm0
	test edx, edx
	jz .outerloop
	add rsp, 16
	times 2 vphaddd xmm0, xmm0, xmm0
	vmovd eax, xmm0
	call PrintNumber
	xor edi, edi
	ret

.overflow: db `error: overflow (total exceeds 0xffffffff)\n`, 0

	pushsection .rodata align=16
.swapmasks:
	db  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, -1, -1, -1, -1
	db 12, 13, 14, 15,  4,  5,  6,  7,  8,  9, 10, 11, -1, -1, -1, -1
	db  4,  5,  6,  7, 12, 13, 14, 15,  8,  9, 10, 11, -1, -1, -1, -1
	db  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, -1, -1, -1, -1
	popsection
