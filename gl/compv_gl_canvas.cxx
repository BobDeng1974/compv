/* Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>
* File author: Mamadou DIOP (Doubango Telecom, France).
* License: GPLv3. For commercial license please contact us.
* Source code: https://github.com/DoubangoTelecom/compv
* WebSite: http://compv.org
*/
#include "compv/gl/compv_gl_canvas.h"
#include "compv/gl/compv_gl_headers.h"
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES)

COMPV_NAMESPACE_BEGIN()

CompVGLCanvas::CompVGLCanvas(CompVGLFboPtr ptrFBO)
    : CompVCanvas()
    , m_bEmpty(true)
    , m_ptrFBO(ptrFBO)
{

}

CompVGLCanvas::~CompVGLCanvas()
{

}

COMPV_ERROR_CODE CompVGLCanvas::drawText(const void* textPtr, size_t textLengthInBytes, int x, int y) /*Overrides(CompVCanvasInterface)*/
{
    COMPV_CHECK_EXP_RETURN(!textPtr || !textLengthInBytes, COMPV_ERROR_CODE_E_INVALID_PARAMETER);
    COMPV_GL_FBO_AUTOBIND(*m_ptrFBO);
	COMPV_CHECK_CODE_RETURN(COMPV_ERROR_CODE_E_NOT_IMPLEMENTED);
    unMakeEmpty();
    return COMPV_ERROR_CODE_S_OK;
}

COMPV_ERROR_CODE CompVGLCanvas::drawLines(const compv_float32_t* x0, const compv_float32_t* y0, const compv_float32_t* x1, const compv_float32_t* y1, size_t count) /*Overrides(CompVCanvasInterface)*/
{   
	COMPV_CHECK_CODE_RETURN(drawLines2(x0, y0, x1, y1, count));
	return COMPV_ERROR_CODE_S_OK;
}

COMPV_ERROR_CODE CompVGLCanvas::drawInterestPoints(const std::vector<CompVInterestPoint >& interestPoints) /*Overrides(CompVCanvasInterface)*/
{
	if (interestPoints.empty()) {
		return COMPV_ERROR_CODE_S_OK;
	}
	if (!m_ptrDrawPoints) {
		COMPV_CHECK_CODE_RETURN(CompVGLDrawPoints::newObj(&m_ptrDrawPoints));
	}
	CompVGLPoint2D* glMemPoints_ = NULL, *glMemPoint_;
	COMPV_ERROR_CODE err = COMPV_ERROR_CODE_S_OK;
	const GLfloat(*color)[3];

	glMemPoints_ = reinterpret_cast<CompVGLPoint2D*>(CompVMem::malloc(interestPoints.size() * sizeof(CompVGLPoint2D)));
	COMPV_CHECK_EXP_RETURN(!glMemPoints_, (err = COMPV_ERROR_CODE_E_OUT_OF_MEMORY), "Failed to allocation GL points");

	glMemPoint_ = glMemPoints_;
	for (std::vector<CompVInterestPoint >::const_iterator it = interestPoints.begin(); it != interestPoints.end(); ++it, ++glMemPoint_) {
		// x, y
		glMemPoint_->position[0] = static_cast<GLfloat>((*it).x);
		glMemPoint_->position[1] = static_cast<GLfloat>((*it).y);
		// r, g, b
		color = &kCompVGLRandomColors[rand() % kCompVGLRandomColorsCount];
		glMemPoint_->color[0] = (*color)[0];
		glMemPoint_->color[1] = (*color)[1];
		glMemPoint_->color[2] = (*color)[2];
	}

	COMPV_CHECK_CODE_BAIL(err = m_ptrFBO->bind());
	COMPV_CHECK_CODE_BAIL(err = m_ptrDrawPoints->points(glMemPoints_, static_cast<GLsizei>(interestPoints.size())));

bail:
	COMPV_CHECK_CODE_NOP(m_ptrFBO->unbind());
	CompVMem::free(reinterpret_cast<void**>(&glMemPoints_));
	unMakeEmpty();
	return err;
}

COMPV_ERROR_CODE CompVGLCanvas::drawMatches(const compv_float32_t* x0, const compv_float32_t* y0, const compv_float32_t* x1, const compv_float32_t* y1, size_t count) /*Internal*/
{
	COMPV_CHECK_CODE_RETURN(drawLines2(x0, y0, x1, y1, count, COMPV_GL_LINE_TYPE_MATCH));
	return COMPV_ERROR_CODE_S_OK;
}

COMPV_ERROR_CODE CompVGLCanvas::close()
{
	m_ptrDrawPoints = NULL;
	m_ptrDrawLines = NULL;
    if (m_ptrFBO) {
		COMPV_CHECK_CODE_NOP(m_ptrFBO->close());
    }
    return COMPV_ERROR_CODE_S_OK;
}

COMPV_ERROR_CODE CompVGLCanvas::drawLines2(const compv_float32_t* x0, const compv_float32_t* y0, const compv_float32_t* x1, const compv_float32_t* y1, size_t count, COMPV_GL_LINE_TYPE type COMPV_DEFAULT(COMPV_GL_LINE_TYPE_SIMPLE))  /*Private*/
{
	COMPV_CHECK_EXP_RETURN(!x0 || !y0 || !x1 || !y1 || !count, COMPV_ERROR_CODE_E_INVALID_PARAMETER);

	if (!m_ptrDrawLines) {
		COMPV_CHECK_CODE_RETURN(CompVGLDrawLines::newObj(&m_ptrDrawLines));
	}
	CompVGLPoint2D* glMemLines_ = NULL, *glMemLine_;
	COMPV_ERROR_CODE err = COMPV_ERROR_CODE_S_OK;
	const GLfloat(*color)[3];

	glMemLines_ = reinterpret_cast<CompVGLPoint2D*>(CompVMem::malloc((count << 1) * sizeof(CompVGLPoint2D)));
	COMPV_CHECK_EXP_RETURN(!glMemLines_, (err = COMPV_ERROR_CODE_E_OUT_OF_MEMORY), "Failed to allocation GL points");

	glMemLine_ = glMemLines_;
	for (size_t i = 0; i < count; i += 1, glMemLine_ += 2) {
		// x0, y0, x1, y1 : (x0, y0) -> (x1, y1)
		glMemLine_->position[0] = static_cast<GLfloat>(x0[i]);
		glMemLine_->position[1] = static_cast<GLfloat>(y0[i]);
		(glMemLine_ + 1)->position[0] = static_cast<GLfloat>(x1[i]);
		(glMemLine_ + 1)->position[1] = static_cast<GLfloat>(y1[i]);
		// r, g, b
		color = &kCompVGLRandomColors[rand() % kCompVGLRandomColorsCount];
		(glMemLine_ + 1)->color[0] = glMemLine_->color[0] = (*color)[0];
		(glMemLine_ + 1)->color[1] = glMemLine_->color[1] = (*color)[1];
		(glMemLine_ + 1)->color[2] = glMemLine_->color[2] = (*color)[2];
	}

	COMPV_CHECK_CODE_BAIL(err = m_ptrFBO->bind());
	COMPV_CHECK_CODE_BAIL(err = m_ptrDrawLines->draw(glMemLines_, static_cast<GLsizei>(count << 1), type));

bail:
	COMPV_CHECK_CODE_NOP(m_ptrFBO->unbind());
	unMakeEmpty();
	CompVMem::free(reinterpret_cast<void**>(&glMemLines_));
	return err;
}

COMPV_ERROR_CODE CompVGLCanvas::newObj(CompVGLCanvasPtrPtr canvas, CompVGLFboPtr ptrFBO)
{
    COMPV_CHECK_EXP_RETURN(!canvas || !ptrFBO, COMPV_ERROR_CODE_E_INVALID_PARAMETER);
    CompVGLCanvasPtr canvas_ = new CompVGLCanvas(ptrFBO);
    COMPV_CHECK_EXP_RETURN(!canvas_, COMPV_ERROR_CODE_E_OUT_OF_MEMORY);
    *canvas = canvas_;
    return COMPV_ERROR_CODE_S_OK;
}

COMPV_NAMESPACE_END()

#endif /* defined(HAVE_OPENGL) || defined(HAVE_OPENGLES) */
