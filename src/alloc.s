struc allocation, -0x10
	.mapping:
	.size:     resq 1
	.base:     resq 1
	.data:
	assert !allocation.data, "invalid allocation header"
endstruc

	section .text
MapMemory:
	; in: rdi = mapping to update (null: create new), rsi = size (zero: free)
	; out: rdi = mapping, rsi = effective size
	test rsi, rsi
	jz .free
	test rdi, rdi
	jnz .update
	; rdi = null is already set to the right value for the call
	add rsi, -allocation.mapping + MAPPING_ALIGNMENT - 1
	and rsi, -MAPPING_ALIGNMENT
	push rsi
	mov edx, PROT_READ | PROT_WRITE
	mov r10, MAP_PRIVATE | MAP_ANONYMOUS
	mov r8, -1
	xor r9, r9
	mov eax, mmap
	syscall
	pop rsi
	test rax, rax
	jle .error
	mov [rax - allocation.mapping + allocation.size], rsi
	mov qword[rax - allocation.mapping + allocation.base], 0
.allocated:
	lea rdi, [rax - allocation.mapping]
.resized:
	add rsi, allocation.mapping
.done:
	ret

.update:
	lea rdx, [rsi - allocation.mapping + MAPPING_ALIGNMENT - 1]
	and rdx, -MAPPING_ALIGNMENT
	mov rsi, [rdi + allocation.size]
	cmp rsi, rdx
	jz .resized
	mov [rdi + allocation.size], rdx
	add rdi, allocation.mapping
	mov r10, MREMAP_MAYMOVE
	mov eax, mremap
	syscall
	test rax, rax
	jle .error
	mov rsi, [rax - allocation.mapping + allocation.size]
	jmp .allocated

.free:
	test rdi, rdi
	jz .done
	mov rsi, [rdi + allocation.size]
	add rdi, allocation.mapping
	mov eax, munmap
	syscall
	xor esi, esi
	xor edi, edi
	test rax, rax
	jz .done
.error:
	lea rsi, [rel .message]
	mov dword[rel wOutputFD], 2
	call PrintMessage
	mov edi, 2
	mov eax, exit_group
	syscall
.message:
	db `error: failed to allocate memory\n`, 0
