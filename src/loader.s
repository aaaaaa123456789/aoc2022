%assign LOADERSIZE 0x1000

	section loader align=16 exec
Loader:
	; get the current process ID and use it later for randomization
	mov eax, getpid
	syscall
	mov r10, rax

	; check for AVX support and exit early if not detected
	mov eax, 1
	cpuid
	bt ecx, 28
	lea rsi, [rel LoaderErrors.avx]
	jnc .errorexit

	; generate a random reload address (self-ASLR)
	mov rax, r10
	shr rax, 2
	mov rbx, rsp
	shl rbx, 20
	xor rbx, rax
	mov rax, 0x5851f42d4c957f2d ; common 64-bit LCG constant
	imul rbx, rax
	inc rbx
	imul rbx, rax
	shr rbx, 32
	inc ebx
	bt ecx, 30
	jnc .norand
	mov ecx, 5
.randloop:
	dec ecx
	jz .norand
	rdrand eax
	jnc .randloop
	xor ebx, eax
.norand:
	add rbx, 0x40000000
	mov rax, rsp
	and rax, -0x1000
	shr rax, 32
	xor eax, esp
	mov ecx, eax
	shr eax, 16
	xor eax, ecx
	xor ah, al
	mov ecx, eax
	shl eax, 4
	xor eax, ecx
	mov ecx, eax
	shr eax, 2
	xor eax, ecx
	shl r10, 12
	xor rax, r10
	and eax, 0x3000
	shl rbx, 14
	add rbx, rax

	; check the auxiliary vector for page size information and exit if it's bigger than LOADERSIZE
	mov rax, [rsp]
	lea rdi, [rsp + 8 * rax + 16]
	xor eax, eax
	mov rcx, -1
	repnz scasq
	lea rsi, [rdi - 8]
.auxloop:
	add rsi, 8
	lodsq
	test rax, rax
	jz .load ; not found
	cmp rax, 6 ; page size aux vector entry (AT_PAGESZ)
	jnz .auxloop
	cmp qword[rsi], LOADERSIZE
	lea rsi, [rel LoaderErrors.page]
	ja .errorexit

.load:
	; load the program segments at the new address
	lea rsi, [rel ELFHeader]
	sub rbx, rsi
	mov rbp, [rsi + 32]
	add rbp, rsi
	mov r13, rbp
	movzx r12, word[rsi + 56]
	movzx r15, word[rsi + 54]
.phloop:
	mov rdi, [rbp + 16]
	add rdi, rbx
	mov r14, rdi
	mov rsi, [rbp + 40]
	mov r8, -1
	xor r9, r9
	mov r10d, MAP_PRIVATE | MAP_FIXED | MAP_ANONYMOUS | MAP_LOCKED
	mov edx, PROT_WRITE
	mov eax, mmap
	syscall
	cmp rax, r14
	lea rsi, [rel LoaderErrors.map]
	jnz .errorexit
	mov rcx, [rbp + 32]
	test rcx, rcx
	jz .nocopy
	mov rdi, rax
	mov rsi, [rbp + 16]
	add rcx, 7
	shr rcx, 3
	rep movsq
.nocopy:
	add rbp, r15
	dec r12
	jnz .phloop

	; perform all necessary relocations at the loaded address
	lea rsi, [rel LoaderRelocationAddresses]
	lodsd
	test eax, eax
	jz .relocdone
.relocloop:
	add [rbx + rax], rbx
	lodsd
	test eax, eax
	jnz .relocloop

.relocdone:
	; flush all the writes and reapply memory protections
	sfence
	mov r10, rbx
	cpuid ; for serialization; eax = 0 here
	mov rbp, r13
	mov rbx, r10
	movzx r12, word[rel ELFHeader + 56]
.protectloop:
	mov al, [rbp + 4]
	mov rdi, [rbp + 16]
	add rdi, rbx
	mov rsi, [rbp + 40]
	; mprotect flags: read = 1, write = 2, exec = 4; ELF flags: read = 4, write = 2, exec = 1
	xor edx, edx
	%rep 3
		shr eax, 1
		rcl edx, 1
	%endrep
	mov eax, mprotect
	syscall
	lea rsi, [rel LoaderErrors.map]
	test rax, rax
	jnz .errorexit
	add rbp, r15
	dec r12
	jnz .protectloop

	; finally, jump to the remapped loader
	lea rax, [rel .unmap]
	add rax, rbx
	jmp rax

	; subroutines and data - placed here in the unreachable gap
.errorexit:
	; attempt to print an error message (ignore errors other than EINTR) and exit with status 255
	lea rbx, [rsi + 1]
.errorloop:
	mov edi, 2
	mov rsi, rbx
	movzx edx, byte[rbx - 1]
	mov eax, write
	syscall
	cmp rax, -EINTR
	jz .errorloop
	mov edi, 255
	mov eax, exit_group
	syscall
	ud2

	; pad for alignment! Must be done manually (the assert at the end enforces the alignment)

.unmap:
	endbr64
	; unmap the originally mapped locations ([rel ELFHeader] now points to the remapped area)
	lea rbp, [rbx + r13]
	movzx r12, word[rel ELFHeader + 56]
.unmaploop:
	mov rdi, [rbp + 16]
	mov rsi, [rbp + 40]
	mov eax, munmap
	syscall
	add rbp, r15
	dec r12
	jnz .unmaploop

	; unmap the loader and fall through to the true entry point
	lea rdi, [rel ELFHeader]
	mov esi, LOADERSIZE
	mov eax, munmap
	syscall

	assert !(($ - Loader) & 15), "Loader is unaligned (fix manual alignment)"

ELFHeader: equ $ - LOADERSIZE

	section loaddata align=4
LoaderErrors:
	.avx: db .end_avxmessage - .avxmessage
	.avxmessage: withend db `loader error: AVX not supported\n`
	.map: db .end_mapmessage - .mapmessage
	.mapmessage: withend db `loader error: failed to map memory\n`
	.page: db .end_pagemessage - .pagemessage
	.pagemessage: withend db `loader error: page size too large\n`

	align 4, db 0

LoaderRelocationAddresses:
	; to be filled by the "linker": 4 bytes per entry, end with a null
