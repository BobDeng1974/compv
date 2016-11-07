/* Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>
* File author: Mamadou DIOP (Doubango Telecom, France).
* License: GPLv3. For commercial license please contact us.
* Source code: https://github.com/DoubangoTelecom/compv
* WebSite: http://compv.org
*/
#if !defined(_COMPV_DRAWING_CANVAS_SKIA_H_)
#define _COMPV_DRAWING_CANVAS_SKIA_H_

#include "compv/base/compv_config.h"
#if HAVE_SKIA
#include "compv/base/compv_common.h"
#include "compv/base/compv_obj.h"
#include "compv/base/compv_mat.h"
#include "compv/drawing/compv_canvas.h"

#if defined(_COMPV_API_H_)
#error("This is a private file and must not be part of the API")
#endif

#include <string>

COMPV_NAMESPACE_BEGIN()

class CompVCanvasSkia;
typedef CompVPtr<CompVCanvasSkia* > CompVCanvasSkiaPtr;
typedef CompVCanvasSkiaPtr* CompVCanvasSkiaPtrPtr;

class CompVCanvasSkia : public CompVCanvas
{
protected:
	CompVCanvasSkia();
public:
	virtual ~CompVCanvasSkia();
	virtual COMPV_INLINE const char* getObjectId() {
		return "CompVCanvasSkia";
	};

	virtual COMPV_ERROR_CODE test();

	static COMPV_ERROR_CODE newObj(CompVCanvasSkiaPtrPtr skiaCanvas);

protected:

private:
	COMPV_VS_DISABLE_WARNINGS_BEGIN(4251 4267)

	COMPV_VS_DISABLE_WARNINGS_END()
};

COMPV_NAMESPACE_END()

#endif /* HAVE_SKIA */

#endif /* _COMPV_DRAWING_CANVAS_SKIA_H_ */