;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>	;
; File author: Mamadou DIOP (Doubango Telecom, France).					;
; License: GPLv3. For commercial license please contact us.				;
; Source code: https://github.com/DoubangoTelecom/compv					;
; WebSite: http://compv.org												;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "compv_common_x86.s"

COMPV_YASM_DEFAULT_REL

global sym(Convlt1_verthz_float32_minpack4_Asm_X86_SSE2)
global sym(Convlt1_verthz_fxpq16_minpack4_Asm_X86_SSE2)

section .data

section .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This function requires sizeof(float) = 4byte = 32bits
; arg(0) -> const uint8_t* in_ptr
; arg(1) -> uint8_t* out_ptr
; arg(2) -> compv_scalar_t width
; arg(3) -> compv_scalar_t height
; arg(4) -> compv_scalar_t stride
; arg(5) -> compv_scalar_t pad
; arg(6) -> const float* hkern_ptr
; arg(7) -> compv_scalar_t kern_size
; void Convlt1_verthz_float32_minpack4_Asm_X86_SSE2(const uint8_t* in_ptr, uint8_t* out_ptr, compv::compv_scalar_t width, compv::compv_scalar_t height, compv::compv_scalar_t stride, compv::compv_scalar_t pad, const float* hkern_ptr, compv::compv_scalar_t kern_size)
sym(Convlt1_verthz_float32_minpack4_Asm_X86_SSE2):
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 8
	COMPV_YASM_SAVE_XMM 7 ;XMM[6-7]
	push rsi
	push rdi
	push rbx
	;; end prolog ;;

	%define COMPV_SIZE_OF_FLOAT 4 ; up to the caller to make sure sizeof(float)=4
	%define i_tmp		rsp + 0
	%define i_xmmSF3	rsp + 8
	

	; align stack and alloc memory
	COMPV_YASM_ALIGN_STACK 16, rax
	sub rsp, 16*1 + 8*1
	; [rsp + 0] = compv_scalar_t tmp
	; [rsp + 8] = xmmSF3

	; i = rdi
	; xor rdi, rdi

	; rcx = col

	; rbx = out_ptr
	mov rbx, arg(1)

	; j = rsi = height
	mov rsi, arg(3)

	; xmm7 = xmmZero
	pxor xmm7, xmm7

	; arg(5) = pad += (width & 3)
	mov rdx, arg(2) ; width
	mov rax, arg(5) ; pad
	and rdx, 3
	add rax, rdx
	mov arg(5), rax

	; rax = in_ptr
	mov rax, arg(0)

	; rdx = hkern_ptr
	mov rdx, arg(6)
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; for (j = 0; j < height; ++j)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.LoopRows
		mov rdi, arg(2) ; i = width
		cmp rdi, 16
		jl .EndOfLoopColumns16
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; while (i > 15)
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		.LoopColumns16
			xorps xmm5, xmm5 ; xmm5 = xmmSF0
			xorps xmm6, xmm6 ; xmm6 = xmmSF1
			xorps xmm4, xmm4 ; xmm4 = xmmSF2
			movaps [i_xmmSF3], xmm7

			mov [i_tmp], rax ; save rax = in_ptr
			xor rcx, rcx ; col = 0
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			; for (col = 0; col < kern_size; ++col)
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			.LoopColumns16Kern16
				movdqu xmm0, [rax] ; xmm0 = xmmI0
				movss xmm1, [rdx + rcx*COMPV_SIZE_OF_FLOAT]
				movdqa xmm2, xmm0
				movdqa xmm3, xmm0
				shufps xmm1, xmm1, 0x0 ; xmm1 = xmmCoeff
				
				punpcklbw xmm2, xmm7
				punpcklbw xmm3, xmm7
				punpcklwd xmm2, xmm7
				punpckhwd xmm3, xmm7
				cvtdq2ps xmm2, xmm2
				cvtdq2ps xmm3, xmm3
				mulps xmm2, xmm1
				mulps xmm3, xmm1
				addps xmm5, xmm2
				addps xmm6, xmm3

				movdqa xmm3, xmm0
				punpckhbw xmm0, xmm7
				punpckhbw xmm3, xmm7
				punpckhwd xmm0, xmm7
				punpcklwd xmm3, xmm7
				cvtdq2ps xmm0, xmm0
				cvtdq2ps xmm3, xmm3
				mulps xmm0, xmm1
				mulps xmm3, xmm1
				addps xmm0, [i_xmmSF3]
				addps xmm4, xmm3
				movaps [i_xmmSF3], xmm0
				
				inc rcx
				add rax, arg(4) ; += stride
				cmp rcx, arg(7) ; ==? kern_size
				jl .LoopColumns16Kern16		

			mov rax, [i_tmp] ; restore rax
			cvtps2dq xmm5, xmm5
			cvtps2dq xmm6, xmm6
			cvtps2dq xmm4, xmm4
			cvtps2dq xmm3, [i_xmmSF3]
			packssdw xmm5, xmm6
			packssdw xmm4, xmm3
			packuswb xmm5, xmm4
			lea rax, [rax + 16] ; in_ptr += 16
			movdqu [rbx], xmm5
			lea rbx, [rbx + 16] ; out_ptr += 16

			sub rdi, 16 ; i -= 16
			cmp rdi, 16
			jge .LoopColumns16
			.EndOfLoopColumns16

		cmp rdi, 4
		jl .EndOfLoopColumns4
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; while (i > 3)
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		.LoopColumns4
			xorps xmm4, xmm4 ; xmm4 = xmmSF0

			mov [i_tmp], rax ; save rax = in_ptr
			xor rcx, rcx ; col = 0
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			; for (col = 0; col < kern_size; ++col)
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			.LoopColumns4Kern16
				movd xmm0, [rax] ; xmm0 = xmmI0
				movss xmm1, [rdx + rcx*COMPV_SIZE_OF_FLOAT]
				punpcklbw xmm0, xmm7
				shufps xmm1, xmm1, 0x0 ; xmm1 = xmmCoeff
				punpcklwd xmm0, xmm7
				cvtdq2ps xmm0, xmm0
				mulps xmm0, xmm1
				addps xmm4, xmm0

				inc rcx
				add rax, arg(4) ; += stride
				cmp rcx, arg(7) ; ==? kern_size
				jl .LoopColumns4Kern16

			mov rax, [i_tmp] ; restore rax
			cvtps2dq xmm4, xmm4
			packssdw xmm4, xmm4
			packuswb xmm4, xmm4
			movd [rbx], xmm4

			lea rbx, [rbx + 4] ; out_ptr += 4
			lea rax, [rax + 4] ; in_ptr += 4

			sub rdi, 4 ; i -= 4
			cmp rdi, 4
			jge .LoopColumns4
			.EndOfLoopColumns4
		
		add rbx, arg(5) ; out_ptr += pad
		add rax, arg(5) ; in_ptr += pad

		dec rsi ; --j
		test rsi, rsi
		jnz .LoopRows

	; unalign stack and free memory
	add rsp, 16*1 + 8*1
	COMPV_YASM_UNALIGN_STACK

	%undef COMPV_SIZE_OF_FLOAT
	%undef i_tmp
	%undef i_xmmSF3

	;; begin epilog ;;
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_RESTORE_XMM
	COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This function requires sizeof(float) = 4byte = 32bits
; arg(0) -> const uint8_t* in_ptr
; arg(1) -> uint8_t* out_ptr
; arg(2) -> compv_scalar_t width
; arg(3) -> compv_scalar_t height
; arg(4) -> compv_scalar_t stride
; arg(5) -> compv_scalar_t pad
; arg(6) -> const uint16_t* hkern_ptr
; arg(7) -> compv_scalar_t kern_size
; void Convlt1_verthz_fxpq16_minpack4_Asm_X86_SSE2(const uint8_t* in_ptr, uint8_t* out_ptr, compv::compv_scalar_t width, compv::compv_scalar_t height, compv::compv_scalar_t stride, compv::compv_scalar_t pad, const uint16_t* hkern_ptr, compv::compv_scalar_t kern_size)
sym(Convlt1_verthz_fxpq16_minpack4_Asm_X86_SSE2):
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 8
	push rsi
	push rdi
	push rbx
	;; end prolog ;;

	%define COMPV_SIZE_OF_INT16 2
	%define i_tmp		rsp + 0
	

	; alloc memory
	sub rsp, 8*1
	; [rsp + 0] = compv_scalar_t tmp

	; i = rdi
	; xor rdi, rdi

	; rcx = col

	; rbx = out_ptr
	mov rbx, arg(1)

	; j = rsi = height
	mov rsi, arg(3)

	; xmm6 = xmmZero
	pxor xmm6, xmm6

	; arg(5) = pad += (width & 3)
	mov rdx, arg(2) ; width
	mov rax, arg(5) ; pad
	and rdx, 3
	add rax, rdx
	mov arg(5), rax

	; rax = in_ptr
	mov rax, arg(0)

	; rdx = hkern_ptr
	mov rdx, arg(6)
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; for (j = 0; j < height; ++j)
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	.LoopRows
		mov rdi, arg(2) ; i = width
		cmp rdi, 16
		jl .EndOfLoopColumns16
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; while (i > 15)
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		.LoopColumns16
			pxor xmm4, xmm4 ; xmm4 = xmmS0
			pxor xmm5, xmm5 ; xmm5 = xmmS1

			mov [i_tmp], rax ; save rax = in_ptr
			xor rcx, rcx ; col = 0
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			; for (col = 0; col < kern_size; ++col)
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			.LoopColumns16Kern16
				movd xmm1, [rdx + rcx*COMPV_SIZE_OF_INT16]
				movdqu xmm0, [rax] ; xmm0 = xmmI0
				punpcklwd xmm1, xmm1			
				movdqa xmm2, xmm0
				pshufd xmm1, xmm1, 0 ; xmm1 = xmmCoeff
				punpcklbw xmm0, xmm6
				punpckhbw xmm2, xmm6
				pmulhuw xmm0, xmm1
				pmulhuw xmm2, xmm1
				paddw xmm4, xmm0
				paddw xmm5, xmm2
				
				inc rcx
				add rax, arg(4) ; += stride
				cmp rcx, arg(7) ; ==? kern_size
				jl .LoopColumns16Kern16		
			
			packuswb xmm4, xmm5
			mov rax, [i_tmp] ; restore rax
			lea rax, [rax + 16] ; in_ptr += 16
			movdqu [rbx], xmm4
			lea rbx, [rbx + 16] ; out_ptr += 16

			sub rdi, 16 ; i -= 16
			cmp rdi, 16
			jge .LoopColumns16
			.EndOfLoopColumns16

		cmp rdi, 4
		jl .EndOfLoopColumns4
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; while (i > 3)
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		.LoopColumns4
			pxor xmm4, xmm4 ; xmm4 = xmmS0

			mov [i_tmp], rax ; save rax = in_ptr
			xor rcx, rcx ; col = 0
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			; for (col = 0; col < kern_size; ++col)
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			.LoopColumns4Kern16
				movd xmm1, [rdx + rcx*COMPV_SIZE_OF_INT16]
				movdqu xmm0, [rax] ; xmm0 = xmmI0
				punpcklwd xmm1, xmm1
				punpcklbw xmm0, xmm6		
				pshufd xmm1, xmm1, 0 ; xmm1 = xmmCoeff				
				pmulhuw xmm0, xmm1
				paddw xmm4, xmm0

				inc rcx
				add rax, arg(4) ; += stride
				cmp rcx, arg(7) ; ==? kern_size
				jl .LoopColumns4Kern16

			packuswb xmm4, xmm4
			mov rax, [i_tmp] ; restore rax
			movd [rbx], xmm4

			lea rbx, [rbx + 4] ; out_ptr += 4
			lea rax, [rax + 4] ; in_ptr += 4

			sub rdi, 4 ; i -= 4
			cmp rdi, 4
			jge .LoopColumns4
			.EndOfLoopColumns4
		
		add rbx, arg(5) ; out_ptr += pad
		add rax, arg(5) ; in_ptr += pad

		dec rsi ; --j
		test rsi, rsi
		jnz .LoopRows

	; free memory
	add rsp, 8*1

	%undef COMPV_SIZE_OF_INT16
	%undef i_tmp

	;; begin epilog ;;
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	ret