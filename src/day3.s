	section .text
Prob3a:
	endbr64
	xor edi, edi
	push rdi
.loop:
	call ReadInputLine
	jc .done
	test edi, edi
	jz .loop
	shr rdi, 1
	jc InvalidInputError
	mov ebx, 1
	mov ecx, 1
	lea rbp, [rsi + rdi]
.itemloop:
	lodsb
	movzx eax, al
	lea rdx, [rax - ("A" - 27)]
	sub eax, "a" - 1
	cmovc eax, edx
	bts rbx, rax
	movzx eax, byte[rbp + rdi - 1]
	lea rdx, [rax - ("A" - 27)]
	sub eax, "a" - 1
	cmovc eax, edx
	bts rcx, rax
	dec rdi
	jnz .itemloop
	and rcx, rbx
	bsr rdi, rcx
	add [rsp], rdi
	jmp .loop
.done:
	pop rax
	call PrintNumber
	xor edi, edi
	ret

Prob3b:
	endbr64
	push 0
.loop:
	call .readnext
	jc Prob3a.done
	push rdx
	call .readnext
	jc InvalidInputError
	and [rsp], rdx
	call .readnext
	jc InvalidInputError
	pop rax
	and rax, rdx
	bsr rax, rax
	add [rsp], rax
	jmp .loop

.readnext:
	call ReadInputLine
	jc .return
	test rdi, rdi
	jz .return
	mov edx, 1
.itemloop:
	lodsb
	movzx eax, al
	lea rcx, [rax - ("A" - 27)]
	sub eax, "a" - 1
	cmovc eax, ecx
	bts rdx, rax
	dec rdi
	jnz .itemloop
	clc
.return:
	ret
