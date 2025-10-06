; DBRT --- debugger runtime
entry:	jmp	main
BITS 16

; cSpell:disable
excnCnt	equ	24

; provided by client code
extern	_Main

; provided by gdbstub.h
extern	_gdb_sys_init

section	.text.main
global	main
main:
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
	ret

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
	or	eax, [ebp+4+8];

	; Write IVT entry
	mov	edi, [ebp+4+4]
	shl	di, 2	; for some reason [es:di*4] fails to assemble
	mov	[es:di], eax

	; Restore ES value
	pop	es

	push	'H'
	call	putDebugChar16
	pop	ax
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

section .data
oldIVT	times excnCnt dd 0

global _small_code_
_small_code_	db	1

; segment stack class=stack
; 	resb 2048
