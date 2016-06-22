;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>	;
; File author: Mamadou DIOP (Doubango Telecom, France).					;
; License: GPLv3. For commercial license please contact us.				;
; Source code: https://github.com/DoubangoTelecom/compv					;
; WebSite: http://compv.org												;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "../compv_common_x86.s"

%if COMPV_YASM_ABI_IS_64BIT

COMPV_YASM_DEFAULT_REL

global sym(MathStatsMSE2DHomogeneous_float64_Asm_X64_SSE2)

section .data
	extern sym(k1_f64)

section .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> const COMPV_ALIGNED(SSE) compv_float64_t* aX_h
; arg(1) -> const COMPV_ALIGNED(SSE) compv_float64_t* aY_h
; arg(2) -> const COMPV_ALIGNED(SSE) compv_float64_t* aZ_h
; arg(3) -> const COMPV_ALIGNED(SSE) compv_float64_t* bX
; arg(4) -> const COMPV_ALIGNED(SSE) compv_float64_t* bY
; arg(5) -> COMPV_ALIGNED(SSE) compv_float64_t* mse
; arg(6) -> compv_uscalar_t numPoints
; void MathStatsMSE2DHomogeneous_float64_Asm_X64_SSE2(const COMPV_ALIGNED(SSE) compv_float64_t* aX_h, const COMPV_ALIGNED(SSE) compv_float64_t* aY_h, const COMPV_ALIGNED(SSE) compv_float64_t* aZ_h, const COMPV_ALIGNED(SSE) compv_float64_t* bX, const COMPV_ALIGNED(SSE) compv_float64_t* bY, COMPV_ALIGNED(SSE) compv_float64_t* mse, compv_uscalar_t numPoints)
sym(MathStatsMSE2DHomogeneous_float64_Asm_X64_SSE2):
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 7
	COMPV_YASM_SAVE_XMM 10
	push rsi
	push rdi
	push rbx
	;; end prolog ;;

	movapd xmm10, [sym(k1_f64)] ; xmm7 = xmmOne
	xor rcx, rcx ; rcx = i
	mov rsi, arg(0) ; aX_h
	mov rdi, arg(1) ; aY_h
	mov rax, arg(2) ; aZ_h
	mov rbx, arg(3) ; bX
	mov rdx, arg(4) ; bY
	mov r8, arg(5) ; mse
	mov r9, arg(6) ; r9 = numPoints
	lea r10, [r9 - 3] ; r10 = (numPoints - 3)
	lea r11, [r9 - 1] ; r11 = (numPoints - 1)

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; for (i = 0; i < numPointsSigned - 3; i += 4)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	cmp rcx, r10
	jge .EndOfLoop4
	.Loop4
		movapd xmm0, xmm10
		movapd xmm1, xmm10
		divpd xmm0, [rax + rcx*8]
		divpd xmm1, [rax + rcx*8 + 2*8]
		movapd xmm2, [rsi + rcx*8]
		movapd xmm3, [rbx + rcx*8]
		movapd xmm4, [rsi + rcx*8 + 2*8]
		movapd xmm5, [rbx + rcx*8 + 2*8]
		movapd xmm6, [rdi + rcx*8]
		movapd xmm7, [rdx + rcx*8]
		movapd xmm8, [rdi + rcx*8 + 2*8]
		movapd xmm9, [rdx + rcx*8 + 2*8]
		lea rcx, [rcx + 4]
		mulpd xmm2, xmm0
		mulpd xmm4, xmm1
		mulpd xmm6, xmm0
		mulpd xmm8, xmm1
		subpd xmm2, xmm3
		subpd xmm4, xmm5
		subpd xmm6, xmm7
		subpd xmm8, xmm9
		mulpd xmm2, xmm2
		mulpd xmm6, xmm6
		mulpd xmm4, xmm4
		mulpd xmm8, xmm8
		addpd xmm2, xmm6
		addpd xmm4, xmm8
		movapd [r8 + rcx*8 - 4*8], xmm2
		movapd [r8 + rcx*8 + 2*8 - 4*8], xmm4
		cmp rcx, r10
		jl .Loop4
	.EndOfLoop4

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; if (i < numPointsSigned - 1)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	cmp rcx, r11
	jge .EndOfMoreThanTwoRemains
	.MoreThanTwoRemains
		movapd xmm0, xmm10
		divpd xmm0, [rax + rcx*8]
		movapd xmm1, [rsi + rcx*8]
		movapd xmm2, [rdi + rcx*8]
		mulpd xmm1, xmm0
		mulpd xmm2, xmm0
		subpd xmm1, [rbx + rcx*8]
		subpd xmm2, [rdx + rcx*8]
		mulpd xmm1, xmm1
		mulpd xmm2, xmm2
		addpd xmm1, xmm2
		movapd [r8 + rcx*8], xmm1
		lea rcx, [rcx + 2]
	.EndOfMoreThanTwoRemains

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; if (numPointsSigned & 1)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	cmp rcx, arg(6)
	jge .EndOfMoreThanOneRemains
	.MoreThanOneRemains
		divsd xmm10, [rax + rcx*8]
		movsd xmm1, [rsi + rcx*8]
		movsd xmm2, [rdi + rcx*8]
		mulsd xmm1, xmm10
		mulsd xmm2, xmm10
		subsd xmm1, [rbx + rcx*8]
		subsd xmm2, [rdx + rcx*8]
		mulsd xmm1, xmm1
		mulsd xmm2, xmm2
		addsd xmm1, xmm2
		movsd [r8 + rcx*8], xmm1
	.EndOfMoreThanOneRemains

	;; begin epilog ;;
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_RESTORE_XMM
	COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	ret

%endif ; COMPV_YASM_ABI_IS_64BIT



