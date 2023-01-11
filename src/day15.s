	section .text
Prob15aVariableSize:
	; variant of 15a with a center line defined by command-line argument, for debugging the sample data
	endbr64
	call ParseNumberFromArgument
	push rdi
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

Prob15bVariableSize:
	; variant of 15b with a center line defined by command-line argument, for debugging the sample data
	endbr64
	call ParseNumberFromArgument
	push rdi
	jmp Prob15b.go

Prob15b:
	endbr64
	push 2000000
.go:

	; load all the sensors and beacons (reserving 32 bytes per entry to fill in later)
	xor r13, r13
	xor r15, r15
	vmovdqa xmm15, [rel .altsigns]
	call ReadBeacon
	jc InvalidInputError
.readloop:
	add r13, 32
	mov rdi, r15
	mov rsi, r13
	call MapMemory
	mov r15, rdi
	vpsubd xmm0, xmm13, xmm12
	vpabsd xmm0, xmm0
	vphaddd xmm0, xmm0, xmm0
	vmovd eax, xmm0
	not eax
	vpinsrd xmm0, xmm0, eax, 1
	vpshufd xmm0, xmm0, 0x50
	vpshufd xmm1, xmm12, 0
	vpshufd xmm2, xmm12, 0x55
	vpsignd xmm1, xmm1, xmm15
	vpaddd xmm2, xmm2, xmm1
	vpsubd xmm0, xmm2, xmm0
	vmovdqa [r15 + r13 - 32], xmm0
	call ReadBeacon
	jnc .readloop

	; transform the coordinate space from (x, y) into (y + x, y - x) so that all covered areas are rectangular, then
	; break down covered areas into non-overlapping pieces
	mov r12d, 32
.checknextentry:
	cmp r12, r13
	jz .overlapdone
	vpcmpeqd xmm13, xmm13, xmm13
	vpsrldq xmm12, xmm13, 8
.nextentry:
	xor r14, r14
	vmovdqa xmm14, [r15 + r12]
.next:
	vmovdqa xmm1, [r15 + r14]
	vpsubd xmm0, xmm14, xmm12
	vpshufd xmm7, xmm1, 0x22
	vpshufd xmm6, xmm0, 0x82
	vpcmpgtd xmm7, xmm6, xmm7
	vptest xmm7, xmm13
	jbe .nooverlap
	vpshufd xmm6, xmm0, 0xd7
	vpshufd xmm0, xmm1, 0x77
	vpcmpgtd xmm6, xmm6, xmm0
	vptest xmm6, xmm13
	jbe .nooverlap
	vphaddw xmm7, xmm7, xmm7
	vphaddw xmm6, xmm6, xmm6
	vpmovmskb eax, xmm7
	vpmovmskb edx, xmm6
	and al, 5
	and dl, 10
	or al, dl
	add al, al
	movzx eax, al
	lea rdx, [rel .jumptable]
	vpshufd xmm6, xmm1, 0x4e
	vmovdqa xmm7, [rdx + rax * 8 + (.vectordata - .jumptable)]
	jmp [rdx + rax * 4]

.trim:
	endbr64
	vpblendvb xmm6, xmm6, xmm14, xmm7
	vpshufd xmm1, xmm6, 0x4e
	vpcmpeqd xmm6, xmm1, xmm6
	vptest xmm6, xmm6
	jnz .replace
	vmovdqa [r15 + r14], xmm1
	jmp .nooverlap

.discard:
	endbr64
	sub r13, 32
	vmovdqa xmm0, [r15 + r13]
	vmovdqa [r15 + r12], xmm0
	jmp .checknextentry

.replace:
	endbr64
	sub r12, 32
	vmovdqa xmm0, [r15 + r12]
	vmovdqa [r15 + r14], xmm0
	sub r13, 32
	vmovdqa xmm0, [r15 + r13]
	vmovdqa [r15 + r12], xmm0
	jmp .replaced

.corner:
	endbr64
	vpblendvb xmm6, xmm1, xmm6, xmm7
	vpsllq xmm7, xmm7, 1
.split:
	endbr64
	vpblendvb xmm15, xmm14, xmm6, xmm7
	vpsllq xmm7, xmm7, 1
	vpblendvb xmm14, xmm14, xmm6, xmm7
	vpshufd xmm7, xmm15, 0x4e
	vpcmpeqd xmm7, xmm7, xmm15
	vptest xmm7, xmm7
	jnz .adjusted
	vpshufd xmm6, xmm14, 0x4e
	vpcmpeqd xmm6, xmm6, xmm14
	vptest xmm6, xmm6
	jnz .swap
	add r13, 32
	mov rdi, r15
	mov rsi, r13
	call MapMemory
	mov r15, rdi
	vmovdqa [rdi + r13 - 32], xmm15
	jmp .nooverlap

.swap:
	; xmm7 = 0 here
	vmovdqa xmm14, xmm15
.adjust:
	endbr64
	vpblendvb xmm14, xmm14, xmm6, xmm7
.adjusted:
	vpshufd xmm6, xmm14, 0x4e
	vpcmpeqd xmm6, xmm6, xmm14
	vptest xmm6, xmm6
	jnz .discard
.nooverlap:
	add r14, 32
.replaced:
	cmp r14, r12
	jc .next
	vmovdqa [r15 + r12], xmm14
	add r12, 32
	cmp r12, r13
	jc .nextentry

.overlapdone:
	; transform the rectangles back into (x, y) coordinate space, representing them as a rectangle (by two X and two Y
	; coordinates) minus four triangles in the corner (clockwise order from the top left; one size per triangle)
	; since transforming points from (y + x, y - x) to (x, y) results in half integers, some of these pieces will only
	; have half-integer points in them and thus be truly empty, and some of the corner triangles will appear to have a
	; negative size; these special cases are all ignored because further calculations treat them as zero anyway
	mov rsi, r15
	add r12, r15
	vmovdqa xmm6, [rel .altsigns]
	vmovdqa xmm7, [rel .edgeoffsets]
	vpshufd xmm5, xmm6, 0x14
.transformloop:
	vmovdqa xmm1, [rsi]
	vpshufd xmm3, xmm1, 0xf5
	vpshufd xmm2, xmm1, 0x88
	vpsignd xmm3, xmm3, xmm6
	vpaddd xmm2, xmm2, xmm7
	vpshufd xmm3, xmm3, 0x87
	vpaddd xmm2, xmm2, xmm3
	vpsrad xmm2, xmm2, 1
	vmovdqa [rsi], xmm2
	add rsi, 32
	vphsubd xmm4, xmm1, xmm1
	vpshufd xmm4, xmm4, 0x50
	vpshufd xmm3, xmm2, 0x14
	vpsignd xmm4, xmm4, xmm5
	vpsignd xmm3, xmm3, xmm5
	vpsrad xmm4, xmm4, 1
	vpsubd xmm4, xmm4, xmm3
	vmovdqa [rsi - 16], xmm4
	cmp rsi, r12
	jc .transformloop

	; begin with the entire region of interest, then halve it at each step, keeping the half that isn't fully covered
	vmovd xmm7, [rsp]
	vpxor xmm0, xmm0, xmm0
	vpshufd xmm7, xmm7, 0x11
	vpaddd xmm7, xmm7, xmm7
	vmovdqa xmm15, [rel .altsigns]
	vpshufd xmm14, xmm15, 0
	call .iscovered
	lea rsi, [rel ErrorMessages.nolocation]
	jz ErrorExit
.splitloop:
	vmovd eax, xmm7
	vpextrd edx, xmm7, 1
	add eax, edx
	sar eax, 1
	cmp eax, edx
	lea edx, [eax + 1]
	jz .nohorizontal
	vpinsrd xmm8, xmm7, edx, 0
	vpinsrd xmm7, xmm7, eax, 1
	call .iscovered
	jnz .nohorizontal
	vmovdqa xmm7, xmm8
.nohorizontal:
	vpextrd eax, xmm7, 2
	vpextrd edx, xmm7, 3
	add eax, edx
	sar eax, 1
	cmp eax, edx
	lea edx, [eax + 1]
	jz .novertical
	vpinsrd xmm8, xmm7, edx, 2
	vpinsrd xmm7, xmm7, eax, 3
	call .iscovered
	jnz .novertical
	vmovdqa xmm7, xmm8
.novertical:
	vphsubd xmm1, xmm7, xmm7
	vptest xmm1, xmm1
	jnz .splitloop

	; xmm7 contains the final coordinates now: print and exit
	pop rax
	vmovd edx, xmm7
	imul rdx, rax
	vpextrd eax, xmm7, 2
	add rdx, rdx
	add rax, rdx
	call PrintNumber
	mov rdi, r15
	xor esi, esi
	jmp MapMemory

.iscovered:
	; check if the region in xmm7 is fully covered; return in zero flag
	xor ecx, ecx
	mov rsi, r15
	vpshufd xmm6, xmm7, 0xb1
.coveredloop:
	vmovdqa xmm1, [rsi]
	add rsi, 32
	vpblendw xmm2, xmm1, xmm6, 0xcc
	vpblendw xmm3, xmm1, xmm6, 0x33
	vpcmpgtd xmm2, xmm2, xmm3
	vptest xmm2, xmm2
	jnz .skipregion
	vpmaxsd xmm2, xmm1, xmm7
	vpminsd xmm3, xmm1, xmm7
	vpblendw xmm2, xmm3, xmm2, 0x33
	vpsignd xmm1, xmm1, xmm15
	vpsignd xmm2, xmm2, xmm15
	vphaddd xmm3, xmm2, xmm2
	vpsubd xmm3, xmm14, xmm3
	vpextrd edx, xmm3, 1
	vmovd eax, xmm3
	imul rax, rdx
	add rcx, rax
	vpshufd xmm3, xmm1, 0xfa
	vpshufd xmm4, xmm1, 0x14
	vpaddd xmm3, xmm3, xmm4
	vpshufd xmm4, xmm2, 0xfa
	vpsubd xmm3, xmm3, xmm4
	vpshufd xmm4, xmm2, 0x14
	vpshufd xmm5, xmm2, 0x41
	vpsubd xmm4, xmm3, xmm4
	vpaddd xmm3, xmm3, xmm5
	vmovdqa xmm5, [rsi - 16]
	vphaddd xmm2, xmm2, xmm2
	vpsubd xmm2, xmm14, xmm2
	vpshufd xmm2, xmm2, 0xff
	vpaddd xmm3, xmm3, xmm5
	vpaddd xmm4, xmm4, xmm5
	vpsubd xmm5, xmm4, xmm2
	vpsubd xmm2, xmm3, xmm2
	vpmaxsd xmm3, xmm3, xmm0
	vpmaxsd xmm4, xmm4, xmm0
	vpmaxsd xmm5, xmm5, xmm0
	vpmaxsd xmm2, xmm2, xmm0
	vpunpckldq xmm1, xmm4, xmm0
	vpunpckhdq xmm4, xmm4, xmm0
	vpmuludq xmm10, xmm1, xmm1
	vpaddq xmm1, xmm1, xmm4
	vpaddq xmm1, xmm1, xmm10
	vpmuludq xmm4, xmm4, xmm4
	vpaddq xmm1, xmm1, xmm4
	vpunpckldq xmm4, xmm5, xmm0
	vpunpckhdq xmm5, xmm5, xmm0
	vpsubq xmm1, xmm1, xmm5
	vpmuludq xmm5, xmm5, xmm5
	vpsubq xmm1, xmm1, xmm4
	vpmuludq xmm4, xmm4, xmm4
	vpaddq xmm4, xmm4, xmm5
	vpsubq xmm1, xmm1, xmm4
	vpunpckldq xmm5, xmm3, xmm0
	vpunpckhdq xmm3, xmm3, xmm0
	vpmuludq xmm4, xmm5, xmm5
	vpaddq xmm5, xmm5, xmm3
	vpmuludq xmm3, xmm3, xmm3
	vpsubq xmm4, xmm4, xmm5
	vpaddq xmm3, xmm3, xmm4
	vpsubq xmm1, xmm1, xmm3
	vpunpckldq xmm3, xmm2, xmm0
	vpunpckhdq xmm2, xmm2, xmm0
	vpmuludq xmm4, xmm3, xmm3
	vpmuludq xmm5, xmm2, xmm2
	vpaddq xmm2, xmm2, xmm3
	vpaddq xmm4, xmm4, xmm5
	vpsubq xmm4, xmm4, xmm2
	vpaddq xmm1, xmm1, xmm4
	vpextrq rax, xmm1, 1
	vmovq rdx, xmm1
	add rax, rdx
	shr rax, 1
	sub rcx, rax
.skipregion:
	cmp rsi, r12
	jc .coveredloop
	vphsubd xmm1, xmm7, xmm0
	vpabsd xmm1, xmm1
	vpaddd xmm1, xmm1, xmm14
	vmovd eax, xmm1
	vpextrd edx, xmm1, 1
	imul rax, rdx
	cmp rax, rcx
	ret

	pushsection .rodata align=16
.jumptable:
	dq .corner  ;0
	dq .trim    ;1
	dq .trim    ;2
	dq .replace ;3
	dq .adjust  ;4
	dq .corner  ;5
	dq .split   ;6
	dq .trim    ;7
	dq .adjust  ;8
	dq .split   ;9
	dq .corner  ;a
	dq .trim    ;b
	dq .discard ;c
	dq .adjust  ;d
	dq .adjust  ;e
	dq .corner  ;f

.vectordata:
	dd 0x40404040,          0, 0xa0a0a0a0, 0xc0c0c0c0 ;0
	dd          0,          0,          0,         -1 ;1
	dd          0,          0,         -1,          0 ;2
.altsigns:
	dd          1,         -1,          1,         -1 ;3 (dummy, used elsewhere)
	dd          0,          0,          0,         -1 ;4
	dd 0xc0c0c0c0, 0x40404040,          0, 0xa0a0a0a0 ;5
	dd          0, 0x80808080,          0, 0x40404040 ;6
	dd         -1,          0,          0,          0 ;7
	dd          0,          0,         -1,          0 ;8
	dd 0x80808080,          0, 0x40404040,          0 ;9
	dd          0, 0xa0a0a0a0, 0xc0c0c0c0, 0x40404040 ;a
	dd          0,         -1,          0,          0 ;b
.edgeoffsets:
	dd          2,         -1,          1,         -2 ;c (dummy, used elsewhere)
	dd         -1,          0,          0,          0 ;d
	dd          0,         -1,          0,          0 ;e
	dd 0xa0a0a0a0, 0xc0c0c0c0, 0x40404040,          0 ;f
	popsection

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
