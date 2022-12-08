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
	lea rdi, [rel wTextBuffer]
	call NumberToString
	mov word[rdi], `\n`
	lea rsi, [rel wTextBuffer]
	call PrintMessage
	xor edi, edi
	ret
