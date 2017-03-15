;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>   ;
; File author: Mamadou DIOP (Doubango Telecom, France).                 ;
; License: GPLv3. For commercial license please contact us.             ;
; Source code: https://github.com/DoubangoTelecom/compv                 ;
; WebSite: http://compv.org                                             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "compv_common_x86.s"

%if COMPV_YASM_ABI_IS_64BIT

COMPV_YASM_DEFAULT_REL

global sym(CompVMathUtilsSum_8u32u_Asm_X64_SSE2)

section .data
	

section .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> COMPV_ALIGNED(SSE) const uint8_t* data
; arg(1) -> compv_uscalar_t width
; arg(2) -> compv_uscalar_t height
; arg(3) -> COMPV_ALIGNED(SSE) compv_uscalar_t stride
; arg(4) -> uint32_t *sum1
sym(CompVMathUtilsSum_8u32u_Asm_X64_SSE2)
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 5
	COMPV_YASM_SAVE_XMM 11
	;; end prolog ;;

	; align stack and alloc memory
	COMPV_YASM_ALIGN_STACK 16, rax
	sub rsp, (4*COMPV_YASM_UINT32_SZ_BYTES)

	%define data				rax
	%define width				rcx
	%define height				rdx
	%define widthMinus15	r8
	%define i					r9
	%define widthMinus63		r10
	%define stride				r11
	%define vecZero				xmm8
	%define vecOrphansSuppress	xmm9
	%define vecSumh				xmm10
	%define vecSuml				xmm11

	;; setting orphans ;;
	mov rax, arg(1) ; width
	and rax, 15
	jz .OrphansIsZero
		pcmpeqw xmm0, xmm0
		movdqa [rsp + 0], xmm0
		shl rax, 3
		mov rcx, 16*8
		sub rcx, rax
		xor rdi, rdi
		%assign index 0
		%rep 4
			test rcx, rcx
			js .OrphansCopied
			mov rax, 0xffffffff
			shr rax, cl
			cmp rcx, 31
			cmovg rax, rdi ; rdi = 0
			mov [rsp + 0 + (3-index)*COMPV_YASM_UINT32_SZ_BYTES], dword eax
			sub rcx, 32
			%assign index index+1
		%endrep
		.OrphansCopied:
			movdqa vecOrphansSuppress, [rsp + 0]
		.OrphansIsZero:

	mov data, arg(0)
	mov width, arg(1)
	mov height, arg(2)
	mov stride, arg(3)
	lea widthMinus63, [width - 63]
	lea widthMinus15, [width - 15]
	
	pxor vecSumh, vecSumh
	pxor vecSuml, vecSuml
	pxor vecZero, vecZero

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; for (compv_uscalar_t j = 0; j < height; ++j)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.LoopHeight:
		xor i, i
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; for (i = 0; i < widthSigned - 63; i += 64)
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		test widthMinus63, widthMinus63
		jle .EndOf_LoopWidth64
		.LoopWidth64:
			movdqa xmm0, [data + (i + 0)*COMPV_YASM_UINT8_SZ_BYTES]
			movdqa xmm1, [data + (i + 16)*COMPV_YASM_UINT8_SZ_BYTES]
			movdqa xmm2, [data + (i + 32)*COMPV_YASM_UINT8_SZ_BYTES]
			movdqa xmm3, [data + (i + 48)*COMPV_YASM_UINT8_SZ_BYTES]
			movdqa xmm4, xmm0
			movdqa xmm5, xmm1
			movdqa xmm6, xmm2
			movdqa xmm7, xmm3

			punpcklbw xmm0, vecZero
			punpckhbw xmm4, vecZero
			punpcklbw xmm1, vecZero
			punpckhbw xmm5, vecZero
			punpcklbw xmm2, vecZero
			punpckhbw xmm6, vecZero
			punpcklbw xmm3, vecZero
			punpckhbw xmm7, vecZero
			paddw xmm0, xmm4
			paddw xmm1, xmm5
			paddw xmm2, xmm6
			paddw xmm3, xmm7
			paddw xmm0, xmm1
			paddw xmm2, xmm3
			add i, 64
			paddw xmm0, xmm2
			movdqa xmm1, xmm0
			cmp i, widthMinus63
			punpcklwd xmm0, vecZero
			punpckhwd xmm1, vecZero
			paddd vecSuml, xmm0
			paddd vecSumh, xmm1
			jl .LoopWidth64
			.EndOf_LoopWidth64:
			;; EndOf_LoopWidth64 ;;

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; for (; i < widthSigned - 15; i += 16)
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		cmp i, widthMinus15
		jge .EndOf_LoopWidth16
		.LoopWidth16:
			movdqa xmm0, [data + (i + 0)*COMPV_YASM_UINT8_SZ_BYTES]
			movdqa xmm1, xmm0
			punpcklbw xmm0, vecZero
			punpckhbw xmm1, vecZero
			paddw xmm0, xmm1
			add i, 16
			movdqa xmm1, xmm0
			punpcklwd xmm0, vecZero
			punpckhwd xmm1, vecZero
			cmp i, widthMinus15
			paddd vecSuml, xmm0
			paddd vecSumh, xmm1
			jl .LoopWidth16
			.EndOf_LoopWidth16:
			;; EndOf_LoopWidth16 ;;
		
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; if (orphans)
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		test width, 15
		jz .NoOrphans
			movdqa xmm0, [data + (i + 0)*COMPV_YASM_UINT8_SZ_BYTES]
			pand xmm0, vecOrphansSuppress
			movdqa xmm1, xmm0
			punpcklbw xmm0, vecZero
			punpckhbw xmm1, vecZero
			paddw xmm0, xmm1
			movdqa xmm1, xmm0
			punpcklwd xmm0, vecZero
			punpckhwd xmm1, vecZero
			paddd vecSuml, xmm0
			paddd vecSumh, xmm1
			.NoOrphans:

		
		dec height
		lea data, [data + stride]
		jnz .LoopHeight
		;; EndOf_LoopHeight ;;


	paddd vecSuml, vecSumh
	movdqa xmm0, vecSuml
	psrldq xmm0, 8
	paddd vecSuml, xmm0
	movdqa xmm1, vecSuml
	psrldq xmm1, 4
	paddd vecSuml, xmm1

	mov rax, arg(4) ; sum1
	movd edx, vecSuml
	mov [rax], dword edx

	%undef data
	%undef width
	%undef height
	%undef stride
	%undef i
	%undef widthMinus63
	%undef widthMinus15
	%undef vecZero
	%undef vecSumh
	%undef vecSuml
	%undef vecOrphansSuppress

	; free memory and unalign stack
	add rsp, (4*COMPV_YASM_UINT32_SZ_BYTES)
	COMPV_YASM_UNALIGN_STACK

	;; begin epilog ;;
	COMPV_YASM_RESTORE_XMM
	COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	ret


%endif ; COMPV_YASM_ABI_IS_64BIT