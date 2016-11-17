/* Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>
* File author: Mamadou DIOP (Doubango Telecom, France).
* License: GPLv3. For commercial license please contact us.
* Source code: https://github.com/DoubangoTelecom/compv
* WebSite: http://compv.org
*/
#if !defined(_COMPV_DRAWING_VIEWPORT_H_)
#define _COMPV_DRAWING_VIEWPORT_H_

#include "compv/base/compv_config.h"
#include "compv/base/compv_common.h"
#include "compv/base/compv_obj.h"
#include "compv/drawing/compv_common.h"

COMPV_NAMESPACE_BEGIN()

enum COMPV_VIEWPORT_SIZE_FLAG {
	COMPV_VIEWPORT_SIZE_FLAG_STATIC,
	COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_ASPECT_RATIO,
	COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_MIN,
	COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_MAX
};

struct CompViewportSizeFlags {
	COMPV_VIEWPORT_SIZE_FLAG x, y, width, height;
	CompViewportSizeFlags(
		COMPV_VIEWPORT_SIZE_FLAG x_ = COMPV_VIEWPORT_SIZE_FLAG_STATIC,
		COMPV_VIEWPORT_SIZE_FLAG y_ = COMPV_VIEWPORT_SIZE_FLAG_STATIC,
		COMPV_VIEWPORT_SIZE_FLAG width_ = COMPV_VIEWPORT_SIZE_FLAG_STATIC,
		COMPV_VIEWPORT_SIZE_FLAG height_ = COMPV_VIEWPORT_SIZE_FLAG_STATIC) : x(x_), y(y_), width(width_), height(height_) { }
	static CompViewportSizeFlags makeStatic() {
		return CompViewportSizeFlags(COMPV_VIEWPORT_SIZE_FLAG_STATIC, COMPV_VIEWPORT_SIZE_FLAG_STATIC, COMPV_VIEWPORT_SIZE_FLAG_STATIC, COMPV_VIEWPORT_SIZE_FLAG_STATIC);
	}
	static CompViewportSizeFlags makeDynamicAspectRatio() { 
		return CompViewportSizeFlags(COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_ASPECT_RATIO, COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_ASPECT_RATIO, COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_ASPECT_RATIO, COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_ASPECT_RATIO);
	}
	static CompViewportSizeFlags makeDynamicFullscreen() {
		return CompViewportSizeFlags(COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_MIN, COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_MIN, COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_MAX, COMPV_VIEWPORT_SIZE_FLAG_DYNAMIC_MAX);
	}
	bool isStatic()const { return (x == COMPV_VIEWPORT_SIZE_FLAG_STATIC) && (y == COMPV_VIEWPORT_SIZE_FLAG_STATIC) && (width == COMPV_VIEWPORT_SIZE_FLAG_STATIC) && (height == COMPV_VIEWPORT_SIZE_FLAG_STATIC); }
	bool isDynamic()const { return (x != COMPV_VIEWPORT_SIZE_FLAG_STATIC) && (y != COMPV_VIEWPORT_SIZE_FLAG_STATIC) && (width != COMPV_VIEWPORT_SIZE_FLAG_STATIC) && (height != COMPV_VIEWPORT_SIZE_FLAG_STATIC); }
};

class CompVViewport;
typedef CompVPtr<CompVViewport* > CompVViewportPtr;
typedef CompVViewportPtr* CompVViewportPtrPtr;

class COMPV_DRAWING_API CompVViewport : public CompVObj
{
protected:
	CompVViewport(const CompViewportSizeFlags& sizeFlags, size_t x = 0, size_t y = 0, size_t width = 0, size_t height = 0);
public:
	virtual ~CompVViewport();
	COMPV_GET_OBJECT_ID("CompVViewport");

	COMPV_INLINE size_t x()const { return m_nX; }
	COMPV_INLINE size_t y()const { return m_nY; }
	COMPV_INLINE size_t width()const { return m_nWidth; }
	COMPV_INLINE size_t height()const { return m_nHeight; }
	COMPV_INLINE const CompVDrawingRatio& aspectRatio()const { return m_PixelAspectRatio; }
	COMPV_INLINE const CompViewportSizeFlags& sizeFlags()const { return m_SizeFlags; }

	COMPV_ERROR_CODE setPixelAspectRatio(const CompVDrawingRatio& ratio);

	static COMPV_ERROR_CODE toRect(const CompVViewportPtr& viewport, CompVDrawingRect* rect);

	static COMPV_ERROR_CODE viewport(const CompVDrawingRect& rcSource, const CompVDrawingRect& rcDest, const CompVViewportPtr& currViewport, CompVDrawingRect* rcViewport);

	static COMPV_ERROR_CODE newObj(CompVViewportPtrPtr viewport, const CompViewportSizeFlags& sizeFlags, size_t x = 0, size_t y = 0, size_t width = 0, size_t height = 0);

private:
	static COMPV_ERROR_CODE letterBoxRect(const CompVDrawingRect& rcSrc, const CompVDrawingRect& rcDst, CompVDrawingRect& rcResult);
	static COMPV_ERROR_CODE correctAspectRatio(const CompVDrawingRect& rcSrc, const CompVDrawingRatio& srcPAR, CompVDrawingRect& rcResult);

private:
	COMPV_VS_DISABLE_WARNINGS_BEGIN(4251 4267)
	size_t m_nX;
	size_t m_nY;
	size_t m_nWidth;
	size_t m_nHeight;
	CompVDrawingRatio m_PixelAspectRatio;
	CompViewportSizeFlags m_SizeFlags;
	COMPV_VS_DISABLE_WARNINGS_END()
};

COMPV_NAMESPACE_END()

#endif /* _COMPV_DRAWING_VIEWPORT_H_ */
