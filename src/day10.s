	section .text
Prob10a:
	endbr64
	vpxor xmm14, xmm14, xmm14
	vpcmpeqd xmm15, xmm14, xmm14
	vpsubd xmm15, xmm14, xmm15
	vmovdqa xmm13, xmm15
	vmovdqa xmm12, xmm15
.loop:
	vpaddd xmm14, xmm14, xmm15
	call ReadInputLine
	jc .done
	lodsd
	cmp eax, "addx"
	jnz .loop
	call SkipSpaces
	call ParseNumber
	jc InvalidInputError
	cmp byte[rsi], 0
	jnz InvalidInputError
	vpaddd xmm14, xmm14, xmm15
	vmovd xmm2, edi
	vpshufd xmm2, xmm2, 0
	vpaddd xmm4, xmm12, xmm2
	vpaddd xmm5, xmm13, xmm2
	vpcmpgtd xmm3, xmm14, [rel .counterchecks]
	vpblendvb xmm12, xmm4, xmm12, xmm3
	vpcmpgtd xmm3, xmm14, [rel .counterchecks + 16]
	vpblendvb xmm13, xmm5, xmm13, xmm3
	jmp .loop
.done:
	vmovdqa xmm0, [rel .counterchecks]
	vmovdqa xmm1, [rel .counterchecks + 16]
	vpaddd xmm0, xmm0, xmm15
	vpaddd xmm1, xmm1, xmm15
	vpmulld xmm0, xmm0, xmm12
	vpmulld xmm1, xmm1, xmm13
	vpaddd xmm0, xmm0, xmm1
	times 2 vphaddd xmm0, xmm0, xmm0
	vmovd eax, xmm0
	call PrintNumber
	xor edi, edi
	ret

	pushsection .rodata align=16
.counterchecks:
	dd 19, 59, 99, 139
	dd 179, 219, -1, -1
	popsection

Prob10b:
	endbr64
	assert (wModeData.end - wModeData) >= (240 * 4)
	lea r12, [rel wModeData + 240 * 4]
	mov r13d, 1
	mov r14, -240
.readloop:
	mov [r12 + r14 * 4], r13d
	inc r14
	jz .donereading
	call ReadInputLine
	jc InvalidInputError
	lodsd
	cmp eax, "addx"
	jnz .readloop
	mov [r12 + r14 * 4], r13d
	call SkipSpaces
	call ParseNumber
	jc InvalidInputError
	cmp byte[rsi], 0
	jnz InvalidInputError
	add r13d, edi
	inc r14
	jnz .readloop
.donereading:
	lea rdi, [rel wTextBuffer]
	lea rsi, [r12 - 240 * 4]
	mov edx, 6
	mov ebx, "#"
.outerloop:
	mov ecx, 40
.innerloop:
	lodsd
	lea eax, [eax + ecx - 39]
	cmp eax, 3
	mov eax, "."
	cmovc eax, ebx
	stosb
	dec ecx
	jnz .innerloop
	mov eax, `\n`
	stosb
	dec edx
	jnz .outerloop
	mov byte[rdi], 0
	lea rsi, [rel wTextBuffer]
	call PrintMessage
	xor edi, edi
	ret
