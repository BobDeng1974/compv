/* Copyright (C) 2016-2019 Doubango Telecom <https://www.doubango.org>
* File author: Mamadou DIOP (Doubango Telecom, France).
* License: GPLv3. For commercial license please contact us.
* Source code: https://github.com/DoubangoTelecom/compv
* WebSite: http://compv.org
*/
#if !defined(_COMPV_BASE_IMAGE_UTILS_H_)
#define _COMPV_BASE_IMAGE_UTILS_H_

#include "compv/base/compv_config.h"
#include "compv/base/compv_common.h"

COMPV_NAMESPACE_BEGIN()

class COMPV_BASE_API CompVImageUtils
{
public:
    static COMPV_ERROR_CODE bestStride(size_t stride, size_t *bestStride);
    static COMPV_ERROR_CODE sizeForPixelFormat(COMPV_SUBTYPE ePixelFormat, size_t width, size_t height, size_t *size);
    static COMPV_ERROR_CODE planeSizeForPixelFormat(COMPV_SUBTYPE ePixelFormat, size_t planeId, size_t imgWidth, size_t imgHeight, size_t *imgSize);
    static COMPV_ERROR_CODE planeSizeForPixelFormat(COMPV_SUBTYPE ePixelFormat, size_t planeId, size_t imgWidth, size_t imgHeight, size_t *compWidth, size_t *compHeight);
    static COMPV_ERROR_CODE bitsCountForPixelFormat(COMPV_SUBTYPE ePixelFormat, size_t* bitsCount);
	static COMPV_ERROR_CODE planeBitsCountForPixelFormat(COMPV_SUBTYPE ePixelFormat, size_t planeId, size_t* bitsCount);
    static COMPV_ERROR_CODE planeCount(COMPV_SUBTYPE ePixelFormat, size_t *planeCount);
    static COMPV_ERROR_CODE isPlanePacked(COMPV_SUBTYPE ePixelFormat, bool *packed);
	static COMPV_ERROR_CODE copy(COMPV_SUBTYPE ePixelFormat, const void* inPtr, size_t inWidth, size_t inHeight, size_t inStride, void* outPtr, size_t outWidth, size_t outHeight, size_t outStride);

private:
};

COMPV_NAMESPACE_END()

#endif /* _COMPV_BASE_IMAGE_UTILS_H_ */
