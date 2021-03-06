/* Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>
* File author: Mamadou DIOP (Doubango Telecom, France).
* License: GPLv3. For commercial license please contact us.
* Source code: https://github.com/DoubangoTelecom/compv
* WebSite: http://compv.org
*/
#if !defined(_COMPV_SIMD_GLOBALS_H_)
#define _COMPV_SIMD_GLOBALS_H_

#include "compv/compv_config.h"
#include "compv/compv_common.h"

#if defined(_COMPV_API_H_)
#error("This is a private file and must not be part of the API")
#endif

COMPV_EXTERNC_BEGIN()

extern COMPV_API COMPV_ALIGN_DEFAULT() uint8_t k_0_0_0_255_u8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int8_t k1_i8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() compv::compv_float64_t k1_f64[];
extern COMPV_API COMPV_ALIGN_DEFAULT() compv::compv_float64_t km1_f64[];
extern COMPV_API COMPV_ALIGN_DEFAULT() compv::compv_float64_t km1_0_f64[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int8_t k2_i8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int8_t k3_i8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int8_t k5_i8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int8_t k16_i8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int8_t k127_i8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint8_t k128_u8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint8_t k254_u8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint8_t k255_u8[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int16_t k16_i16[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int16_t k128_i16[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int16_t k255_i16[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int16_t k7120_i16[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int16_t k8912_i16[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int16_t k4400_i16[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int32_t k_0_2_4_6_0_2_4_6_i32[];
extern COMPV_API COMPV_ALIGN_DEFAULT() compv::compv_float64_t ksqrt2_f64[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint64_t kAVXMaskstore_0_u64[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint64_t kAVXMaskstore_0_1_u64[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint32_t kAVXMaskstore_0_u32[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint64_t kAVXMaskzero_3_u64[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint64_t kAVXMaskzero_2_3_u64[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint64_t kAVXMaskzero_1_2_3_u64[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int32_t kAVXPermutevar8x32_AEBFCGDH_i32[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int32_t kAVXPermutevar8x32_ABCDDEFG_i32[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int32_t kAVXPermutevar8x32_CDEFFGHX_i32[];
extern COMPV_API COMPV_ALIGN_DEFAULT() int32_t kAVXPermutevar8x32_XXABBCDE_i32[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint32_t kAVXFloat64MaskAbs[];
extern COMPV_API COMPV_ALIGN_DEFAULT() uint32_t kAVXFloat64MaskNegate[];


COMPV_EXTERNC_END()

#endif /* _COMPV_SIMD_GLOBALS_H_ */
