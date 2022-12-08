%imacro assert 1-2 "assertion failed"
	%ifn %1
		%error %2
	%endif
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
	%pop section
%endmacro

%assign READ_BUFFER_SIZE 0x4000

; Linux x64 syscall IDs
%assign read         0
%assign write        1
%assign mmap         9
%assign munmap      11
%assign mremap      25
%assign exit_group 231

; errno values
%assign EINTR 4
