	section .text
Prob4a:
	endbr64
	push 0
.loop:
	call GetNextSectionAssignmentPair
	jc .done
	vpshufd xmm1, xmm0, 0x6c
	vpshufd xmm0, xmm0, 0xc6
	vpcmpgtd xmm0, xmm0, xmm1
	vphaddd xmm0, xmm0, xmm0
	vpmovmskb eax, xmm0
	cmp eax, 0xffff
	setnz al
	movzx eax, al
	add [rsp], rax
	jmp .loop
.done:
	pop rax
	call PrintNumber
	xor edi, edi
	ret

Prob4b:
	endbr64
	push 0
.loop:
	call GetNextSectionAssignmentPair
	jc .done
	vpshufd xmm1, xmm0, 0xd7
	vpcmpgtd xmm0, xmm0, xmm1
	vpmovmskb eax, xmm0
	test eax, eax
	setz al
	movzx eax, al
	add [rsp], rax
	jmp .loop
.done:
	pop rax
	call PrintNumber
	xor edi, edi
	ret

GetNextSectionAssignmentPair:
	call ReadInputLine
	jc .done
	test rdi, rdi
	jz GetNextSectionAssignmentPair
	sub rsp, 8
	call ParseNumber
	jc InvalidInputError
	push rdi
	lodsb
	cmp al, "-"
	jnz InvalidInputError
	call ParseNumber
	jc InvalidInputError
	mov [rsp + 4], edi
	lodsb
	cmp al, ","
	jnz InvalidInputError
	call ParseNumber
	jc InvalidInputError
	mov [rsp + 8], edi
	lodsb
	cmp al, "-"
	jnz InvalidInputError
	call ParseNumber
	jc InvalidInputError
	mov [rsp + 12], edi
	cmp byte[rsi], 0
	jnz InvalidInputError
	movdqu xmm0, [rsp]
	add rsp, 16
.done:
	ret
