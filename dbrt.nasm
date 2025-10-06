; DBRT --- debugger runtime
BITS 16
entry:	jmp	_init_dbrt0

; cSpell:disable
excnCnt	equ	24

; provided by client code
extern	_Main

; provided by gdbstub.h
extern	_gdb_sys_init

section	code
global	_init_dbrt0
_init_dbrt0:
	; Dirty hack to fix linker's inability to relocate data reads
	mov	ax, ds
	mov	bx, 0x0010
	add	ax, bx
	; jc	segment_overflow ; TODO
	mov	ds, ax

	; We assume cs=ds=es=ss at the startup
	; Save existing IVT
	push	ds
	xor	ax, ax
	mov	ds, ax
	
	mov	cx, excnCnt
	mov	di, oldIVT
	mov	si, 0x00
	rep movsd

	pop	ds

	; Initialize serial port
	mov	ax, 0x0000 | 0b11100011
	mov	dx, 0
	int	0x14

	; COM2 for (f)printf
	mov	ax, 0x0000 | 0b11100011
	mov	dx, 1
	int	0x14

	; Setup debugger
	call	_gdb_sys_init
	int3

	; Main must preserve ds and es
	; call	Main

	; Restore original IVT
	push	es
	xor	ax, ax
	mov	es, ax

	mov	cx, excnCnt
	mov	si, oldIVT
	mov	di, 0x00
	rep movsd

	pop	es
	mov	ax, cs
	mov	ds, ax
	ret

; The caller pushes 16-bit handler address and 32-bit interrupt number on the stack.
; Note that an interrupt number must be a 8-bit integer, so we can ignore its higher bytes.
; [esp+8]	caller's stack frame
; [esp+6]	handler asddress	2 bytes
; [esp+2]	interrupt no.	4 byte
; [esp]	return address	2 bytes
global _gdb_x86_hook_idt
_gdb_x86_hook_idt:
	push	ebp
	mov	ebp, esp

	push	es
	xor	ax, ax
	mov	es, ax

	; Set EBX to <DS|handlerAddress> as required for an IVT entry
	mov	ax, ds
	shl	eax, 0x10
	or	ax, [ebp+4+6];

	; Write IVT entry
	mov	edi, [ebp+4+2]
	shl	di, 2	; for some reason [es:di*4] fails to assemble
	mov	[es:di], eax

	; Restore ES value
	pop	es

	; push	word 'H'
	; call	putDebugChar16
	; add	sp, 2

	xor	ax, ax
	pop	ebp
	ret

putDebugChar16:
	nop
	mov	eax, [esp+2]	
	mov	ah, 0x01
	xor	dx, dx
	int	0x14
	ret

section data
oldIVT	times excnCnt dd 0

global _small_code_
_small_code_	db	1

; segment stack class=stack
; 	resb 2048
