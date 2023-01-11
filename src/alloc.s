struc allocation, -0x20
	.allocation:
	.previous: resq 1
	.next:     resq 1
	.mapping:
	.size:     resq 1
	.base:     resq 1
	.data:
	assert !allocation.data, "invalid allocation header"
endstruc

	section .text
; none of these functions are allowed to clobber r12-r15 or xmm12-xmm15

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
	mov r10d, MAP_PRIVATE | MAP_ANONYMOUS
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
	mov r10d, MREMAP_MAYMOVE
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
	lea rsi, [rel ErrorMessages.allocation]
	mov dword[rel wOutputFD], 2
	call PrintMessage
	mov edi, 2
	mov eax, exit_group
	syscall
	ud2

AllocateMemory:
	; in: rdi = current allocation (null to allocate new), rsi = size (zero to free)
	; out: rdi = allocation, rsi = actual size
	test rdi, rdi
	jnz .update
	add rsi, 15
	and rsi, -16
	jz .done
.allocate:
	lea rax, [rsi - allocation.allocation]
	cmp rax, MAPPING_THRESHOLD
	jnc MapMemory
	sub [rel wAllocationRemainingSpace], eax
	jc .newmap
	mov rbx, [rel wLastAllocation]
	mov rdx, [rbx - allocation.allocation + allocation.size]
	lea rdi, [rdx + rbx]
	mov [rbx - allocation.allocation + allocation.next], rdi
	mov [rel wLastAllocation], rdi
	sub rdi, allocation.allocation
	mov [rdi + allocation.previous], rbx
	mov qword[rdi + allocation.next], 0
	mov [rdi + allocation.size], rax
	mov rax, [rel wCurrentAllocationMapping]
	mov [rdi + allocation.base], rax
.done:
	ret

.newmap:
	push rax
	mov esi, ALLOCATION_BUFFER_SIZE + allocation.mapping
	call MapMemory
	mov [rel wCurrentAllocationMapping], rdi
	mov [rel wLastAllocation], rdi
	pop rax
	sub esi, eax
	mov [rel wAllocationRemainingSpace], esi
	mov [rdi - allocation.allocation + allocation.base], rdi
	sub rdi, allocation.allocation
	mov [rdi + allocation.size], rax
	lea rsi, [rax + allocation.allocation]
	xor eax, eax
	mov [rdi + allocation.previous], rax
	mov [rdi + allocation.next], rax
	ret

.update:
	cmp qword[rdi + allocation.base], 0
	jz MapMemory
	test rsi, rsi
	jz .free
	add rsi, 15 - allocation.allocation
	and rsi, -16
	mov rax, [rdi + allocation.size]
	lea rdx, [rdi + allocation.allocation]
	cmp rsi, rax
	jz .restoresize
	jc .shrink
	cmp rsi, MAPPING_THRESHOLD
	jnc .move
	cmp rdx, [rel wLastAllocation]
	jnz .move
	mov ecx, esi
	sub ecx, eax
	sub ecx, [rel wAllocationRemainingSpace]
	ja .move
	mov [rel wAllocationRemainingSpace], ecx
	jmp .updated

.shrink:
	; only shrink the last allocation; everything else can stay as is
	xchg esi, eax
	cmp rdx, [rel wLastAllocation]
	jnz .updated
	sub esi, eax
	add [rel wAllocationRemainingSpace], esi
	mov esi, eax
.updated:
	mov [rdi + allocation.size], rsi
.restoresize:
	add esi, allocation.allocation
	ret

.move:
	add eax, allocation.allocation
	push rax
	push rdi
	add rsi, allocation.allocation
	xor edi, edi
	call .allocate
	mov ecx, [rsp + 8]
	shr ecx, 3
	mov [rsp + 8], rsi
	mov rbx, rdi
	mov rsi, [rsp]
	rep movsq
	pop rdi
	push rbx
	xor esi, esi
	call .free
	pop rdi
	pop rsi
	ret

.free:
	mov rax, [rdi + allocation.next]
	mov rdx, [rdi + allocation.previous]
	add rdi, allocation.allocation
	cmp rdi, [rel wLastAllocation]
	jnz .lastOK
	mov rcx, [rdi - allocation.allocation + allocation.size]
	add [rel wAllocationRemainingSpace], ecx
	mov [rel wLastAllocation], rdx
	test rdx, rdx
	jnz .lastOK
	mov [rel wCurrentAllocationMapping], rdx
	mov [rel wAllocationRemainingSpace], edx
.lastOK:
	test rax, rax
	jz .nonext
	mov [rax - allocation.allocation + allocation.previous], rdx
.nonext:
	test rdx, rdx
	jz .noprev
	mov [rdx - allocation.allocation + allocation.next], rax
.noprev:
	or rdx, rax
	mov rdi, [rdi - allocation.allocation + allocation.base]
	jz MapMemory
	xor edi, edi
	ret
