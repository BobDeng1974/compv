;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>	;
; File author: Mamadou DIOP (Doubango Telecom, France).					;
; License: GPLv3. For commercial license please contact us.				;
; Source code: https://github.com/DoubangoTelecom/compv					;
; WebSite: http://compv.org												;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "../../compv_common_x86.s"
%include "../../compv_bits_macros_x86.s"
%include "../../math/compv_math_macros_x86.s"
%include "compv_feature_fast_dete_macros_x86.s"

COMPV_YASM_DEFAULT_REL

global sym(Fast9Strengths16_Asm_CMOV_X86_SSE41)
global sym(Fast9Strengths16_Asm_X86_SSE41)
global sym(Fast12Strengths16_Asm_CMOV_X86_SSE41)
global sym(Fast12Strengths16_Asm_X86_SSE41)

global sym(Fast9Strengths32_Asm_CMOV_X86_SSE41)
global sym(Fast9Strengths32_Asm_X86_SSE41)
global sym(Fast12Strengths32_Asm_CMOV_X86_SSE41)
global sym(Fast12Strengths32_Asm_X86_SSE41)

global sym(FastData16Row_Asm_X86_SSE2)

section .data
	extern sym(kFast9Arcs)
	extern sym(kFast12Arcs)
	extern sym(Fast9Flags)
	extern sym(Fast12Flags)
	extern sym(k1_i8)
	extern sym(k254_u8)
	extern sym(FastStrengths16) ; Function

section .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> const uint8_t* IP,
; arg(1) -> const uint8_t* IPprev,
; arg(2) -> compv_scalar_t width,
; arg(3) -> const compv_scalar_t(&pixels16)[16],
; arg(4) -> compv_scalar_t N,
; arg(5) -> compv_scalar_t threshold,
; arg(6) -> uint8_t* strengths,
; arg(7) -> compv_scalar_t* me
; void FastData16Row_Asm_X86_SSE2(const uint8_t* IP, const uint8_t* IPprev, compv_scalar_t width, const compv_scalar_t(&pixels16)[16], compv_scalar_t N, compv_scalar_t threshold, uint8_t* strengths, compv_scalar_t* me);
sym(FastData16Row_Asm_X86_SSE2):
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 8
	COMPV_YASM_SAVE_XMM 7 ;XMM[6-n]
	push rsi
	push rdi
	push rbx
	; end prolog

	; align stack and alloc memory
	COMPV_YASM_ALIGN_STACK 16, rax
	sub rsp, 8 + 8 + 8 + 8*16 + 8*16 + 16 + 16*16 + 16*16 + 16*16 + 16*16 + 16*16 + 16
	; [rsp + 0] = compv_scalar_t sum
	; [rsp + 8] = compv_scalar_t colDarkersFlags
	; [rsp + 16] = compv_scalar_t colBrightersFlags
	; [rsp + 24] = compv_scalar_t fdarkers16[16];
	; [rsp + 152] = compv_scalar_t fbrighters16[16];
	; [rsp + 280] = __m128i xmmNMinusOne
	; [rsp + 296] = __m128i xmmDarkersFlags[16]
	; [rsp + 552] = __m128i xmmBrightersFlags[16]
	; [rsp + 808] = __m128i xmmDataPtr[16]
	; [rsp + 1064] = __m128i xmmDdarkers16x16[16];
	; [rsp + 1320] = __m128i xmmDbrighters16x16[16];
	; [rsp + 1576] = __m128i xmmThreshold (saved/restored after function call)

	mov rsi, arg(2) ; rsi = width
	mov rax, arg(5) ; threshold
	mov rbx, arg(0) ; rbx = IP
	movd xmm7, eax
	punpcklbw xmm7, xmm7  
	punpcklwd xmm7, xmm7  
	pshufd xmm7, xmm7, 0  ; xmm7 = _mm_set1_epi8((uint8_t)threshold)) = xmmThreshold

	; Compute xmmNMinusOne
	mov rax, arg(4) ; N
	sub rax, 1
	movd xmm0, rax
	punpcklbw xmm0, xmm0  
	punpcklwd xmm0, xmm0  
	pshufd xmm0, xmm0, 0
	movdqa [rsp + 280], xmm0
	
	;-------------------
	;StartOfLooopRows
	;
	.LoopRows
	; -------------------	 
	movdqu xmm6, [rbx]
	pxor xmm4, xmm4 ; xmm4 = xmmZeros

	; Motion Estimation
	; TODO(dmi): not supported
	; TODO(dmi): inc IPprev here

	; cleanup strengths
	mov rax, arg(6)
	movdqu [rax], xmm4

	movdqa xmm5, xmm6
	paddusb xmm6, xmm7 ; xmm6 = xmmBrighter
	psubusb xmm5, xmm7 ; xmm5 = xmmDarker

	;
	; Speed-Test-1
	;

	; compare I1 and I9 aka 0 and 8
	mov rdx, arg(3) ; pixels16
	mov rax, [rdx + 0*COMPV_YASM_REG_SZ_BYTES] ; pixels16[0]
	mov rdx, [rdx + 8*COMPV_YASM_REG_SZ_BYTES] ; pixels16[8]
	movdqu xmm0, [rbx + rax] ; IP[pixels16[0]]
	movdqu xmm1, [rbx + rdx] ; IP[pixels16[8]]
	movdqa xmm2, xmm5 ; xmmDarker
	movdqa xmm3, xmm5 ; xmmDarker
	psubusb xmm2, xmm0 ; ddarkers16x16[0]
	psubusb xmm3, xmm1 ; ddarkers16x16[8]
	psubusb xmm0, xmm6 ; dbrighters16x16[0]
	psubusb xmm1, xmm6 ; dbrighters16x16[8]
	movdqa [rsp + 1064 + 0*16], xmm2
	movdqa [rsp + 1064 + 8*16], xmm3
	movdqa [rsp + 1320 + 0*16], xmm0
	movdqa [rsp + 1320 + 8*16], xmm1
	pcmpeqb xmm2, xmm4
	pcmpeqb xmm3, xmm4
	pcmpeqb xmm0, xmm4
	pcmpeqb xmm1, xmm4
	pcmpeqb xmm4, xmm4  ; xmm4 = xmmFF
	pandn xmm2, xmm4
	pandn xmm3, xmm4
	pandn xmm0, xmm4
	pandn xmm1, xmm4
	movdqa [rsp + 296 + 0*16], xmm2 ; xmmDarkersFlags[0]
	movdqa [rsp + 296 + 8*16], xmm3 ; xmmDarkersFlags[8]
	movdqa [rsp + 552 + 0*16], xmm0 ; xmmBrightersFlags[0]
	movdqa [rsp + 552 + 8*16], xmm1 ; xmmBrightersFlags[8]
	por xmm0, xmm2
	por xmm1, xmm3
	pmovmskb eax, xmm0
	pmovmskb edx, xmm1
	test ax, ax
	setnz al
	test dx, dx
	setnz dl
	add dl, al
	test dl, dl
	jz .LoopRowsNext
	mov [rsp + 0], dl ; sum = ?

	; compare I5 and I13 aka 4 and 12
	mov rdx, arg(3) ; pixels16
	mov rax, [rdx + 4*COMPV_YASM_REG_SZ_BYTES] ; pixels16[4]
	mov rdx, [rdx + 12*COMPV_YASM_REG_SZ_BYTES] ; pixels16[12]
	pxor xmm4, xmm4 ; xmm4 = xmmZeros
	movdqu xmm0, [rbx + rax] ; IP[pixels16[4]]
	movdqu xmm1, [rbx + rdx] ; IP[pixels16[12]]
	movdqa xmm2, xmm5 ; xmmDarker
	movdqa xmm3, xmm5 ; xmmDarker
	psubusb xmm2, xmm0 ; ddarkers16x16[4]
	psubusb xmm3, xmm1 ; ddarkers16x16[12]
	psubusb xmm0, xmm6 ; dbrighters16x16[4]
	psubusb xmm1, xmm6 ; dbrighters16x16[12]
	movdqa [rsp + 1064 + 4*16], xmm2
	movdqa [rsp + 1064 + 12*16], xmm3
	movdqa [rsp + 1320 + 4*16], xmm0
	movdqa [rsp + 1320 + 12*16], xmm1
	pcmpeqb xmm2, xmm4
	pcmpeqb xmm3, xmm4
	pcmpeqb xmm0, xmm4
	pcmpeqb xmm1, xmm4
	pcmpeqb xmm4, xmm4  ; xmm4 = xmmFF
	pandn xmm2, xmm4
	pandn xmm3, xmm4
	pandn xmm0, xmm4
	pandn xmm1, xmm4
	movdqa [rsp + 296 + 4*16], xmm2 ; xmmDarkersFlags[4]
	movdqa [rsp + 296 + 12*16], xmm3 ; xmmDarkersFlags[12]
	movdqa [rsp + 552 + 4*16], xmm0 ; xmmBrightersFlags[4]
	movdqa [rsp + 552 + 12*16], xmm1 ; xmmBrightersFlags[12]
	por xmm0, xmm2
	por xmm1, xmm3
	pmovmskb eax, xmm0
	pmovmskb edx, xmm1
	test ax, ax
	setnz al
	test dx, dx
	setnz dl
	add dl, al
	test dl, dl
	jz .LoopRowsNext
	add [rsp + 0], dl ; sum += ?

	;
	;  Speed-Test-2
	;
	
	mov cl, arg(4) ; N
	mov al, [rsp + 0] ; sum
	cmp cl, 9
	je .SpeedTest2For9
	; otherwise ...N == 12
	cmp al, 3
	jl .LoopRowsNext
	jmp .EndOfSpeedTest2

	.SpeedTest2For9
	cmp al, 2
	jl .LoopRowsNext
	
	.EndOfSpeedTest2

	;
	;	Processing
	;

	; Check whether to load Brighters
	movdqa xmm0, [rsp + 552 + 0*16] ; xmmBrightersFlags[0]
	movdqa xmm1, [rsp + 552 + 4*16] ; xmmBrightersFlags[4]
	por xmm0, [rsp + 552 + 8*16] ; xmmBrightersFlags[0] | xmmBrightersFlags[8]
	por xmm1, [rsp + 552 + 12*16] ; xmmBrightersFlags[4] | xmmBrightersFlags[12]
	pmovmskb eax, xmm0
	pmovmskb edx, xmm1
	test ax, ax
	setnz al
	test dx, dx
	setnz dl
	add dl, al
	cmp dl, 1
	setg dl
	movzx rdi, byte dl ; rdi = (rdx > 1) ? 1 : 0

	; Check whether to load Darkers
	movdqa xmm0, [rsp + 296 + 0*16] ; xmmDarkersFlags[0]
	movdqa xmm1, [rsp + 296 + 4*16] ; xmmDarkersFlags[4]
	por xmm0, [rsp + 296 + 8*16] ; xmmDarkersFlags[0] | xmmDarkersFlags[8]
	por xmm1, [rsp + 296 + 12*16] ; xmmDarkersFlags[4] | xmmDarkersFlags[12]
	pmovmskb eax, xmm0
	pmovmskb edx, xmm1
	test ax, ax
	setnz al
	test dx, dx
	setnz dl
	add dl, al
	cmp dl, 1
	setg dl ; rdx = (rdx > 1) ? 1 : 0

	; rdi = loadB, rdx = loadD
	; skip process if (!(loadB || loadD))
	mov rax, rdi
	or al, dl
	test al, al
	jz .LoopRowsNext

	; Set colDarkersFlags and colBrightersFlags to zero
	xor rax, rax
	mov [rsp + 8], rax ; colDarkersFlags
	mov [rsp + 16], rax ; colBrightersFlags

	; Load xmmDataPtr
	mov rcx, arg(3) ; pixels16
	mov rax, [rcx + 1*COMPV_YASM_REG_SZ_BYTES] ; pixels16[1]
	movdqu xmm0, [rbx + rax]
	mov rax, [rcx + 2*COMPV_YASM_REG_SZ_BYTES] ; pixels16[2]
	movdqu xmm1, [rbx + rax]
	mov rax, [rcx + 3*COMPV_YASM_REG_SZ_BYTES] ; pixels16[3]
	movdqu xmm2, [rbx + rax]
	mov rax, [rcx + 5*COMPV_YASM_REG_SZ_BYTES] ; pixels16[5]
	movdqu xmm3, [rbx + rax]
	mov rax, [rcx + 6*COMPV_YASM_REG_SZ_BYTES] ; pixels16[6]
	movdqu xmm4, [rbx + rax]
	movdqa [rsp + 808 + 1*16], xmm0
	movdqa [rsp + 808 + 2*16], xmm1
	movdqa [rsp + 808 + 3*16], xmm2
	movdqa [rsp + 808 + 5*16], xmm3
	movdqa [rsp + 808 + 6*16], xmm4
	mov rax, [rcx + 7*COMPV_YASM_REG_SZ_BYTES] ; pixels16[7]
	movdqu xmm0, [rbx + rax]
	mov rax, [rcx + 9*COMPV_YASM_REG_SZ_BYTES] ; pixels16[9]
	movdqu xmm1, [rbx + rax]
	mov rax, [rcx + 10*COMPV_YASM_REG_SZ_BYTES] ; pixels16[10]
	movdqu xmm2, [rbx + rax]
	mov rax, [rcx + 11*COMPV_YASM_REG_SZ_BYTES] ; pixels16[11]
	movdqu xmm3, [rbx + rax]
	mov rax, [rcx + 13*COMPV_YASM_REG_SZ_BYTES] ; pixels16[13]
	movdqu xmm4, [rbx + rax]
	movdqa [rsp + 808 + 7*16], xmm0
	movdqa [rsp + 808 + 9*16], xmm1
	movdqa [rsp + 808 + 10*16], xmm2
	movdqa [rsp + 808 + 11*16], xmm3
	movdqa [rsp + 808 + 13*16], xmm4
	mov rax, [rcx + 14*COMPV_YASM_REG_SZ_BYTES] ; pixels16[14]
	movdqu xmm0, [rbx + rax]
	mov rax, [rcx + 15*COMPV_YASM_REG_SZ_BYTES] ; pixels16[15]
	movdqu xmm1, [rbx + rax]
	movdqa [rsp + 808 + 14*16], xmm0
	movdqa [rsp + 808 + 15*16], xmm1

	; We could compute pixels at 1 and 9, check if at least one is darker or brighter than the candidate
	; Then, do the same for 2 and 10 etc etc ... but this is slower than whant we're doing below because
	; _mm_movemask_epi8 is cyclyvore

	;
	;	LoadDarkers
	;
	test dl, dl ; rdx was loadD, now it's free
	jz .EndOfDarkers
	; compute ddarkers16x16 and flags
	pxor xmm4, xmm4
	movdqa xmm0, xmm5
	movdqa xmm1, xmm5
	movdqa xmm2, xmm5
	movdqa xmm3, xmm5
	psubusb xmm0, [rsp + 808 + 1*16]
	psubusb xmm1, [rsp + 808 + 2*16]
	psubusb xmm2, [rsp + 808 + 3*16]
	psubusb xmm3, [rsp + 808 + 5*16]
	movdqa [rsp + 1064 + 1*16], xmm0
	movdqa [rsp + 1064 + 2*16], xmm1
	movdqa [rsp + 1064 + 3*16], xmm2
	movdqa [rsp + 1064 + 5*16], xmm3
	pcmpeqb xmm0, xmm4
	pcmpeqb xmm1, xmm4
	pcmpeqb xmm2, xmm4
	pcmpeqb xmm3, xmm4
	movdqa xmm4, [sym(k1_i8)]
	pandn xmm0, xmm4
	pandn xmm1, xmm4
	pandn xmm2, xmm4
	pandn xmm3, xmm4
	paddusb xmm0, xmm1
	paddusb xmm2, xmm3
	paddusb xmm0, xmm2
	movdqa [rsp + 296 + 1*16], xmm0 ; xmmDarkersFlags[1] = 1 + 2 + 3 + 5
	pxor xmm4, xmm4
	movdqa xmm0, xmm5
	movdqa xmm1, xmm5
	movdqa xmm2, xmm5
	movdqa xmm3, xmm5
	psubusb xmm0, [rsp + 808 + 6*16]
	psubusb xmm1, [rsp + 808 + 7*16]
	psubusb xmm2, [rsp + 808 + 9*16]
	psubusb xmm3, [rsp + 808 + 10*16]
	movdqa [rsp + 1064 + 6*16], xmm0
	movdqa [rsp + 1064 + 7*16], xmm1
	movdqa [rsp + 1064 + 9*16], xmm2
	movdqa [rsp + 1064 + 10*16], xmm3
	pcmpeqb xmm0, xmm4
	pcmpeqb xmm1, xmm4
	pcmpeqb xmm2, xmm4
	pcmpeqb xmm3, xmm4
	movdqa xmm4, [sym(k1_i8)]
	pandn xmm0, xmm4
	pandn xmm1, xmm4
	pandn xmm2, xmm4
	pandn xmm3, xmm4
	paddusb xmm0, xmm1
	paddusb xmm2, xmm3
	paddusb xmm0, xmm2
	movdqa [rsp + 296 + 6*16], xmm0 ; xmmDarkersFlags[6] = 6 + 7 + 9 + 10
	pxor xmm4, xmm4
	movdqa xmm0, xmm5
	movdqa xmm1, xmm5
	movdqa xmm2, xmm5
	movdqa xmm3, xmm5
	psubusb xmm0, [rsp + 808 + 11*16]
	psubusb xmm1, [rsp + 808 + 13*16]
	psubusb xmm2, [rsp + 808 + 14*16]
	psubusb xmm3, [rsp + 808 + 15*16]
	movdqa [rsp + 1064 + 11*16], xmm0
	movdqa [rsp + 1064 + 13*16], xmm1
	movdqa [rsp + 1064 + 14*16], xmm2
	movdqa [rsp + 1064 + 15*16], xmm3
	pcmpeqb xmm0, xmm4
	pcmpeqb xmm1, xmm4
	pcmpeqb xmm2, xmm4
	pcmpeqb xmm3, xmm4
	movdqa xmm4, [sym(k1_i8)]
	pandn xmm0, xmm4
	pandn xmm1, xmm4
	pandn xmm2, xmm4
	pandn xmm3, xmm4
	paddusb xmm0, xmm1
	paddusb xmm2, xmm3
	paddusb xmm0, xmm2
	movdqa [rsp + 296 + 11*16], xmm0 ; xmmDarkersFlags[11] = 11 + 13 + 14 + 15
	; Compute flags 0, 4, 8, 12
	movdqa xmm5, [sym(k254_u8)]
	movdqa xmm4, [rsp + 280] ; xmmNMinusOne
	movdqa xmm0, xmm5
	movdqa xmm1, xmm5
	movdqa xmm2, xmm5
	movdqa xmm3, xmm5
	pandn xmm0, [rsp + 296 + 0*16]
	pandn xmm1, [rsp + 296 + 4*16]
	pandn xmm2, [rsp + 296 + 8*16]
	pandn xmm3, [rsp + 296 + 12*16]
	paddusb xmm0, xmm1
	paddusb xmm2, xmm3
	paddusb xmm0, xmm2 ; xmm0 = 0 + 4 + 8 + 12
	paddusb xmm0, [rsp + 296 + 1*16] ; xmm0 += 1 + 2 + 3 + 5
	paddusb xmm0, [rsp + 296 + 6*16] ; xmm0 += 6 + 7 + 9 + 10
	paddusb xmm0, [rsp + 296 + 11*16] ; xmm0 += 11 + 13 + 14 + 15
	; Check the columns with at least N non-zero bits
	pcmpgtb xmm0, xmm4
	pmovmskb edx, xmm0
	test dx, dx
	jz .EndOfDarkers
	; Continue loading darkers
	mov [rsp + 8], rdx ; colDarkersFlags
	; Transpose
	COMPV_TRANSPOSE_I8_16X16_REG_T5_SSE2 rsp+1064+0*16, rsp+1064+1*16, rsp+1064+2*16, rsp+1064+3*16, rsp+1064+4*16, rsp+1064+5*16, rsp+1064+6*16, rsp+1064+7*16, rsp+1064+8*16, rsp+1064+9*16, rsp+1064+10*16, rsp+1064+11*16, rsp+1064+12*16, rsp+1064+13*16, rsp+1064+14*16, rsp+1064+15*16, xmm0, xmm1, xmm2, xmm3, xmm4
	; Flags
	pcmpeqb xmm5, xmm5 ; xmmFF
	%assign i 0
	%rep    4
		pxor xmm0, xmm0
		pxor xmm1, xmm1
		pxor xmm2, xmm2
		pxor xmm3, xmm3
		pcmpeqb xmm0, [rsp + 1064 + (0+i)*16]
		pcmpeqb xmm1, [rsp + 1064 + (1+i)*16]
		pcmpeqb xmm2, [rsp + 1064 + (2+i)*16]
		pcmpeqb xmm3, [rsp + 1064 + (3+i)*16]
		pandn xmm0, xmm5
		pandn xmm1, xmm5
		pandn xmm2, xmm5
		pandn xmm3, xmm5
		pmovmskb eax, xmm0
		pmovmskb ecx, xmm1
		mov [rsp + 24 + (0+i)*COMPV_YASM_REG_SZ_BYTES], rax
		mov [rsp + 24 + (1+i)*COMPV_YASM_REG_SZ_BYTES], rcx
		pmovmskb eax, xmm2
		pmovmskb ecx, xmm3
		mov [rsp + 24 + (2+i)*COMPV_YASM_REG_SZ_BYTES], rax
		mov [rsp + 24 + (3+i)*COMPV_YASM_REG_SZ_BYTES], rcx
		%assign i i+4
	%endrep
	
	.EndOfDarkers
	
	;
	;	LoadBrighters
	;
	test rdi, rdi ; rdi was loadB, now it's free
	jz .EndOfBrighters
	; compute Dbrighters
	pxor xmm5, xmm5
	movdqa xmm0, [rsp + 808 + 1*16]
	movdqa xmm1, [rsp + 808 + 2*16]
	movdqa xmm2, [rsp + 808 + 3*16]
	movdqa xmm3, [rsp + 808 + 5*16]
	movdqa xmm4, [rsp + 808 + 6*16]
	psubusb xmm0, xmm6
	psubusb xmm1, xmm6
	psubusb xmm2, xmm6
	psubusb xmm3, xmm6
	psubusb xmm4, xmm6
	movdqa [rsp + 1320 + 1*16], xmm0
	movdqa [rsp + 1320 + 2*16], xmm1
	movdqa [rsp + 1320 + 3*16], xmm2
	movdqa [rsp + 1320 + 5*16], xmm3
	movdqa [rsp + 1320 + 6*16], xmm4
	pcmpeqb xmm0, xmm5
	pcmpeqb xmm1, xmm5
	pcmpeqb xmm2, xmm5
	pcmpeqb xmm3, xmm5
	pcmpeqb xmm4, xmm5
	movdqa xmm5, [sym(k1_i8)]
	pandn xmm0, xmm5
	pandn xmm1, xmm5
	pandn xmm2, xmm5
	pandn xmm3, xmm5
	pandn xmm4, xmm5
	paddusb xmm0, xmm1
	paddusb xmm2, xmm3
	paddusb xmm0, xmm4
	paddusb xmm0, xmm2
	movdqa [rsp + 552 + 1*16], xmm0 ; xmmBrightersFlags[1] = 1 + 2 + 3 + 5 + 6
	pxor xmm5, xmm5
	movdqa xmm0, [rsp + 808 + 7*16]
	movdqa xmm1, [rsp + 808 + 9*16]
	movdqa xmm2, [rsp + 808 + 10*16]
	movdqa xmm3, [rsp + 808 + 11*16]
	movdqa xmm4, [rsp + 808 + 13*16]
	psubusb xmm0, xmm6
	psubusb xmm1, xmm6
	psubusb xmm2, xmm6
	psubusb xmm3, xmm6
	psubusb xmm4, xmm6
	movdqa [rsp + 1320 + 7*16], xmm0
	movdqa [rsp + 1320 + 9*16], xmm1
	movdqa [rsp + 1320 + 10*16], xmm2
	movdqa [rsp + 1320 + 11*16], xmm3
	movdqa [rsp + 1320 + 13*16], xmm4
	pcmpeqb xmm0, xmm5
	pcmpeqb xmm1, xmm5
	pcmpeqb xmm2, xmm5
	pcmpeqb xmm3, xmm5
	pcmpeqb xmm4, xmm5
	movdqa xmm5, [sym(k1_i8)]
	pandn xmm0, xmm5
	pandn xmm1, xmm5
	pandn xmm2, xmm5
	pandn xmm3, xmm5
	pandn xmm4, xmm5
	paddusb xmm0, xmm1
	paddusb xmm2, xmm3
	paddusb xmm0, xmm4
	paddusb xmm0, xmm2
	movdqa [rsp + 552 + 7*16], xmm0 ; xmmBrightersFlags[7] = 7 + 9 + 10 + 11 + 13
	pxor xmm5, xmm5
	movdqa xmm4, [sym(k1_i8)]
	movdqa xmm0, [rsp + 808 + 14*16]
	movdqa xmm1, [rsp + 808 + 15*16]
	psubusb xmm0, xmm6
	psubusb xmm1, xmm6
	movdqa [rsp + 1320 + 14*16], xmm0
	movdqa [rsp + 1320 + 15*16], xmm1
	pcmpeqb xmm0, xmm5
	pcmpeqb xmm1, xmm5
	pandn xmm0, xmm4
	pandn xmm1, xmm4
	paddusb xmm0, xmm1
	movdqa [rsp + 552 + 14*16], xmm0 ; xmmBrightersFlags[14] = 14 + 15	
	; Compute flags 0, 4, 8, 12
	movdqa xmm6, [sym(k254_u8)]
	movdqa xmm4, [rsp + 280] ; xmmNMinusOne
	movdqa xmm0, xmm6
	movdqa xmm1, xmm6
	movdqa xmm2, xmm6
	movdqa xmm3, xmm6
	pandn xmm0, [rsp + 552 + 0*16]
	pandn xmm1, [rsp + 552 + 4*16]
	pandn xmm2, [rsp + 552 + 8*16]
	pandn xmm3, [rsp + 552 + 12*16]
	paddusb xmm0, xmm1
	paddusb xmm2, xmm3
	paddusb xmm0, xmm2 ; xmm0 = 0 + 4 + 8 + 12
	paddusb xmm0, [rsp + 552 + 1*16] ; xmm0 += 1 + 2 + 3 + 5 + 6
	paddusb xmm0, [rsp + 552 + 7*16] ; xmm0 += 7 + 9 + 10 + 11 + 13
	paddusb xmm0, [rsp + 552 + 14*16] ; xmm0 += 14 + 15
	; Check the columns with at least N non-zero bits
	pcmpgtb xmm0, xmm4
	pmovmskb edx, xmm0
	test dx, dx
	jz .EndOfBrighters
	; Continue loading brighters
	mov [rsp + 16], rdx ; colBrightersFlags
	; Transpose
	COMPV_TRANSPOSE_I8_16X16_REG_T5_SSE2 rsp+1320+0*16, rsp+1320+1*16, rsp+1320+2*16, rsp+1320+3*16, rsp+1320+4*16, rsp+1320+5*16, rsp+1320+6*16, rsp+1320+7*16, rsp+1320+8*16, rsp+1320+9*16, rsp+1320+10*16, rsp+1320+11*16, rsp+1320+12*16, rsp+1320+13*16, rsp+1320+14*16, rsp+1320+15*16, xmm0, xmm1, xmm2, xmm3, xmm4
	; Flags
	pcmpeqb xmm6, xmm6 ; xmmFF
	%assign i 0
	%rep    4
		pxor xmm0, xmm0
		pxor xmm1, xmm1
		pxor xmm2, xmm2
		pxor xmm3, xmm3
		pcmpeqb xmm0, [rsp + 1320 + (0+i)*16]
		pcmpeqb xmm1, [rsp + 1320 + (1+i)*16]
		pcmpeqb xmm2, [rsp + 1320 + (2+i)*16]
		pcmpeqb xmm3, [rsp + 1320 + (3+i)*16]
		pandn xmm0, xmm6
		pandn xmm1, xmm6
		pandn xmm2, xmm6
		pandn xmm3, xmm6
		pmovmskb edi, xmm0
		pmovmskb ecx, xmm1
		mov [rsp + 152 + (0+i)*COMPV_YASM_REG_SZ_BYTES], rdi
		mov [rsp + 152 + (1+i)*COMPV_YASM_REG_SZ_BYTES], rcx
		pmovmskb edi, xmm2
		pmovmskb ecx, xmm3
		mov [rsp + 152 + (2+i)*COMPV_YASM_REG_SZ_BYTES], rdi
		mov [rsp + 152 + (3+i)*COMPV_YASM_REG_SZ_BYTES], rcx
		%assign i i+4
	%endrep

	.EndOfBrighters

	; Check if we have to compute strengths
	mov rax, [rsp + 8] ; colDarkersFlags
	or rax, [rsp + 16] ; | colBrighters
	test rax, rax
	jz .NeitherDarkersNorBrighters
	; call FastStrengths16(colBrightersFlags, colDarkersFlags, (const uint8_t*)xmmDbrighters16x16, (const uint8_t*)xmmDdarkers16x16, &fbrighters16, &fdarkers16, (uint8_t*)xmmStrengths, N);
	mov rax, rsp ; save rsp before reserving params, must not be one of the registers used to save the params (rcx, rdx, r8, r9, rdi, rsi)
	movdqa [rsp + 1576], xmm7 ; save xmmThreshold
	push rbx ; because we cannot use [rcx, rdx, r8, r9, rdi, rsi]
	COMPV_YASM_RESERVE_PARAMS rbx, 8
	mov rbx, [rax + 16] ; colBrightersFlags
	set_param 0, rbx
	mov rbx, [rax + 8] ; colDarkersFlags
	set_param 1, rbx
	lea rbx, [rax + 1320] ; xmmDbrighters16x16
	set_param 2, rbx
	lea rbx, [rax + 1064] ; xmmDdarkers16x16
	set_param 3, rbx
	lea rbx, [rax + 152] ; fbrighters16
	set_param 4, rbx
	lea rbx, [rax + 24] ; fdarkers16
	set_param 5, rbx
	mov rbx, arg(6) ; strengths
	set_param 6, rbx
	mov rbx, arg(4) ; N
	set_param 7, rbx
	call sym(FastStrengths16)
	COMPV_YASM_UNRESERVE_PARAMS
	pop rbx
	movdqa xmm7, [rsp + 1576] ; restore xmmThreshold
	.NeitherDarkersNorBrighters
	
	.LoopRowsNext
	
	mov rdx, 16
	lea rbx, [rbx + 16] ; IP += 16
	add arg(6), rdx ; strenghts += 16
	; TODO(dmi): Motion estimation not supported -> do not inc IPprev

	;-------------------
	;EndOfLooopRows
	lea rsi, [rsi - 16]
	test rsi, rsi
	jnz .LoopRows
	;-------------------

	; unalign stack and free memory
	add rsp, 8 + 8 + 8 + 8*16 + 8*16 + 16 + 16*16 + 16*16 + 16*16 + 16*16 + 16*16 + 16
	COMPV_YASM_UNALIGN_STACK

	; begin epilog
	pop rbx
	pop rdi
	pop rsi
	COMPV_YASM_RESTORE_XMM
	COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	ret
	
	


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> compv_scalar_t rbrighters
; arg(1) -> compv_scalar_t rdarkers
; arg(2) -> COMPV_ALIGNED(SSE) const uint8_t* dbrighters16x16
; arg(3) -> COMPV_ALIGNED(SSE) const uint8_t* ddarkers16x16
; arg(4) -> const compv_scalar_t(*fbrighters16)[16]
; arg(5) -> const compv_scalar_t(*fdarkers16)[16]
; arg(6) -> uint8_t* strengths16
; arg(7) -> compv_scalar_t N
; %1 -> 1: CMOV is supported, 0 CMOV not supported
; %2 -> 9: Use FAST9, 12: FAST12 ....
%macro FastStrengths16_Asm_X86_SSE41 2
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 8
	COMPV_YASM_SAVE_XMM 7 ;XMM[6-n]
	push rsi
	push rdi
	push rbx
	; end prolog

	; alloc memory
	sub rsp, 8
	; [rsp + 0] = (1 << p)

	pxor xmm0, xmm0

	; FAST hard-coded flags
	%if %2 == 9
		movdqa xmm7, [sym(Fast9Flags) + 0] ; xmmFastXFlagsLow
		movdqa xmm6, [sym(Fast9Flags) + 16]; xmm6 = xmmFastXFlagsHigh
	%elif %2 == 12
		movdqa xmm7, [sym(Fast12Flags) + 0] ; xmmFastXFlagsLow
		movdqa xmm6, [sym(Fast12Flags) + 16]; xmm6 = xmmFastXFlagsHigh
	%else
		%error "not supported"
	%endif

	xor rdx, rdx ; rdx = p = 0
	mov rax, 1
	mov [rsp + 0], rax ; (1<<p) = 1

	;----------------------
	; Loop Start
	;----------------------
	.LoopStart
		xor rcx, rcx ; rcx = maxn

		; ---------
		; Brighters
		; ---------
		mov rsi, [rsp + 0] ; (1<<p)
		test arg(0), rsi ; (rbrighters & (1 << p)) ?
		jz .EndOfBrighters
		mov rax, arg(4) ; &fbrighters16[p]
		mov rdi, [rax + rdx*COMPV_YASM_REG_SZ_BYTES] ; fbrighters16[p]

		movd xmm5, rdi
		punpcklwd xmm5, xmm5  
		pshufd xmm5, xmm5, 0 ; xmm5 = _mm_set1_epi16(fbrighters)
		movdqa xmm4, xmm5
		pand xmm5, xmm7
		pand xmm4, xmm6
		pcmpeqw xmm5, xmm7
		pcmpeqw xmm4, xmm6
		packsswb xmm5, xmm4
		pmovmskb eax, xmm5
		test ax, ax ; rax = r0
		jz .EndOfBrighters
		; Load dbrighters
		mov rbx, arg(2) ; dbrighters16x16
		mov rsi, rdx ; rsi = p
		shl rsi, 4 ; p*16 
		movdqa xmm2, [rbx + rsi]
		; Compute minimum hz
		COMPV_FEATURE_FAST_DETE_HORIZ_MIN_SSE41 Brighters, %1, %2, xmm2, xmm0, xmm1, xmm3, xmm4 ; This macro overrides rax, rsi, rdi and set the result in rcx
		.EndOfBrighters

		; ---------
		; Darkers
		; ---------
	.Darkers
		mov rsi, [rsp + 0] ; (1<<p)
		test arg(1), rsi ; (rdarkers & (1 << p)) ?
		jz .EndOfDarkers
		mov rax, arg(5) ; &fdarkers16[p]
		mov rdi, [rax + rdx*COMPV_YASM_REG_SZ_BYTES] ; fdarkers16[p]

		movd xmm5, rdi
		punpcklwd xmm5, xmm5  
		pshufd xmm5, xmm5, 0 ; xmm5 = _mm_set1_epi16(fdarkers)
		movdqa xmm4, xmm5
		pand xmm5, xmm7
		pand xmm4, xmm6
		pcmpeqw xmm5, xmm7
		pcmpeqw xmm4, xmm6
		packsswb xmm5, xmm4
		pmovmskb eax, xmm5
		test ax, ax ; rax = r0
		jz .EndOfDarkers
		; Load ddarkers16x16
		mov rbx, arg(3) ; ddarkers16x16
		mov rsi, rdx ; rsi = p
		shl rsi, 4 ; p*16 
		movdqa xmm2, [rbx + rsi]
		; Compute minimum hz
		COMPV_FEATURE_FAST_DETE_HORIZ_MIN_SSE41 Darkers, %1, %2, xmm2, xmm0, xmm1, xmm3, xmm4 ; This macro overrides rax, rsi, rdi and set the result in rcx
		.EndOfDarkers
		
	; compute strenghts[p]
	mov rax, arg(6) ; &strengths16
	mov [rax + rdx], byte cl ; strengths16[p] = maxn
	
	inc rdx ; p+= 1

	mov rax, [rsp + 0]
	shl rax, 1
	cmp rdx, 16
	mov [rsp + 0], rax
	jl .LoopStart
	;----------------

	; free memory
	add rsp, 8

	; begin epilog
	pop rbx
	pop rdi
	pop rsi
    COMPV_YASM_RESTORE_XMM
    COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	ret
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; compv_scalar_t Fast9Strengths16_Asm_CMOV_X86_SSE41(COMPV_ALIGNED(SSE) const int16_t(&dbrighters)[16], COMPV_ALIGNED(SSE) const int16_t(&ddarkers)[16], compv_scalar_t fbrighters, compv_scalar_t fdarkers, compv_scalar_t N, COMPV_ALIGNED(SSE) const uint16_t(&FastXFlags)[16])
sym(Fast9Strengths16_Asm_CMOV_X86_SSE41):
	FastStrengths16_Asm_X86_SSE41 1, 9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; compv_scalar_t Fast9Strengths16_Asm_X86_SSE41(COMPV_ALIGNED(SSE) const int16_t(&dbrighters)[16], COMPV_ALIGNED(SSE) const int16_t(&ddarkers)[16], compv_scalar_t fbrighters, compv_scalar_t fdarkers, compv_scalar_t N, COMPV_ALIGNED(SSE) const uint16_t(&FastXFlags)[16])
sym(Fast9Strengths16_Asm_X86_SSE41):
	FastStrengths16_Asm_X86_SSE41 0, 9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; compv_scalar_t Fast12Strengths16_Asm_CMOV_X86_SSE41(COMPV_ALIGNED(SSE) const int16_t(&dbrighters)[16], COMPV_ALIGNED(SSE) const int16_t(&ddarkers)[16], compv_scalar_t fbrighters, compv_scalar_t fdarkers, compv_scalar_t N, COMPV_ALIGNED(SSE) const uint16_t(&FastXFlags)[16])
sym(Fast12Strengths16_Asm_CMOV_X86_SSE41):
	FastStrengths16_Asm_X86_SSE41 1, 12

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; compv_scalar_t Fast12Strengths16_Asm_X86_SSE41(COMPV_ALIGNED(SSE) const int16_t(&dbrighters)[16], COMPV_ALIGNED(SSE) const int16_t(&ddarkers)[16], compv_scalar_t fbrighters, compv_scalar_t fdarkers, compv_scalar_t N, COMPV_ALIGNED(SSE) const uint16_t(&FastXFlags)[16])
sym(Fast12Strengths16_Asm_X86_SSE41):
	FastStrengths16_Asm_X86_SSE41 0, 12



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arg(0) -> compv_scalar_t rbrighters
; arg(1) -> compv_scalar_t rdarkers
; arg(2) -> COMPV_ALIGNED(SSE) const uint8_t* dbrighters16x32
; arg(3) -> COMPV_ALIGNED(SSE) const uint8_t* ddarkers16x32
; arg(4) -> const compv_scalar_t(*fbrighters16)[16]
; arg(5) -> const compv_scalar_t(*fdarkers16)[16]
; arg(6) -> uint8_t* Strengths32
; arg(7) -> compv_scalar_t N
; %1 -> 1: CMOV is supported, 0 CMOV not supported
; %2 -> 9: Use FAST9, 12: FAST12 ....
%macro FastStrengths32_Asm_X86_SSE41 2
	push rbp
	mov rbp, rsp
	COMPV_YASM_SHADOW_ARGS_TO_STACK 8
	COMPV_YASM_SAVE_XMM 7 ;XMM[6-n]
	push rsi
	push rdi
	push rbx
	; end prolog

	; alloc memory
	sub rsp, 8
	; [rsp + 0] = (1 << p)

	; xmm0 = xmmZeros
	pxor xmm0, xmm0

	; FAST hard-coded flags
	%if %2 == 9
		movdqa xmm7, [sym(Fast9Flags) + 0] ; xmmFastXFlagsLow
		movdqa xmm6, [sym(Fast9Flags) + 16]; xmm6 = xmmFastXFlagsHigh
	%elif %2 == 12
		movdqa xmm7, [sym(Fast12Flags) + 0] ; xmmFastXFlagsLow
		movdqa xmm6, [sym(Fast12Flags) + 16]; xmm6 = xmmFastXFlagsHigh
	%else
		%error "not supported"
	%endif

	;----------------------
	; process16
	;----------------------
	%assign j 0
	%rep 2

	xor rdx, rdx ; rdx = p = 0
	mov rax, 1
	mov [rsp + 0], rax ; (1<<p) = 1

		;----------------------
		; Loop Start
		;----------------------
		.LoopStart %+ j
			xor rcx, rcx ; rcx = maxn

			; ---------
			; Brighters
			; ---------
			mov rsi, [rsp + 0] ; (1<<p)
			test arg(0), rsi ; (rbrighters & (1 << p)) ?
			jz .EndOfBrighters %+ j
			mov rax, arg(4) ; &fbrighters16[p]
			mov rdi, [rax + rdx*COMPV_YASM_REG_SZ_BYTES] ; fbrighters16[p]
			%if j == 1
				shr rdi, 16
			%endif

			movd xmm5, rdi
			punpcklwd xmm5, xmm5  
			pshufd xmm5, xmm5, 0 ; xmm5 = _mm_set1_epi16(fbrighters)
			movdqa xmm4, xmm5
			pand xmm5, xmm7
			pand xmm4, xmm6
			pcmpeqw xmm5, xmm7
			pcmpeqw xmm4, xmm6
			; clear the high bit in the epi16, otherwise will be considered as the sign bit when saturated to u8
			psrlw xmm5, 1
			psrlw xmm4, 1
			packuswb xmm5, xmm4
			pmovmskb eax, xmm5
			test ax, ax ; rax = r0
			jz .EndOfBrighters %+ j
			; Load dbrighters
			mov rbx, arg(2) ; dbrighters16x32
			mov rsi, rdx ; rsi = p
			shl rsi, 5 ; p*32 
			movdqa xmm2, [rbx + rsi + j*16]
			; Compute minimum hz
			COMPV_FEATURE_FAST_DETE_HORIZ_MIN_SSE41 Brighters, %1, %2, xmm2, xmm0, xmm1, xmm3, xmm4 ; This macro overrides rax, rsi, rdi and set the result in rcx
			.EndOfBrighters %+ j

			; ---------
			; Darkers
			; ---------
		.Darkers %+ j
			mov rsi, [rsp + 0] ; (1<<p)
			test arg(1), rsi ; (rdarkers & (1 << p)) ?
			jz .EndOfDarkers %+ j
			mov rax, arg(5) ; &fdarkers16[p]
			mov rdi, [rax + rdx*COMPV_YASM_REG_SZ_BYTES] ; fdarkers16[p]
			%if j == 1
				shr rdi, 16
			%endif

			movd xmm5, rdi
			punpcklwd xmm5, xmm5  
			pshufd xmm5, xmm5, 0 ; xmm5 = _mm_set1_epi16(fdarkers)
			movdqa xmm4, xmm5
			pand xmm5, xmm7
			pand xmm4, xmm6
			pcmpeqw xmm5, xmm7
			pcmpeqw xmm4, xmm6
			; clear the high bit in the epi16, otherwise will be considered as the sign bit when saturated to u8
			psrlw xmm5, 1
			psrlw xmm4, 1
			packuswb xmm5, xmm4
			pmovmskb eax, xmm5
			test ax, ax ; rax = r0
			jz .EndOfDarkers %+ j
			; Load ddarkers16x16
			mov rbx, arg(3) ; ddarkers16x32
			mov rsi, rdx ; rsi = p
			shl rsi, 5 ; p*32 
			movdqa xmm2, [rbx + rsi + j*16]
			; Compute minimum hz
			COMPV_FEATURE_FAST_DETE_HORIZ_MIN_SSE41 Darkers, %1, %2, xmm2, xmm0, xmm1, xmm3, xmm4 ; This macro overrides rax, rsi, rdi and set the result in rcx
			.EndOfDarkers %+ j
		
		; compute strenghts[p]
		mov rax, arg(6) ; &Strengths32
		mov [rax + rdx + j*16], byte cl ; Strengths32[p] = maxn
	
		inc rdx ; p+= 1

		mov rax, [rsp + 0]
		shl rax, 1
		cmp rdx, 16
		mov [rsp + 0], rax
		jl .LoopStart %+ j
		;----------------

	%if j == 0
		mov rax, arg(0) ; rbrighters
		mov rcx, arg(1) ; rdarkers
		shr rax, 16
		shr rcx, 16
		mov rbx, rax
		or rbx, rcx ; rbrighters || rdarkers
		test bx, bx
		jnz .process16_continue
		; set remaining strengths to zeros
		pxor xmm0, xmm0
		mov rbx, arg(6) ; Strengths32
		movdqu [rbx + 16], xmm0
		jmp .process16_done
		.process16_continue
		mov arg(0), rax ; rbrighters >>= 16
		mov arg(1), rcx ; rdarkers >>= 16
	%endif

	%assign j j+1

	; EndOf .process16
	%endrep

	.process16_done

	; free memory
	add rsp, 8

	; begin epilog
	pop rbx
	pop rdi
	pop rsi
    COMPV_YASM_RESTORE_XMM
    COMPV_YASM_UNSHADOW_ARGS
	mov rsp, rbp
	pop rbp
	ret
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; compv_scalar_t Fast9Strengths32_Asm_CMOV_X86_SSE41(COMPV_ALIGNED(SSE) const int16_t(&dbrighters)[16], COMPV_ALIGNED(SSE) const int16_t(&ddarkers)[16], compv_scalar_t fbrighters, compv_scalar_t fdarkers, compv_scalar_t N, COMPV_ALIGNED(SSE) const uint16_t(&FastXFlags)[16])
sym(Fast9Strengths32_Asm_CMOV_X86_SSE41):
	FastStrengths32_Asm_X86_SSE41 1, 9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; compv_scalar_t Fast9Strengths32_Asm_X86_SSE41(COMPV_ALIGNED(SSE) const int16_t(&dbrighters)[16], COMPV_ALIGNED(SSE) const int16_t(&ddarkers)[16], compv_scalar_t fbrighters, compv_scalar_t fdarkers, compv_scalar_t N, COMPV_ALIGNED(SSE) const uint16_t(&FastXFlags)[16])
sym(Fast9Strengths32_Asm_X86_SSE41):
	FastStrengths32_Asm_X86_SSE41 0, 9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; compv_scalar_t Fast12Strengths32_Asm_CMOV_X86_SSE41(COMPV_ALIGNED(SSE) const int16_t(&dbrighters)[16], COMPV_ALIGNED(SSE) const int16_t(&ddarkers)[16], compv_scalar_t fbrighters, compv_scalar_t fdarkers, compv_scalar_t N, COMPV_ALIGNED(SSE) const uint16_t(&FastXFlags)[16])
sym(Fast12Strengths32_Asm_CMOV_X86_SSE41):
	FastStrengths32_Asm_X86_SSE41 1, 12

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; compv_scalar_t Fast12Strengths32_Asm_X86_SSE41(COMPV_ALIGNED(SSE) const int16_t(&dbrighters)[16], COMPV_ALIGNED(SSE) const int16_t(&ddarkers)[16], compv_scalar_t fbrighters, compv_scalar_t fdarkers, compv_scalar_t N, COMPV_ALIGNED(SSE) const uint16_t(&FastXFlags)[16])
sym(Fast12Strengths32_Asm_X86_SSE41):
	FastStrengths32_Asm_X86_SSE41 0, 12