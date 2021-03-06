;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>	;
; File author: Mamadou DIOP (Doubango Telecom, France).					;
; License: GPLv3. For commercial license please contact us.				;
; Source code: https://github.com/DoubangoTelecom/compv					;
; WebSite: http://compv.org												;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "../../compv_common_x86.s"
%include "compv_imageconv_macros_x86_avx.s"

COMPV_YASM_DEFAULT_REL

global sym(rgbaToI420Kernel11_CompY_Asm_X86_Aligned0_AVX2)
global sym(rgbaToI420Kernel11_CompY_Asm_X86_Aligned1_AVX2)
global sym(rgbaToI420Kernel41_CompY_Asm_X86_Aligned00_AVX2)
global sym(rgbaToI420Kernel41_CompY_Asm_X86_Aligned01_AVX2)
global sym(rgbaToI420Kernel41_CompY_Asm_X86_Aligned10_AVX2)
global sym(rgbaToI420Kernel41_CompY_Asm_X86_Aligned11_AVX2)

global sym(rgbaToI420Kernel11_CompUV_Asm_X86_Aligned0xx_AVX2)
global sym(rgbaToI420Kernel11_CompUV_Asm_X86_Aligned1xx_AVX2)
global sym(rgbaToI420Kernel41_CompUV_Asm_X86_Aligned000_AVX2)
global sym(rgbaToI420Kernel41_CompUV_Asm_X86_Aligned100_AVX2)
global sym(rgbaToI420Kernel41_CompUV_Asm_X86_Aligned110_AVX2)
global sym(rgbaToI420Kernel41_CompUV_Asm_X86_Aligned111_AVX2)

global sym(rgbToI420Kernel31_CompY_Asm_X86_Aligned00_AVX2)
global sym(rgbToI420Kernel31_CompY_Asm_X86_Aligned01_AVX2)
global sym(rgbToI420Kernel31_CompY_Asm_X86_Aligned10_AVX2)
global sym(rgbToI420Kernel31_CompY_Asm_X86_Aligned11_AVX2)

global sym(rgbToI420Kernel31_CompUV_Asm_X86_Aligned000_AVX2)
global sym(rgbToI420Kernel31_CompUV_Asm_X86_Aligned100_AVX2)
global sym(rgbToI420Kernel31_CompUV_Asm_X86_Aligned110_AVX2)
global sym(rgbToI420Kernel31_CompUV_Asm_X86_Aligned111_AVX2)

global sym(i420ToRGBAKernel11_Asm_X86_Aligned00_AVX2)
global sym(i420ToRGBAKernel11_Asm_X86_Aligned01_AVX2)
global sym(i420ToRGBAKernel11_Asm_X86_Aligned10_AVX2)
global sym(i420ToRGBAKernel11_Asm_X86_Aligned11_AVX2)

section .data
	extern sym(k_0_0_0_255_u8)
	extern sym(k5_i8)
	extern sym(k16_i16)
	extern sym(k16_i8)
	extern sym(k128_i16)
	extern sym(k255_i16)
	extern sym(k7120_i16)
	extern sym(k8912_i16)
	extern sym(k4400_i16)
	extern sym(kRGBAToYUV_YCoeffs8)
	extern sym(kRGBAToYUV_UCoeffs8)
	extern sym(kRGBAToYUV_VCoeffs8)
	extern sym(kRGBAToYUV_U2V2Coeffs8)
	extern sym(kRGBAToYUV_U4V4Coeffs8)
	extern sym(kYUVToRGBA_RCoeffs8)
	extern sym(kYUVToRGBA_GCoeffs8)
	extern sym(kYUVToRGBA_BCoeffs8)
	extern sym(kAVXMaskstore_0_u64)
	extern sym(kAVXMaskstore_0_1_u64)
	extern sym(kAVXMaskstore_0_u32)
	extern sym(kAVXPermutevar8x32_AEBFCGDH_i32)
	extern sym(kAVXPermutevar8x32_ABCDDEFG_i32)
	extern sym(kAVXPermutevar8x32_CDEFFGHX_i32)
	extern sym(kAVXPermutevar8x32_XXABBCDE_i32)
	extern sym(kShuffleEpi8_RgbToRgba_i32)

section .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> const uint8_t* rgbaPtr
; arg(1) -> uint8_t* outYPtr
; arg(2) -> compv_scalar_t height
; arg(3) -> compv_scalar_t width
; arg(4) -> compv_scalar_t stride
; arg(5) -> COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_YCoeffs8
; %1 -> 1: rgbaPtr is aligned, 0: rgbaPtr isn't aligned
%macro rgbaToI420Kernel11_CompY_Asm_AVX2 1
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 6
	push rsi
	push rdi
	push rbx
	; end prolog

	mov rax, arg(3)
	add rax, 7
	and rax, -8
	mov rcx, arg(4)
	sub rcx, rax ; rcx = padY
	mov rdx, rcx
	shl rdx, 2 ; rdx = padRGBA

	vzeroupper

	mov rax, arg(5)
	vmovdqa ymm0, [rax] ; ymmYCoeffs
	vmovdqa ymm1, [sym(k16_i16)] ; ymm16
	vmovdqa ymm3, [sym(kAVXMaskstore_0_u64)] ; ymmMaskToExtractFirst64Bits

	mov rax, arg(0) ; rgbaPtr
	mov rsi, arg(2) ; height
	mov rbx, arg(1) ; outYPtr

	.LoopHeight:
		xor rdi, rdi
		.LoopWidth:
			%if %1 == 1
			vmovdqa ymm2, [rax] ; 8 RGBA samples
			%else
			vmovdqu ymm2, [rax] ; 8 RGBA samples
			%endif
			vpmaddubsw ymm2, ymm0
			vphaddw ymm2, ymm2 ; aaaabbbbaaaabbbb
			vpermq ymm2, ymm2, 0xD8 ; aaaaaaaabbbbbbbb
			vpsraw ymm2, 7
			vpaddw ymm2, ymm1
			vpackuswb ymm2, ymm2
			vpmaskmovq [rbx], ymm3, ymm2
			
			add rbx, 8
			add rax, 32

			; end-of-LoopWidth
			add rdi, 8
			cmp rdi, arg(3)
			jl .LoopWidth
	add rbx, rcx
	add rax, rdx
	; end-of-LoopHeight
	sub rsi, 1
	cmp rsi, 0
	jg .LoopHeight

	; begin epilog
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	vzeroupper
	ret
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel11_CompY_Asm_X86_Aligned0_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbaPtr, uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_YCoeffs8)
sym(rgbaToI420Kernel11_CompY_Asm_X86_Aligned0_AVX2):
	rgbaToI420Kernel11_CompY_Asm_AVX2 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel11_CompY_Asm_X86_Aligned_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbaPtr, uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_YCoeffs8)
sym(rgbaToI420Kernel11_CompY_Asm_X86_Aligned1_AVX2):
	rgbaToI420Kernel11_CompY_Asm_AVX2 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> const uint8_t* rgbaPtr
; arg(1) -> uint8_t* outYPtr
; arg(2) -> compv_scalar_t height
; arg(3) -> compv_scalar_t width
; arg(4) -> compv_scalar_t stride
; arg(5) -> COMPV_ALIGNED(AVX2) const int8_t* kXXXXToYUV_YCoeffs
; %1 -> 1: rgbaPtr aligned, 0: rgbaPtr isn't aligned
; %2 -> 1: outYPtr aligned, 0: outYPtr isn't aligned
%macro rgbaToI420Kernel41_CompY_Asm_AVX2 2
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 6
	push rsi
	push rdi
	push rbx
	; end prolog

	mov rax, arg(3)
	add rax, 31
	and rax, -32
	mov rcx, arg(4)
	sub rcx, rax ; rcx = padY
	mov rdx, rcx
	shl rdx, 2 ; rdx = padRGBA

	vzeroupper

	mov rax, arg(5)
	vmovdqa ymm0, [rax] ; ymmYCoeffs
	vmovdqa ymm1, [sym(k16_i16)] ; ymm16
	vmovdqa ymm6, [sym(kAVXPermutevar8x32_AEBFCGDH_i32)] ; ymmAEBFCGDH

	mov rax, arg(0) ; rgbaPtr
	mov rsi, arg(2) ; height
	mov rbx, arg(1) ; outYPtr

	.LoopHeight:
		xor rdi, rdi
		.LoopWidth:
			%if %1 == 1
			vmovdqa ymm2, [rax] ; 8 RGBA samples
			vmovdqa ymm3, [rax + 32] ; 8 RGBA samples	
			vmovdqa ymm4, [rax + 64] ; 8 RGBA samples	
			vmovdqa ymm5, [rax + 96] ; 8 RGBA samples
			%else
			vmovdqu ymm2, [rax] ; 8 RGBA samples
			vmovdqu ymm3, [rax + 32] ; 8 RGBA samples	
			vmovdqu ymm4, [rax + 64] ; 8 RGBA samples	
			vmovdqu ymm5, [rax + 96] ; 8 RGBA samples
			%endif

			vpmaddubsw ymm2, ymm0
			vpmaddubsw ymm3, ymm0
			vpmaddubsw ymm4, ymm0
			vpmaddubsw ymm5, ymm0

			vphaddw ymm2, ymm3 ; hadd(ABCD) -> ACBD
			vphaddw ymm4, ymm5 ; hadd(EFGH) -> EGFH

			vpsraw ymm2, 7 ; >> 7
			vpsraw ymm4, 7 ; >> 7

			vpaddw ymm2, ymm1 ; + 16
			vpaddw ymm4, ymm1 ; + 16

			vpackuswb ymm2, ymm4 ; Saturate(I16 -> U8): packus(ACBD, EGFH) -> AEBFCGDH

			; Final permute
			vpermd ymm2, ymm6, ymm2

			%if %2 == 1
			vmovdqa [rbx], ymm2
			%else
			vmovdqu [rbx], ymm2
			%endif
			
			add rbx, 32
			add rax, 128

			; end-of-LoopWidth
			add rdi, 32
			cmp rdi, arg(3)
			jl .LoopWidth
	add rbx, rcx
	add rax, rdx
	; end-of-LoopHeight
	sub rsi, 1
	cmp rsi, 0
	jg .LoopHeight
	
	; begin epilog
	pop rbx
	pop rdi
	pop rsi
    COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	vzeroupper
	ret
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel41_CompY_Asm_X86_Aligned_AVX2(const uint8_t* rgbaPtr, uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2) const int8_t* kXXXXToYUV_YCoeffs)
sym(rgbaToI420Kernel41_CompY_Asm_X86_Aligned00_AVX2):
	rgbaToI420Kernel41_CompY_Asm_AVX2 0, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel41_CompY_Asm_X86_Aligned_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbaPtr, uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2) const int8_t* kXXXXToYUV_YCoeffs)
sym(rgbaToI420Kernel41_CompY_Asm_X86_Aligned10_AVX2):
	rgbaToI420Kernel41_CompY_Asm_AVX2 1, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel41_CompY_Asm_X86_Aligned_AVX2(const uint8_t* rgbaPtr, COMPV_ALIGNED(AVX2) uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2) const int8_t* kXXXXToYUV_YCoeffs)
sym(rgbaToI420Kernel41_CompY_Asm_X86_Aligned01_AVX2)
	rgbaToI420Kernel41_CompY_Asm_AVX2 0, 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel41_CompY_Asm_X86_Aligned_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbaPtr, COMPV_ALIGNED(AVX2) uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2) const int8_t* kXXXXToYUV_YCoeffs)
sym(rgbaToI420Kernel41_CompY_Asm_X86_Aligned11_AVX2):
	rgbaToI420Kernel41_CompY_Asm_AVX2 1, 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> const uint8_t* rgbaPtr
; arg(1) -> uint8_t* outUPtr
; arg(2) -> uint8_t* outVPtr
; arg(3) -> compv_scalar_t height
; arg(4) -> compv_scalar_t width
; arg(5) -> compv_scalar_t stride
; arg(6) -> COMPV_ALIGNED(SSE) const int8_t* kXXXXToYUV_UCoeffs8
; arg(7) -> COMPV_ALIGNED(SSE) const int8_t* kXXXXToYUV_VCoeffs8
; %1 -> 1: rgbaPtr is aligned, 0: rgbaPtr isn't aligned
%macro rgbaToI420Kernel11_CompUV_Asm_AVX2 1
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 8
	push rsi
	push rdi
	push rbx
	sub rsp, 16
	; end prolog

	mov rax, arg(4)
	add rax, 7
	and rax, -8
	mov rcx, arg(5)
	sub rcx, rax
	shr rcx, 1
	mov [rsp + 0], rcx ; [rsp + 0] = padUV
	mov rcx, arg(5)
	sub rcx, rax
	add rcx, arg(5)
	shl rcx, 2
	mov [rsp + 8], rcx ; [rsp + 8] = padRGBA

	vzeroupper

	; load UV coeffs interleaved: each appear #4 times (kRGBAToYUV_U4V4Coeffs8) - #4times U(or V) = #4 times 32bits = 128bits
	mov rax, arg(6)
	mov rdx, arg(7)
	vmovdqa ymm0, [rdx]
	vmovdqa ymm1, [rax]
	vinsertf128 ymm3, ymm1, xmm0, 0x1 ; ymmUV4Coeffs
	vmovdqa ymm0, [sym(kAVXMaskstore_0_u32)] ; ymmMaskToExtractFirst32Bits
	vmovdqa ymm1, [sym(k128_i16)] ; ymm128
	
	mov rbx, arg(0) ; rgbaPtr
	mov rcx, arg(1); outUPtr
	mov rdx, arg(2); outVPtr
	mov rsi, arg(3) ; height

	.LoopHeight:
		xor rdi, rdi
		.LoopWidth:
			%if %1 == 1
			vmovdqa ymm2, [rbx] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): axbxcxdx
			%else
			vmovdqu ymm2, [rbx] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): axbxcxdx
			%endif
			vpmaddubsw ymm2, ymm3 ; Ua Ub Uc Ud Va Vb Vc Vd
			vphaddw ymm2, ymm2
			vpermq ymm2, ymm2, 0xD8
			vpsraw ymm2, 8 ; >> 8
			vpaddw ymm2, ymm1 ; + 128 -> UUVV----
			vpackuswb ymm2, ymm2; Saturate(I16 -> U8)
			vpmaskmovd [rcx], ymm0, ymm2
			vpsrldq ymm2, ymm2, 4 ; >> 4
			vpmaskmovd [rdx], ymm0, ymm2
						
			add rbx, 32 ; rgbaPtr += 32
			add rcx, 4 ; outUPtr += 4
			add rdx, 4 ; outVPtr += 4

			; end-of-LoopWidth
			add rdi, 8
			cmp rdi, arg(4)
			jl .LoopWidth
	add rbx, [rsp + 8]
	add rcx, [rsp + 0]
	add rdx, [rsp + 0]
	
	; end-of-LoopHeight
	sub rsi, 2
	cmp rsi, 0
	jg .LoopHeight

	; begin epilog
	add rsp, 16
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	vzeroupper
	ret
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel11_CompUV_Asm_X86_Aligned0xx_AVX2(const uint8_t* rgbaPtr, uint8_t* outUPtr, uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2) const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2) const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbaToI420Kernel11_CompUV_Asm_X86_Aligned0xx_AVX2):
	rgbaToI420Kernel11_CompUV_Asm_AVX2 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel11_CompUV_Asm_X86_Aligned1xx_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbaPtr, uint8_t* outUPtr, uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2) const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2) const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbaToI420Kernel11_CompUV_Asm_X86_Aligned1xx_AVX2):
	rgbaToI420Kernel11_CompUV_Asm_AVX2 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> const uint8_t* rgbaPtr
; arg(1) -> uint8_t* outUPtr
; arg(2) -> uint8_t* outVPtr
; arg(3) -> compv_scalar_t height
; arg(4) -> compv_scalar_t width
; arg(5) -> compv_scalar_t stride
; arg(6) -> COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8
; arg(7) -> COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8
; %1 -> 1: rgbaPtr is aligned, 0: rgbaPtr isn't aligned
; %2 -> 1: outUPtr is aligned, 0: outUPtr isn't aligned
; %3 -> 1: outVPtr is aligned, 0: outVPtr isn't aligned
%macro rgbaToI420Kernel41_CompUV_Asm_AVX2 3
	vzeroupper
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 8
	COMPV_YASM_SAVE_YMM 7 ;YMM[6-n]
	push rsi
	push rdi
	push rbx
	sub rsp, 16
	; end prolog

	mov rax, arg(4)
	add rax, 31
	and rax, -32
	mov rcx, arg(5)
	sub rcx, rax
	shr rcx, 1
	mov [rsp + 0], rcx ; [rsp + 0] = padUV
	mov rcx, arg(5)
	sub rcx, rax
	add rcx, arg(5)
	shl rcx, 2
	mov [rsp + 8], rcx ; [rsp + 8] = padRGBA

	mov rax, arg(6) 
	mov rdx, arg(7)
	vmovdqa ymm0, [rax] ; kRGBAToYUV_UCoeffs8
	vmovdqa ymm1, [rdx] ; kRGBAToYUV_VCoeffs8
	
	mov rbx, arg(0) ; rgbaPtr
	mov rcx, arg(1); outUPtr
	mov rdx, arg(2); outVPtr
	mov rsi, arg(3) ; height

	.LoopHeight:
		xor rdi, rdi
		.LoopWidth:
			%if %1 == 1
			vmovdqa ymm4, [rbx] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): axbxcxdx
			vmovdqa ymm5, [rbx + 32] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): exfxgxhx
			vmovdqa ymm6, [rbx + 64] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): ixjxkxlx
			vmovdqa ymm7, [rbx + 96] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): mxnxoxpx
			%else
			vmovdqu ymm4, [rbx] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): axbxcxdx
			vmovdqu ymm5, [rbx + 32] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): exfxgxhx
			vmovdqu ymm6, [rbx + 64] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): ixjxkxlx
			vmovdqu ymm7, [rbx + 96] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): mxnxoxpx
			%endif

			vpunpckldq ymm2, ymm4, ymm5 ; aexxcgxx
			vpunpckhdq ymm3, ymm4, ymm5 ; bfxxdhxx
			vpunpckldq ymm4, ymm2, ymm3 ; abefcdgh
			vpermq ymm5, ymm4, 0xD8 ; abcdefgh
			vmovdqa ymm4, ymm5

			vpunpckldq ymm2, ymm6, ymm7 ; imxxkoxx
			vpunpckhdq ymm3, ymm6, ymm7 ; jnxxlpxx
			vpunpckldq ymm6, ymm2, ymm3 ; ijmnklop
			vpermq ymm7, ymm6, 0xD8 ; ijklmnop
			vmovdqa ymm6, ymm7

			; save kAVXPermutevar8x32_AEBFCGDH_i32 into ymm2
			vmovdqa ymm2, [sym(kAVXPermutevar8x32_AEBFCGDH_i32)]
			; save kAVXMaskstore_0_1_u64 into ymm3
			vmovdqa ymm3, [sym(kAVXMaskstore_0_1_u64)] ; ymmMaskToExtract128bits

			; U = (ymm4, ymm6)
			; V = (ymm5, ymm7)

			vpmaddubsw ymm4, ymm0
			vpmaddubsw ymm6, ymm0
			vpmaddubsw ymm5, ymm1
			vpmaddubsw ymm7, ymm1

			; U = ymm4
			; V = ymm5

			vphaddw ymm4, ymm6
			vphaddw ymm5, ymm7

			vpsraw ymm4, 8 ; >> 8
			vpsraw ymm5, 8 ; >> 8

			vpaddw ymm4, [sym(k128_i16)] ; +128
			vpaddw ymm5, [sym(k128_i16)] ; +128

			; UV = ymm4

			vpackuswb ymm4, ymm5 ; Packs + Saturate(I16 -> U8)

			; Final Permute
			vpermd ymm4, ymm2, ymm4

			%if %2 == 1
			vextractf128 [rcx], ymm4, 0
			%else
			vpmaskmovq [rcx], ymm3, ymm4
			%endif
			%if %3 == 1
			vextractf128 [rdx], ymm4, 1
			%else
			vpermq ymm4, ymm4, 0xE
			vpmaskmovq [rdx], ymm3, ymm4
			%endif
			
			add rbx, 128 ; rgbaPtr += 128
			add rcx, 16 ; outUPtr += 16
			add rdx, 16 ; outVPtr += 16

			; end-of-LoopWidth
			add rdi, 32
			cmp rdi, arg(4)
			jl .LoopWidth
	add rbx, [rsp + 8]
	add rcx, [rsp + 0]
	add rdx, [rsp + 0]
	
	; end-of-LoopHeight
	sub rsi, 2
	cmp rsi, 0
	jg .LoopHeight

	; begin epilog
	add rsp, 16
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_RESTORE_YMM
	COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	vzeroupper
	ret
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel41_CompUV_Asm_X86_Aligned000_AVX2(const uint8_t* rgbaPtr, uint8_t* outUPtr, uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbaToI420Kernel41_CompUV_Asm_X86_Aligned000_AVX2):
	rgbaToI420Kernel41_CompUV_Asm_AVX2 0, 0, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel41_CompUV_Asm_X86_Aligned100_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbaPtr, uint8_t* outUPtr, uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbaToI420Kernel41_CompUV_Asm_X86_Aligned100_AVX2):
	rgbaToI420Kernel41_CompUV_Asm_AVX2 1, 0, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel41_CompUV_Asm_X86_Aligned110_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbaPtr, COMPV_ALIGNED(AVX2) uint8_t* outUPtr, uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbaToI420Kernel41_CompUV_Asm_X86_Aligned110_AVX2):
	rgbaToI420Kernel41_CompUV_Asm_AVX2 1, 1, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbaToI420Kernel41_CompUV_Asm_X86_Aligned000_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbaPtr, COMPV_ALIGNED(AVX2) uint8_t* outUPtr, COMPV_ALIGNED(AVX2) uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbaToI420Kernel41_CompUV_Asm_X86_Aligned111_AVX2):
	rgbaToI420Kernel41_CompUV_Asm_AVX2 1, 1, 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> const uint8_t* rgbPtr
; arg(1) -> uint8_t* outYPtr
; arg(2) -> compv_scalar_t height
; arg(3) -> compv_scalar_t width
; arg(4) -> compv_scalar_t stride
; arg(5) -> COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_YCoeffs8
; %1 -> 1: rgbPtr is aligned, 0: rgbPtr not aligned
; %2 -> 1: outYPtr is aligned, 0: outYPtr not aligned
%macro rgbToI420Kernel31_CompY_Asm_X86_AVX2 2
	vzeroupper
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 6
	COMPV_YASM_SAVE_YMM 6 ;XMM[6-n]
	push rsi
	push rdi
	push rbx
	; end prolog

	; align stack and alloc memory
	COMPV_YASM_ALIGN_STACK 32, rax
	sub rsp, 16+32+32+32+32 ; [rsp+0]=temp128, [rsp+16+x*32]=rba[4]

	mov rax, arg(3)
	add rax, 31
	and rax, -32
	mov rcx, arg(4)
	sub rcx, rax ; rcx = padY
	mov rdx, rcx
	imul rdx, 3 ; rdx = padRGB

	mov rax, arg(5)
	vmovdqa ymm0, [rax] ; ymmYCoeffs
	vmovdqa ymm1, [sym(k16_i16)] ; ymm16

	mov rax, arg(0) ; rgbPtr
	mov rsi, arg(2) ; height
	mov rbx, arg(1) ; outYPtr

	.LoopHeight:
		xor rdi, rdi
		.LoopWidth:
			; Convert RGB -> RGBA
			; This macro modify [ymm4 - ymm7]
			COMPV_3RGB_TO_4RGBA_AVX2 rax, rsp+16, rsp+0, %1, 1;  COMPV_3RGB_TO_4RGBA_AVX2(rgbPtr, rgbaPtr, tmp128, rgbPtrIsAligned, rgbaPtrIsAligned)			

			vmovdqa ymm6, [sym(kAVXPermutevar8x32_AEBFCGDH_i32)] ; ymmAEBFCGDH

			vmovdqa ymm2, [rsp + 16 + 0] ; 8 RGBA samples
			vmovdqa ymm3, [rsp + 16 + 32] ; 8 RGBA samples	
			vmovdqa ymm4, [rsp + 16 + 64] ; 8 RGBA samples	
			vmovdqa ymm5, [rsp + 16 + 96] ; 8 RGBA samples

			vpmaddubsw ymm2, ymm0
			vpmaddubsw ymm3, ymm0
			vpmaddubsw ymm4, ymm0
			vpmaddubsw ymm5, ymm0

			vphaddw ymm2, ymm3 ; hadd(ABCD) -> ACBD
			vphaddw ymm4, ymm5 ; hadd(EFGH) -> EGFH

			vpsraw ymm2, 7 ; >> 7
			vpsraw ymm4, 7 ; >> 7

			vpaddw ymm2, ymm1 ; + 16
			vpaddw ymm4, ymm1 ; + 16

			vpackuswb ymm2, ymm4 ; Saturate(I16 -> U8): packus(ACBD, EGFH) -> AEBFCGDH

			; Final permute
			vpermd ymm2, ymm6, ymm2
			%if %2==1
			vmovdqa [rbx], ymm2
			%else
			vmovdqu [rbx], ymm2
			%endif
			
			add rbx, 32
			add rax, 96

			; end-of-LoopWidth
			add rdi, 32
			cmp rdi, arg(3)
			jl .LoopWidth
	add rbx, rcx
	add rax, rdx
	; end-of-LoopHeight
	sub rsi, 1
	cmp rsi, 0
	jg .LoopHeight

	; unalign stack and alloc memory
	add rsp, 16+32+32+32+32
	COMPV_YASM_UNALIGN_STACK
	
	; begin epilog
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_RESTORE_YMM
    COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	vzeroupper
	ret
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void rgbToI420Kernel31_CompY_Asm_X86_Aligned00_AVX2(const uint8_t* rgbPtr, uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_YCoeffs8)
sym(rgbToI420Kernel31_CompY_Asm_X86_Aligned00_AVX2):
	rgbToI420Kernel31_CompY_Asm_X86_AVX2 0, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void rgbToI420Kernel31_CompY_Asm_X86_Aligned01_AVX2(const uint8_t* rgbPtr, COMPV_ALIGNED(AVX2) uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_YCoeffs8)
sym(rgbToI420Kernel31_CompY_Asm_X86_Aligned01_AVX2):
	rgbToI420Kernel31_CompY_Asm_X86_AVX2 0, 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void rgbToI420Kernel31_CompY_Asm_X86_Aligned10_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbPtr, uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_YCoeffs8)
sym(rgbToI420Kernel31_CompY_Asm_X86_Aligned10_AVX2):
	rgbToI420Kernel31_CompY_Asm_X86_AVX2 1, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void rgbToI420Kernel31_CompY_Asm_X86_Aligned11_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbPtr, COMPV_ALIGNED(AVX2) uint8_t* outYPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_YCoeffs8)
sym(rgbToI420Kernel31_CompY_Asm_X86_Aligned11_AVX2):
	rgbToI420Kernel31_CompY_Asm_X86_AVX2 1, 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> const uint8_t* rgbPtr
; arg(1) -> uint8_t* outUPtr
; arg(2) ->uint8_t* outVPtr
; arg(3) ->compv_scalar_t height
; arg(4) ->compv_scalar_t width
; arg(5) ->compv_scalar_t stride
; arg(6) ->COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8
; arg(7) ->COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8
; %1 -> 1: rgbPtr is AVX-aligned, 0: not aligned
; %2 -> 1: outUPtr is SSE-aligned, 0: not aligned
; %3 -> 1: outVPtr is SSE-aligned, 0: not aligned
%macro rgbToI420Kernel31_CompUV_Asm_X86_AVX2 3
	vzeroupper
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 8
	COMPV_YASM_SAVE_YMM 7 ;XMM[6-n]
	push rsi
	push rdi
	push rbx
	; end prolog

	; align stack and alloc memory
	COMPV_YASM_ALIGN_STACK 32, rax
	sub rsp, 16+16+32+32+32+32 ; [rsp+0]=padUV||padRGB,[rsp+16]=temp128, [rsp+32+x*32]=rba[4]

	mov rax, arg(4)
	add rax, 31
	and rax, -32
	mov rcx, arg(5)
	sub rcx, rax
	shr rcx, 1
	mov [rsp + 0], rcx ; [rsp + 0] = padUV
	mov rcx, arg(5)
	sub rcx, rax
	add rcx, arg(5)
	imul rcx, 3
	mov [rsp + 8], rcx ; [rsp + 8] = padRGB

	mov rax, arg(6) 
	mov rdx, arg(7)
	vmovdqa ymm0, [rax] ; kRGBAToYUV_UCoeffs8
	vmovdqa ymm1, [rdx] ; kRGBAToYUV_VCoeffs8
	
	mov rbx, arg(0) ; rgbPtr
	mov rcx, arg(1); outUPtr
	mov rdx, arg(2); outVPtr
	mov rsi, arg(3) ; height

	.LoopHeight:
		xor rdi, rdi
		.LoopWidth:
			; Convert RGB -> RGBA
			; This macro modify [ymm4 - ymm7]
			COMPV_3RGB_TO_4RGBA_AVX2 rbx, rsp+32, rsp+16, 1, 1;  COMPV_3RGB_TO_4RGBA_AVX2([in]rgbPtr, [out]rgbaPtr, [in]tmp128, [in]rgbPtrIsAligned, [in]rgbaPtrIsAligned)	

			%if %1 == 1
			vmovdqa ymm4, [rsp + 32 + 0] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): axbxcxdx
			vmovdqa ymm5, [rsp + 32 + 32] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): exfxgxhx
			vmovdqa ymm6, [rsp + 32 + 64] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): ixjxkxlx
			vmovdqa ymm7, [rsp + 32 + 96] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): mxnxoxpx
			%else
			vmovdqu ymm4, [rsp + 32 + 0] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): axbxcxdx
			vmovdqu ymm5, [rsp + 32 + 32] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): exfxgxhx
			vmovdqu ymm6, [rsp + 32 + 64] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): ixjxkxlx
			vmovdqu ymm7, [rsp + 32 + 96] ; 8 RGBA samples = 32bytes (4 are useless, we want 1 out of 2): mxnxoxpx
			%endif

			vpunpckldq ymm2, ymm4, ymm5 ; aexxcgxx
			vpunpckhdq ymm3, ymm4, ymm5 ; bfxxdhxx
			vpunpckldq ymm4, ymm2, ymm3 ; abefcdgh
			vpermq ymm5, ymm4, 0xD8 ; abcdefgh
			vmovdqa ymm4, ymm5

			vpunpckldq ymm2, ymm6, ymm7 ; imxxkoxx
			vpunpckhdq ymm3, ymm6, ymm7 ; jnxxlpxx
			vpunpckldq ymm6, ymm2, ymm3 ; ijmnklop
			vpermq ymm7, ymm6, 0xD8 ; ijklmnop
			vmovdqa ymm6, ymm7

			; save kAVXPermutevar8x32_AEBFCGDH_i32 into ymm2
			vmovdqa ymm2, [sym(kAVXPermutevar8x32_AEBFCGDH_i32)]
			; save kAVXMaskstore_0_1_u64 into ymm3
			vmovdqa ymm3, [sym(kAVXMaskstore_0_1_u64)] ; ymmMaskToExtract128bits

			; U = (ymm4, ymm6)
			; V = (ymm5, ymm7)

			vpmaddubsw ymm4, ymm0
			vpmaddubsw ymm6, ymm0
			vpmaddubsw ymm5, ymm1
			vpmaddubsw ymm7, ymm1

			; U = ymm4
			; V = ymm5

			vphaddw ymm4, ymm6
			vphaddw ymm5, ymm7

			vpsraw ymm4, 8 ; >> 8
			vpsraw ymm5, 8 ; >> 8

			vpaddw ymm4, [sym(k128_i16)] ; +128
			vpaddw ymm5, [sym(k128_i16)] ; +128

			; UV = ymm4

			vpackuswb ymm4, ymm5 ; Packs + Saturate(I16 -> U8)

			; Final Permute
			vpermd ymm4, ymm2, ymm4

			%if %2 == 1
			vextractf128 [rcx], ymm4, 0
			%else
			vpmaskmovq [rcx], ymm3, ymm4
			%endif
			%if %3 == 1
			vextractf128 [rdx], ymm4, 1
			%else
			vpermq ymm4, ymm4, 0xE
			vpmaskmovq [rdx], ymm3, ymm4
			%endif
			
			add rbx, 96 ; rgbPtr += 128
			add rcx, 16 ; outUPtr += 16
			add rdx, 16 ; outVPtr += 16

			; end-of-LoopWidth
			add rdi, 32
			cmp rdi, arg(4)
			jl .LoopWidth
	add rbx, [rsp + 8]
	add rcx, [rsp + 0]
	add rdx, [rsp + 0]
	
	; end-of-LoopHeight
	sub rsi, 2
	cmp rsi, 0
	jg .LoopHeight

	; unalign stack and alloc memory
	add rsp, 16+16+32+32+32+32
	COMPV_YASM_UNALIGN_STACK

	; begin epilog
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_RESTORE_YMM
	COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	vzeroupper
	ret
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbToI420Kernel31_CompUV_Asm_X86_Aligned000_AVX2(const uint8_t* rgbPtr, uint8_t* outUPtr, uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbToI420Kernel31_CompUV_Asm_X86_Aligned000_AVX2):
	rgbToI420Kernel31_CompUV_Asm_X86_AVX2 0, 0, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbToI420Kernel31_CompUV_Asm_X86_Aligned100_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbPtr, uint8_t* outUPtr, uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbToI420Kernel31_CompUV_Asm_X86_Aligned100_AVX2):
	rgbToI420Kernel31_CompUV_Asm_X86_AVX2 1, 0, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbToI420Kernel31_CompUV_Asm_X86_Aligned110_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbPtr, COMPV_ALIGNED(SSE) uint8_t* outUPtr, uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbToI420Kernel31_CompUV_Asm_X86_Aligned110_AVX2):
	rgbToI420Kernel31_CompUV_Asm_X86_AVX2 1, 1, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void rgbToI420Kernel31_CompUV_Asm_X86_Aligned111_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* rgbPtr, COMPV_ALIGNED(SSE) uint8_t* outUPtr, COMPV_ALIGNED(SSE) uint8_t* outVPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_UCoeffs8, COMPV_ALIGNED(AVX2)const int8_t* kXXXXToYUV_VCoeffs8)
sym(rgbToI420Kernel31_CompUV_Asm_X86_Aligned111_AVX2):
	rgbToI420Kernel31_CompUV_Asm_X86_AVX2 1, 1, 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> const uint8_t* yPtr
; arg(1) -> const uint8_t* uPtr
; arg(2) -> const uint8_t* vPtr
; arg(3) -> uint8_t* outRgbaPtr
; arg(4) -> compv_scalar_t height
; arg(5) -> compv_scalar_t width
; arg(6) -> compv_scalar_t stride
; %1 -> 1: yPtr aligned, 0: yPtr not aligned
; %2 -> 1: outRgbaPtr aligned, 0: outRgbaPtr not aligned
%macro i420ToRGBAKernel11_Asm_AVX2 2
	vzeroupper
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 7
	COMPV_YASM_SAVE_YMM 7 ;XMM[6-n]
	push rsi
	push rdi
	push rbx
	; end prolog

	; align stack and alloc memory
	COMPV_YASM_ALIGN_STACK 32, rax
	sub rsp, 32+32+32+8+8+8+8

	; xmmY = [rsp + 32] ; xmmU = [rsp + 64] ; xmmV = [rsp + 96]
	mov rax, arg(5)
	add rax, 31
	and rax, -32
	mov rdx, rax
	add rdx, 1
	shr rdx, 1
	neg rdx
	mov [rsp + 0], rdx ; [rsp + 0] = rollbackUV
	mov rdx, arg(6)
	sub rdx, rax
	mov [rsp + 8], rdx ; [rsp + 8] = padY
	mov rcx, rdx
	add rdx, 1
	shr rdx, 1
	mov [rsp + 16], rdx ; [rsp + 16] = padUV
	shl rcx, 2
	mov [rsp + 24], rcx ; [rsp + 24] = padRGBA

	mov rcx, arg(0) ; yPtr
	mov rdx, arg(1) ; uPtr
	mov rbx, arg(2) ; vPtr
	mov rax, arg(3) ; outRgbaPtr
	mov rsi, arg(4) ; height

	.LoopHeight:
		xor rdi, rdi
		.LoopWidth:
			vmovdqa ymm3, [sym(kAVXMaskstore_0_1_u64)]
			%if %1 == 1
			vmovdqa ymm0, [rcx] ; 32 Y samples = 32bytes
			%else
			vmovdqu ymm0, [rcx] ; 32 Y samples = 32bytes
			%endif
			vpmaskmovq ymm1, ymm3, [rdx] ; 16 U samples, low mem
			vpmaskmovq ymm2, ymm3, [rbx] ; 16 V samples, low mem
			; Duplicate and interleave
			vpermq ymm1, ymm1, 0xD8
			vpunpcklbw ymm1, ymm1
			vpermq ymm2, ymm2, 0xD8
			vpunpcklbw ymm2, ymm2

			;;;;;;;;;;;;;;;;;;;;;
			;;;;;; 16Y-LOW ;;;;;;
			;;;;;;;;;;;;;;;;;;;;;
			
			; YUV0 = (ymm6 || ymm3)
			vpxor ymm5, ymm5
			vpunpcklbw ymm3, ymm0, ymm2 ; YVYVYVYVYVYVYV....
			vpunpcklbw ymm4, ymm1, ymm5 ; U0U0U0U0U0U0U0U0....
			vpunpcklbw ymm6, ymm3, ymm4 ; YUV0YUV0YUV0YUV0YUV0YUV0
			vpunpckhbw ymm3, ymm4

			; save ymm0, ymm1 and ymm2
			vmovdqa [rsp + 32], ymm0
			vmovdqa [rsp + 64], ymm1
			vmovdqa [rsp + 96], ymm2

			; ymm0 = R
			vmovdqa ymm7, [sym(kYUVToRGBA_RCoeffs8)]
			vpmaddubsw ymm0, ymm6, ymm7
			vpmaddubsw ymm1, ymm3, ymm7
			vphaddw ymm0, ymm1
			vpsubw ymm0, [sym(k7120_i16)]
			vpsraw ymm0, 5
			; ymm1 = B
			vmovdqa ymm7, [sym(kYUVToRGBA_BCoeffs8)]
			vpmaddubsw ymm1, ymm6, ymm7
			vpmaddubsw ymm2, ymm3, ymm7
			vphaddw ymm1, ymm2
			vpsubw ymm1, [sym(k8912_i16)]
			vpsraw ymm1, 5
			; ymm4 = RBRBRBRBRBRB
			vpunpcklwd ymm4, ymm0, ymm1
			vpunpckhwd ymm5, ymm0, ymm1
			vpackuswb ymm4, ymm5

			; ymm6 = G
			vmovdqa ymm7, [sym(kYUVToRGBA_GCoeffs8)]
			vmovdqa ymm2, [sym(k255_i16)] ; alpha
			vpmaddubsw ymm6, ymm7
			vpmaddubsw ymm3, ymm7
			vphaddw ymm6, ymm3
			vpaddw ymm6, [sym(k4400_i16)]
			vpsraw ymm6, 5
			; ymm3 = GAGAGAGAGAGAGA
			vpunpcklwd ymm3, ymm6, ymm2
			vpunpckhwd ymm6, ymm2
			vpackuswb ymm3, ymm6

			; outRgbaPtr[x-y] = RGBARGBARGBARGBA
			; re-order the samples for the final unpacklo, unpackhi
			vpermq ymm4, ymm4, 0xD8
			vpermq ymm3, ymm3, 0xD8
			; because of AVX cross-lane issue final data = (0, 2, 1, 3)*32 = (0, 64, 32, 96)
			vpunpcklbw ymm5, ymm4, ymm3
			vpunpckhbw ymm4, ymm3
			%if %2==1
			vmovdqa [rax + 0], ymm5 ; high8(RGBARGBARGBARGBA)
			vmovdqa [rax + 64], ymm4 ; low8(RGBARGBARGBARGBA)
			%else
			vmovdqu [rax + 0], ymm5 ; high8(RGBARGBARGBARGBA)
			vmovdqu [rax + 64], ymm4 ; low8(RGBARGBARGBARGBA)
			%endif

			;;;;;;;;;;;;;;;;;;;;;
			;;;;;; 8Y-HIGH  ;;;;;
			;;;;;;;;;;;;;;;;;;;;;

			; restore ymm0, ymm1 and ymm2
			vmovdqa ymm0, [rsp + 32]
			vmovdqa ymm1, [rsp + 64]
			vmovdqa ymm2, [rsp + 96]

			; YUV0 = (ymm6 || ymm3)
			vpxor ymm5, ymm5
			vpunpckhbw ymm3, ymm0, ymm2 ; YVYVYVYVYVYVYV....
			vpunpckhbw ymm4, ymm1, ymm5 ; U0U0U0U0U0U0U0U0....
			vpunpcklbw ymm6, ymm3, ymm4 ; YUV0YUV0YUV0YUV0YUV0YUV0
			vpunpckhbw ymm3, ymm4

			; ymm0 = R
			vmovdqa ymm7, [sym(kYUVToRGBA_RCoeffs8)]
			vpmaddubsw ymm0, ymm6, ymm7
			vpmaddubsw ymm1, ymm3, ymm7
			vphaddw ymm0, ymm1
			vpsubw ymm0, [sym(k7120_i16)]
			vpsraw ymm0, 5
			; ymm1 = B
			vmovdqa ymm7, [sym(kYUVToRGBA_BCoeffs8)]
			vpmaddubsw ymm1, ymm6, ymm7
			vpmaddubsw ymm2, ymm3, ymm7
			vphaddw ymm1, ymm2
			vpsubw ymm1, [sym(k8912_i16)]
			vpsraw ymm1, 5
			; ymm4 = RBRBRBRBRBRB
			vpunpcklwd ymm4, ymm0, ymm1
			vpunpckhwd ymm5, ymm0, ymm1
			vpackuswb ymm4, ymm5

			; ymm6 = G
			vmovdqa ymm7, [sym(kYUVToRGBA_GCoeffs8)]
			vmovdqa ymm2, [sym(k255_i16)] ; alpha
			vpmaddubsw ymm6, ymm7
			vpmaddubsw ymm3, ymm7
			vphaddw ymm6, ymm3
			vpaddw ymm6, [sym(k4400_i16)]
			vpsraw ymm6, 5
			; ymm3 = GAGAGAGAGAGAGA
			vpunpcklwd ymm3, ymm6, ymm2
			vpunpckhwd ymm6, ymm2
			vpackuswb ymm3, ymm6

			; outRgbaPtr[x-y] = RGBARGBARGBARGBA
			; re-order the samples for the final unpacklo, unpackhi
			vpermq ymm4, ymm4, 0xD8
			vpermq ymm3, ymm3, 0xD8
			; because of AVX cross-lane issue final data = (0, 2, 1, 3)*32 = (0, 64, 32, 96)
			vpunpcklbw ymm5, ymm4, ymm3
			vpunpckhbw ymm4, ymm3
			%if %2==1
			vmovdqa [rax + 32], ymm5 ; high8(RGBARGBARGBARGBA)
			vmovdqa [rax + 96], ymm4 ; low8(RGBARGBARGBARGBA)
			%else
			vmovdqu [rax + 32], ymm5 ; high8(RGBARGBARGBARGBA)
			vmovdqu [rax + 96], ymm4 ; low8(RGBARGBARGBARGBA)
			%endif

			; Move pointers
			add rcx, 32 ; yPtr += 32
			add rdx, 16 ; uPtr += 16
			add rbx, 16 ; vPtr += 16
			add rax, 128 ; outRgbaPtr += 128

			; end-of-LoopWidth
			add rdi, 32
			cmp rdi, arg(5)
			jl .LoopWidth
	add rcx, [rsp + 8] ; yPtr += padY
	add rax, [rsp + 24] ; outRgbaPtr += padRGBA
	mov rdi, rsi
	and rdi, 1
	cmp rdi, 1
	je .rdi_odd
	.rdi_even:
		add rdx, [rsp + 0] ; uPtr += rollbackUV
		add rbx, [rsp + 0] ; vPtr += rollbackUV
		jmp .rdi_done
	.rdi_odd:
		add rdx, [rsp + 16] ; uPtr += padUV
		add rbx, [rsp + 16] ; vPtr += padUV
	.rdi_done:
	; end-of-LoopHeight
	sub rsi, 1
	cmp rsi, 0
	jg .LoopHeight

	; unalign stack and alloc memory
	add rsp, 32+32+32+8+8+8+8
	COMPV_YASM_UNALIGN_STACK

	; begin epilog
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_RESTORE_YMM
    COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	vzeroupper
	ret
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void i420ToRGBAKernel11_Asm_X86_Aligned00_AVX2(const uint8_t* yPtr, const uint8_t* uPtr, const uint8_t* vPtr, uint8_t* outRgbaPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride)
sym(i420ToRGBAKernel11_Asm_X86_Aligned00_AVX2):
	i420ToRGBAKernel11_Asm_AVX2 0, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void i420ToRGBAKernel11_Asm_X86_Aligned10_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* yPtr, const uint8_t* uPtr, const uint8_t* vPtr, uint8_t* outRgbaPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride)
sym(i420ToRGBAKernel11_Asm_X86_Aligned10_AVX2):
	i420ToRGBAKernel11_Asm_AVX2 1, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void i420ToRGBAKernel11_Asm_X86_Aligned01_AVX2(const uint8_t* yPtr, const uint8_t* uPtr, const uint8_t* vPtr, COMPV_ALIGNED(AVX2) uint8_t* outRgbaPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride)
sym(i420ToRGBAKernel11_Asm_X86_Aligned01_AVX2):
	i420ToRGBAKernel11_Asm_AVX2 0, 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; void i420ToRGBAKernel11_Asm_X86_Aligned11_AVX2(COMPV_ALIGNED(AVX2) const uint8_t* yPtr, const uint8_t* uPtr, const uint8_t* vPtr, COMPV_ALIGNED(AVX2) uint8_t* outRgbaPtr, compv_scalar_t height, compv_scalar_t width, compv_scalar_t stride)
sym(i420ToRGBAKernel11_Asm_X86_Aligned11_AVX2):
	i420ToRGBAKernel11_Asm_AVX2 1, 1