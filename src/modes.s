	section .rodata align=16
ModeHandlers:
	; all called with rdi = argument count, rsi = argument array (after skipping), rdx = program name (or null)
	; returning exit status in edi
	dq "script",   ScriptMode
	dq "1a",       Prob1a
	dq "1b",       Prob1b
	dq "2a",       Prob2a
	dq "2b",       Prob2b
	dq "3a",       Prob3a
	dq "3b",       Prob3b
	dq "4a",       Prob4a
	dq "4b",       Prob4b
	dq "5a",       Prob5a
	dq "5b",       Prob5b
	dq "6a",       Prob6a
	dq "6b",       Prob6b
	dq "7a",       Prob7a
	dq "7b",       Prob7b
	dq "8a",       Prob8a
	dq "8b",       Prob8b
	dq "9a",       Prob9a
	dq "9b",       Prob9b
	dq "10a",      Prob10a
	dq "10b",      Prob10b
	dq "11a",      Prob11a
	dq "11b",      Prob11b
	dq "12a",      Prob12a
	dq "12b",      Prob12b
	dq "13a",      Prob13a
	dq "13b",      Prob13b
	dq "14a",      Prob14a
	dq "14b",      Prob14b
	dq "testcat",  TestCat
	dq "testmap",  TestMap
	dq "testmem",  TestMemory
	dq "showaddr", ShowAddresses
	dq 0,          InvalidModeHandler
