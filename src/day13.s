	absolute wModeData

wFirstPacketGroup:
wPacketNumber: resq 1

wSecondPacketGroup:
wPacketTotal: resq 1

wPacketBuffer: resq 1

	assert $ <= wModeData.end

	section .text
Prob13a:
	endbr64
	call InitializePacketBuffer
	xor edi, edi
	mov [rel wPacketNumber], rdi
	mov [rel wPacketTotal], rdi
.loop:
	inc qword[rel wPacketNumber]
	call ReadPacketLine
	test r14, r14
	jz .done
	push r14
	call ReadPacketLine
	test r14, r14
	jz InvalidInputError
	mov rdi, r14
	pop rsi
	mov r15, rsi
	call ComparePackets
	mov eax, 0
	cmovc rax, [rel wPacketNumber]
	add [rel wPacketTotal], rax
	mov rdi, r14
	xor esi, esi
	call AllocateMemory
	mov rdi, r15
	call AllocateMemory
	jmp .loop

.done:
	mov rax, [rel wPacketTotal]
PrintPacketTotal:
	call PrintNumber
	mov rdi, [rel wPacketBuffer]
	xor esi, esi
	jmp AllocateMemory

Prob13b:
	endbr64
	mov qword[rel wFirstPacketGroup], 1
	mov qword[rel wSecondPacketGroup], 2
	call InitializePacketBuffer
.loop:
	call ReadPacketLine
	test r14, r14
	jz .done
	mov rsi, r14
	lea rdi, [rel .packet2]
	call ComparePackets
	jnc .above2
	inc qword[rel wFirstPacketGroup]
	jmp .increment
.above2:
	mov rsi, r14
	lea rdi, [rel .packet6]
	call ComparePackets
	jnc .above6
.increment:
	inc qword[rel wSecondPacketGroup]
.above6:
	mov rdi, r14
	xor esi, esi
	call AllocateMemory
	jmp .loop

.done:
	mov rax, [rel wFirstPacketGroup]
	imul rax, [rel wSecondPacketGroup]
	jmp PrintPacketTotal

	pushsection .rodata align=16
.packet2: dq 1, .packet2 + 16, 1, 5
.packet6: dq 1, .packet6 + 16, 1, 13
	popsection

InitializePacketBuffer:
	xor edi, edi
	mov esi, 16
	call AllocateMemory
	mov qword[rdi], 1
	mov [rel wPacketBuffer], rdi
	ret

ComparePackets:
	mov rax, rsi
	mov rdx, [rel wPacketBuffer]
	test rdi, 1
	cmovnz rax, rdi
	cmovnz rdi, rdx
	test rsi, 1
	cmovnz rsi, rdx
	mov [rdx + 8], rax
	lodsq
	mov rcx, rax
	mov rdx, [rdi]
	add rdi, 8
	sub rax, rdx
	cmovnc rcx, rdx
	mov rdx, rax
	test rcx, rcx
	jz .endlist
.compareloop:
	mov eax, 1
	and eax, [rdi]
	and eax, [rsi]
	jz .comparelists
	cmpsq
	jnz .return
.comparenext:
	dec rcx
	jnz .compareloop
.endlist:
	shl rdx, 1
.return:
	ret

.comparelists:
	push rdx
	push rcx
	lodsq
	push rsi
	mov rsi, rax
	add rdi, 8
	push rdi
	mov rdi, [rdi - 8]
	call ComparePackets
	pop rdi
	pop rsi
	pop rcx
	pop rdx
	jz .comparenext
	ret

ReadPacketLine:
	xor r14, r14
.read:
	call ReadInputLine
	jc .return
	call SkipSpaces
	mov al, [rsi]
	test al, al
	jz .read
	cmp al, "["
	jnz InvalidInputError
	lea r13, [rsi - 1]
	xor r12, r12
	xor r15, r15
.loop:
	inc r13
	movzx eax, byte[r13]
	vmovd xmm0, eax
	vpcmpistri xmm0, [rel .inputchars], 0
	jnc InvalidInputError
	cmp ecx, 2
	jc .loop
	sub rcx, 4
	mov edi, ecx
	jnc .number
	lea r14, [r14 + rcx * 2 + 3]
.value:
	xchg r15, rdi
	inc r12
	lea rsi, [r12 * 4]
	call AllocateMemory
	xchg r15, rdi
	mov [r15 + r12 * 4 - 4], edi
	test r14, r14
	jg .loop
	jnz InvalidInputError
	lea rsi, [r12 * 8 - 8]
	xor edi, edi
	call AllocateMemory
	mov r14, rdi
	lea rsi, [r15 + 4]
	call .build
	mov rdi, r15
	xor esi, esi
	jmp AllocateMemory

.number:
	mov rsi, r13
	call ParseNumber
	jc InvalidInputError
	lea r13, [rsi - 1]
	jmp .value

.build:
	add rdi, 8
	mov rdx, rdi
.copyloop:
	lodsd
	cmp eax, -2
	jz .reparse
	adc rax, rax ; cmp will have set carry unless eax = -1
	stosq
	cmp eax, -2
	jnz .copyloop
	mov [rdi - 8], rsi
	mov rcx, 1
.scanloop:
	lodsd
	add eax, 2
	jnc .scanloop
	lea rcx, [rcx + rax * 2 - 1]
	test rcx, rcx
	jnz .scanloop
	jmp .copyloop

.reparse:
	mov rcx, rdi
	sub rcx, rdx
	shr rcx, 3
	mov [rdx - 8], rcx
	jz .return
	mov rsi, rdx
.reparseloop:
	lodsq
	test eax, 1
	jnz .nosublist
	push rsi
	push rcx
	mov [rsi - 8], rdi
	mov rsi, rax
	call .build
	pop rcx
	pop rsi
.nosublist:
	dec rcx
	jnz .reparseloop
.return:
	ret

	pushsection .rodata align=16
.inputchars: db " ,][0123456789", 0, 0
	popsection
