	section .text
Prob15aSmall:
	; variant of 15a with a smaller board, used for the sample inputs
	endbr64
	push 10
	jmp Prob15a.go

Prob15a:
	endbr64
	push 2000000
.go:
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15
	call ReadBeacon
	jc .done
.loop:
	vpextrd eax, xmm13, 1
	cmp eax, [rsp]
	jnz .nobeacon
	test r15, r15
	jz .beacon
	vmovd eax, xmm13
	mov rdi, r14
	mov rcx, r15
	repnz scasd
	jz .nobeacon
.beacon:
	inc r15
	mov rdi, r14
	lea rsi, [r15 * 4]
	call AllocateMemory
	mov r14, rdi
	vmovd [rdi + r15 * 4 - 4], xmm13
.nobeacon:
	vpshufd xmm0, xmm12, 0xd4
	mov eax, [rsp]
	vpinsrd xmm1, xmm13, eax, 2
	vpsubd xmm0, xmm0, xmm1
	vpabsd xmm0, xmm0
	vphaddd xmm0, xmm0, xmm0
	vphsubd xmm0, xmm0, xmm0
	vmovd eax, xmm0
	not eax
	test eax, eax
	jns .nextentry
	vpinsrd xmm0, xmm0, eax, 1
	vpshufd xmm1, xmm0, 0x44
	vpshufd xmm0, xmm12, 0
	vpsubd xmm14, xmm0, xmm1
	test r13, r13
	jz .insert
	xor ecx, ecx
.check:
	vmovq xmm0, [r12 + rcx * 8]
	vpshufd xmm2, xmm0, 0x50
	vpcmpgtd xmm1, xmm14, xmm2
	vpmovmskb eax, xmm1
	cmp eax, 0xff
	jz .nextentry
	inc eax
	cmp ax, 2
	jc .next
	vpshufd xmm2, xmm1, 0x9c
	vpshufd xmm0, xmm0, 0x44
	vpshufd xmm1, xmm2, 0x4e
	vpxor xmm1, xmm1, xmm2
	vpblendvb xmm14, xmm0, xmm14, xmm1
	dec r13
	mov rax, [r12 + r13 * 8]
	mov [r12 + rcx * 8], rax
	dec rcx
.next:
	inc rcx
	cmp rcx, r13
	jc .check
.insert:
	inc r13
	mov rdi, r12
	lea rsi, [r13 * 8]
	call AllocateMemory
	mov r12, rdi
	vmovq [rdi + r13 * 8 - 8], xmm14
.nextentry:
	call ReadBeacon
	jnc .loop
	lea rax, [r12 + r13 * 8]
	shr r13, 1
	jnc .done
	mov qword[rax], 0 ; valid because all allocations round up to a multiple of 16
	inc r13

.done:
	add rsp, 8
	vpxor xmm0, xmm0, xmm0
	mov rsi, r12
	mov rcx, r13
	shr rcx, 1
	jnc .add
	vmovdqa xmm1, [rsi]
	add rsi, 16
	vphsubd xmm0, xmm1, xmm0
.add:
	test rcx, rcx
	jz .added
.addloop:
	vmovdqa xmm1, [rsi]
	vphsubd xmm1, xmm1, [rsi + 16]
	vpaddd xmm0, xmm0, xmm1
	add rsi, 32
	dec rcx
	jnz .addloop
.added:
	times 2 vphaddd xmm0, xmm0, xmm0
	vmovd eax, xmm0
	add rax, r15
	neg eax
	call PrintNumber
	mov rdi, r12
	xor esi, esi
	call AllocateMemory
	mov rdi, r14
	jmp AllocateMemory

ReadBeacon:
	; coordinates in xmm12, nearest in xmm13, as dwords
	call ReadInputLine
	jc .done
	call SkipNonSignedDigits
	jnc ReadBeacon
	call ParseNumber
	jc InvalidInputError
	vmovd xmm12, edi
	call .nextnumber
	vpinsrd xmm12, xmm12, edi, 1
	call .nextnumber
	vmovd xmm13, edi
	call .nextnumber
	vpinsrd xmm13, xmm13, edi, 1
	ret

.nextnumber:
	; returns with carry clear
	call SkipNonSignedDigits
	jnc InvalidInputError
	call ParseNumber
	jc InvalidInputError
.done:
	ret
