struc direntry
	.name:     resq 1
	.size:     resq 1 ; for directories: ~child count
	.parent:   resq 1
	.entries:  resq 1 ; array of entries
	.namebuf:  resq 1 ; buffer for child filenames
	.entrysize:
endstruc

	absolute wModeData

wCurrentCallback:
wCurrentDirectory: resq 1
wRootDirectory: resb direntry.entrysize

wTotalComputedDirectorySize:
wCurrentEntryCount: resq 1
wCandidateDirectorySize:
wCurrentEntryBuffer: resq 1
wCurrentEntryBufferSize: resq 1

	assert $ <= wModeData.end

	section .text
Prob7a:
	endbr64
	call BuildFilesystemTree
	mov qword[rel wTotalComputedDirectorySize], 0
	lea rbx, [rel .callback]
	call ProcessFilesystemTree
	mov rax, [rel wTotalComputedDirectorySize]
	call PrintNumber
	jmp DestroyFilesystemTree

.callback:
	endbr64
	cmp rax, 100000
	ja .done
	add [rel wTotalComputedDirectorySize], rax
.done:
	ret

Prob7b:
	endbr64
	call BuildFilesystemTree
	lea rbx, [rel DummyCallback]
	call ProcessFilesystemTree
	sub rax, 40000000
	jc InvalidInputError
	mov [rel wTotalComputedDirectorySize], rax
	mov qword[rel wCandidateDirectorySize], -1
	lea rbx, [rel .callback]
	call ProcessFilesystemTree
	mov rax, [rel wCandidateDirectorySize]
	cmp rax, -1
	jz InvalidInputError
	call PrintNumber
	jmp DestroyFilesystemTree

.callback:
	endbr64
	cmp rax, [rel wTotalComputedDirectorySize]
	jc .done
	cmp rax, [rel wCandidateDirectorySize]
	jnc .done
	mov [rel wCandidateDirectorySize], rax
.done:
	ret

ProcessFilesystemTree:
	; callback must preserve rax!
	mov [rel wCurrentCallback], rbx
	lea rbx, [rel wRootDirectory]
.compute:
	mov rcx, [rbx + direntry.size]
	not rcx
	mov rbx, [rbx + direntry.entries]
	xor edx, edx
.loop:
	mov rax, [rbx + direntry.size]
	test rax, rax
	jns .notdir
	push rcx
	push rdx
	push rbx
	call .compute
	pop rbx
	pop rdx
	pop rcx
.notdir:
	add rdx, rax
	add rbx, direntry.entrysize
	dec rcx
	jnz .loop
	mov rax, rdx
	jmp [rel wCurrentCallback]
	
BuildFilesystemTree:
	lea rdi, [rel wRootDirectory]
	mov [rel wCurrentDirectory], rdi
	xor eax, eax
	mov ecx, direntry.entrysize / 8
	rep stosq
	mov qword[rdi - direntry.entrysize + direntry.size], -1
.loop:
	call ReadInputLine
	jc .done
	test rdi, rdi
	jz .loop
.nextline:
	cmp word[rsi], "$ "
	jnz InvalidInputError
	cmp dword[rsi + 1], " ls"
	jz .listentries
	cmp dword[rsi + 1], " cd "
	jnz InvalidInputError
	cmp word[rsi + 5], "/"
	jz .root
	cmp dword[rsi + 4], " .."
	jz .up
	add rsi, 5
	mov rbx, [rel wCurrentDirectory]
	mov rdx, [rbx + direntry.size]
	not rdx
	test rdx, rdx
	jz .notfound
	mov rbx, [rbx + direntry.entries]
.search:
	mov rdi, [rbx + direntry.name]
	call CompareStrings
	jz .found
	add rbx, direntry.entrysize
	dec rdx
	jnz .search
.notfound:
	lea rsi, [rel .notfoundmessage]
	jmp ErrorExit

.found:
	mov rax, [rbx + direntry.size]
	test rax, rax
	jns .notfound
	mov [rel wCurrentDirectory], rbx
	jmp .loop

.up:
	mov rax, [rel wCurrentDirectory]
	mov rax, [rax + direntry.parent]
	test rax, rax
	jz InvalidInputError
	mov [rel wCurrentDirectory], rax
	jmp .loop

.root:
	lea rax, [rel wRootDirectory]
	mov [rel wCurrentDirectory], rax
	jmp .loop

.listentries:
	mov rsi, [rel wCurrentDirectory]
	cmp qword[rsi + direntry.size], 0
	jge InvalidInputError
	cmp qword[rsi + direntry.namebuf], 0
	lea rsi, [rel .multiplemessage]
	jnz ErrorExit
	xor eax, eax
	assert wCurrentEntryBuffer == wCurrentEntryCount + 8
	assert wCurrentEntryBufferSize == wCurrentEntryCount + 16
	lea rdi, [rel wCurrentEntryCount]
	mov ecx, 3
	rep stosq
.readentryloop:
	call ReadInputLine
	jc .entryEOF
	test rdi, rdi
	jz .readentryloop
	cmp word[rsi], "$ "
	jz .entrydone
	inc rdi
	push rsi
	push rdi
	inc qword[rel wCurrentEntryCount]
	add rdi, [rel wCurrentEntryBufferSize]
	mov rsi, rdi
	mov rdi, [rel wCurrentEntryBuffer]
	call AllocateMemory
	mov [rel wCurrentEntryBuffer], rdi
	add rdi, [rel wCurrentEntryBufferSize]
	pop rcx
	add [rel wCurrentEntryBufferSize], rcx
	pop rsi
	rep movsb
	jmp .readentryloop

.entryEOF:
	xor esi, esi
.entrydone:
	push rsi
	mov rsi, [rel wCurrentEntryCount]
	test rsi, rsi
	jz .noentries
	assert direntry.entrysize == 40
	shl rsi, 3
	lea rsi, [rsi * 5]
	xor edi, edi
	call AllocateMemory
	mov rbx, [rel wCurrentDirectory]
	mov [rbx + direntry.entries], rdi
	mov rsi, [rel wCurrentEntryBuffer]
	mov [rbx + direntry.namebuf], rsi
	mov rdx, [rel wCurrentEntryCount]
	mov rcx, rdx
	not rdx
	mov [rbx + direntry.size], rdx
.entryloop:
	mov rax, [rel wCurrentDirectory]
	mov [rdi + direntry.parent], rax
	xor eax, eax
	mov [rdi + direntry.entries], rax
	mov [rdi + direntry.namebuf], rax
	push rcx
	push rdi
	dec rax
	lea rdx, [rsi + 3]
	cmp dword[rsi], "dir "
	cmovz rsi, rdx
	jz .gotsize
	call ParseNumber
	jc InvalidInputError
	mov rax, rdi
	mov rdi, [rsp]
.gotsize:
	mov [rdi + direntry.size], rax
	call SkipSpaces
	mov rdi, [rsp]
	mov [rdi + direntry.name], rsi
	mov rdi, rsi
	xor eax, eax
	repnz scasb
	mov rsi, rdi
	pop rdi
	pop rcx
	add rdi, direntry.entrysize
	dec rcx
	jnz .entryloop
.noentries:
	pop rsi
	test rsi, rsi
	jnz .nextline
.done:
	ret

.notfoundmessage: db `error: directory not found\n`, 0
.multiplemessage: db `error: directory listed multiple times\n`, 0

DestroyFilesystemTree:
	; exits with rdi = 0
	lea rbx, [rel wRootDirectory]
.destroy:
	mov rcx, [rbx + direntry.size]
	not rcx
	test rcx, rcx
	jz .skip
	push rbx
	push rcx
	push qword[rbx + direntry.entries]
.loop:
	mov rbx, [rsp]
	mov rax, [rbx + direntry.size]
	test rax, rax
	jns .notdir
	call .destroy
.notdir:
	add qword[rsp], direntry.entrysize
	dec qword[rsp + 8]
	jnz .loop
	add rsp, 16
	pop rbx
.skip:
	push qword[rbx + direntry.namebuf]
	mov rdi, [rbx + direntry.entries]
	xor esi, esi
	call AllocateMemory
	pop rdi
	jmp AllocateMemory
