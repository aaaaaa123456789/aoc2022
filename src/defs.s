%imacro assert 1-2 "assertion failed"
	%ifn %1
		%error %2
	%endif
%endmacro

%imacro message 1+
	db %1
	db `\n`, 0
%endmacro

%imacro withend 1+
	%defstr %%label %00
	%substr %%sb %%label 1
	%deftok %%firstchar %%sb
	%substr %%sb %%label 2,-1
	%deftok %%remainder %%sb
	%ifidn %[%%firstchar],.
		%define %%endlabel .end_%[%%remainder]
	%else
		%define %%endlabel .end
	%endif
%00:
	%1
%[%%endlabel]:
%endmacro

%imacro pushsection 1+
	%push section
	%xdefine %$section __?SECT?__
	section %1
%endmacro

%imacro popsection 0
	%$section
	%xdefine __?SECT?__ %$section
	%pop section
%endmacro

%assign READ_BUFFER_SIZE         0x4000
%assign MAPPING_ALIGNMENT        0x1000
%assign MAPPING_THRESHOLD        0x1800
%assign ALLOCATION_BUFFER_SIZE  0x10000

; Linux x64 syscall IDs
%assign read         0
%assign write        1
%assign open         2
%assign close        3
%assign mmap         9
%assign mprotect    10
%assign munmap      11
%assign mremap      25
%assign getpid      39
%assign fcntl       72
%assign exit_group 231

; errno values
%assign EINTR 4
%assign EBADF 9

; other kernel API constants
%assign F_GETFD              1
%assign MAP_PRIVATE          2
%assign MAP_FIXED         0x10
%assign MAP_ANONYMOUS     0x20
%assign MAP_LOCKED      0x2000
%assign MREMAP_MAYMOVE       1
%assign O_RDONLY             0
%assign PROT_READ            1
%assign PROT_WRITE           2

	section .text align=4096
	section .rodata align=16
	section .bss align=4096
