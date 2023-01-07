	section .text
Prob12a:
	endbr64
	call ProcessTerrainElevationData
	mov eax, [rbp + r15 * 4]
	cmp eax, 0x7fffffff
	jnz PrintTerrainElevation
UnreachableTerrain:
	lea rsi, [rel ErrorMessages.unreachable]
	jmp ErrorExit

Prob12b:
	endbr64
	call ProcessTerrainElevationData
	mov edx, 0x7fffffff
	mov rsi, r13
	mov rbx, rsi
	neg rbx
	lea rbx, [rbp + 4 * rbx - 4]
	mov ecx, r14d
.loop:
	lodsb
	cmp al, "a"
	jnz .skip
	mov edi, [rbx + 4 * rsi]
	cmp edi, edx
	cmovb edx, edi
.skip:
	dec ecx
	jnz .loop
	mov eax, edx
	cmp eax, 0x7fffffff
	jz UnreachableTerrain
PrintTerrainElevation:
	call PrintNumber
	mov rdi, rbp
	xor esi, esi
	call MapMemory
	mov rdi, r13
	jmp MapMemory

ProcessTerrainElevationData:
	; out: r13 = terrain, r14 = total padded size, r15 = starting index, rbp = path distances
	call ReadInputLine
	jc InvalidInputError
	call StringLength
	jz ProcessTerrainElevationData
	lea r12, [rdi + 2]
	mov r15, rsi
	lea rsi, [r12 + r12]
	mov r14, rsi
	xor edi, edi
	call MapMemory
	mov r13, rdi
	lea rdi, [rdi + r12 + 1]
	mov rsi, r15
	lea rcx, [r12 - 2]
	rep movsb
.readloop:
	call ReadInputLine
	jc .donereading
	call StringLength
	jz .readloop
	sub rdi, r12
	cmp rdi, -2
	jnz InvalidInputError
	mov r15, rsi
	mov rdi, r13
	lea rsi, [r14 + r12]
	call MapMemory
	mov r13, rdi
	lea rdi, [rdi + r14 + 1]
	lea rcx, [r12 - 2]
	mov rsi, r15
	rep movsb
	add r14, r12
	jmp .readloop

.donereading:
	mov rdi, r13
	lea rsi, [r14 + r12]
	call MapMemory
	mov r13, rdi
	add r14, r12

	xor edi, edi
	lea rsi, [r14 * 9]
	shl rsi, 2
	call MapMemory
	mov rcx, r14
	mov rbp, rdi
	mov eax, 0x7fffffff
	rep stosd
	mov rsi, rdi
	; ensure that the zeroes at the border are too low compared with actual data
	mov eax, 1
	call .findbyte
	jnc InvalidInputError
	mov eax, "S"
	call .findbyte
	jc InvalidInputError
	mov r15, rdi
	mov byte[r13 + rdi], "a"
	mov eax, "E"
	call .findbyte
	jc InvalidInputError
	mov byte[r13 + rdi], "z"
	mov eax, edi
	mov r11, r12
	neg r11
	mov rdi, rsi
	stosq
.loop:
	lodsd
	mov edx, eax
	lodsd
	cmp eax, [rbp + 4 * rdx]
	jnc .skipcell
	mov [rbp + 4 * rdx], eax
	inc eax
	movzx ebx, byte[r13 + rdx]
	dec ebx
	vmovd xmm2, ebx
	vpshufd xmm2, xmm2, 0
	lea rcx, [rdx + r11]
	mov ebx, [rbp + 4 * rcx]
	vmovd xmm3, ecx
	movzx ecx, byte[r13 + rcx]
	vmovd xmm4, ebx
	vmovd xmm5, ecx
	lea rcx, [rdx + r12]
	mov ebx, [rbp + 4 * rcx]
	vpinsrd xmm3, xmm3, ecx, 1
	movzx ecx, byte[r13 + rcx]
	vpinsrd xmm4, xmm4, ebx, 1
	vpinsrd xmm5, xmm5, ecx, 1
	lea rcx, [rdx - 1]
	mov ebx, [rbp + 4 * rcx]
	vpinsrd xmm3, xmm3, ecx, 2
	movzx ecx, byte[r13 + rcx]
	vpinsrd xmm4, xmm4, ebx, 2
	vpinsrd xmm5, xmm5, ecx, 2
	lea rcx, [rdx + 1]
	mov ebx, [rbp + 4 * rcx]
	vpinsrd xmm3, xmm3, ecx, 3
	movzx ecx, byte[r13 + rcx]
	vpinsrd xmm4, xmm4, ebx, 3
	vpinsrd xmm5, xmm5, ecx, 3
	vpcmpgtd xmm2, xmm2, xmm5
	mov ecx, eax
	inc eax
	vmovd xmm5, eax
	vpshufd xmm5, xmm5, 0
	vpcmpgtd xmm5, xmm5, xmm4
	vpor xmm2, xmm2, xmm5
	vpshufb xmm2, xmm2, [rel .packing]
	vpmovmskb ebx, xmm2
	%assign curindex 0
	%rep 4
		shr ebx, 1
		jc .skip%[curindex]
		%if curindex
			vpextrd eax, xmm3, curindex
		%else
			vmovd eax, xmm3
		%endif
		stosd
		mov eax, ecx
		stosd
.skip%[curindex]:
		%assign curindex curindex + 1
	%endrep
.skipcell:
	cmp rsi, rdi
	jnz .loop
	ret

.findbyte:
	lea rdi, [r12 * 2 + 2]
	mov rcx, r14
	sub rcx, rdi
	lea rdi, [r13 + r12 + 1]
	repnz scasb
	cmovnz rdi, r13
	dec rdi
	sub rdi, r13 ; sets carry if not found
	ret

	pushsection .rodata align=16
.packing:
	db 3, 7, 11, 15
	times 12 db -1
	popsection
