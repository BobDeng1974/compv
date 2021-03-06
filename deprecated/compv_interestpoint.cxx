/* Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>
* File author: Mamadou DIOP (Doubango Telecom, France).
* License: GPLv3. For commercial license please contact us.
* Source code: https://github.com/DoubangoTelecom/compv
* WebSite: http://compv.org
*/
#include "compv/compv_interestpoint.h"
#include "compv/compv_mem.h"
#include "compv/compv_engine.h"
#include "compv/math/compv_math_utils.h"
#include "compv/compv_debug.h"

COMPV_NAMESPACE_BEGIN()

#define COMPV_QUICKSORT_MIN_SAMPLES_PER_THREAD 200*100

static void sortByStrengthRange(CompVBoxInterestPoint* self, intptr_t left, intptr_t right);
static COMPV_ERROR_CODE sortByStrengthRangeAsynExec(const struct compv_asynctoken_param_xs* pc_params);
static void scaleAndRoundAndGetAngleSinCos_C(COMPV_ALIGNED(x) const float* xf, COMPV_ALIGNED(x) const float *yf, COMPV_ALIGNED(x) const float *sf, COMPV_ALIGNED(x) const float* angleInDegree, COMPV_ALIGNED(x) int32_t* xi, COMPV_ALIGNED(x) int32_t* yi, COMPV_ALIGNED(x) float* cos, COMPV_ALIGNED(x) float* sin, compv_scalar_t count);

CompVBoxInterestPoint::CompVBoxInterestPoint(size_t nCapacity /*= 0*/, bool bLockable /*= false*/)
    : CompVBox<CompVInterestPoint >(nCapacity, bLockable)
{

}

CompVBoxInterestPoint::~CompVBoxInterestPoint()
{

}

COMPV_ERROR_CODE CompVBoxInterestPoint::sortByStrength()
{
    sortByStrengthRange(this, 0, (intptr_t)size() - 1);
    return COMPV_ERROR_CODE_S_OK;
}

COMPV_ERROR_CODE CompVBoxInterestPoint::retainBest(size_t count)
{
    COMPV_CHECK_CODE_RETURN(sortByStrength());
    resize(count);
    return COMPV_ERROR_CODE_S_OK;
}

COMPV_ERROR_CODE CompVBoxInterestPoint::eraseTooCloseToBorder(int32_t img_width, int32_t img_height, int32_t border_size)
{
    if (m_nSize > 0) {
        const CompVInterestPoint* p;
        float w = (float)img_width, h = (float)img_height, b = (float)border_size;
        for (size_t i = 0; i < size();) {
            p = ptr(i);
            if ((p->x < b || (p->x + b) >= w || (p->y < b) || (p->y + b) >= h)) {
                erase(ptr(i));
            }
            else {
                ++i;
            }
        }
    }
    return COMPV_ERROR_CODE_S_OK;
}

COMPV_ERROR_CODE CompVBoxInterestPoint::newObj(CompVPtr<CompVBoxInterestPoint* >* box, size_t nCapacity /*= 0*/, bool bLockable /*= false*/)
{
    if (sizeof(CompVBoxInterestPoint) > kCompVBoxItemMaxSize) {
        COMPV_DEBUG_ERROR("Boxing is only allowed on object with size < %u, you're boxing an object with size = %lu", (unsigned)kCompVBoxItemMaxSize, sizeof(CompVBoxInterestPoint));
        return COMPV_ERROR_CODE_E_INVALID_CALL;
    }
    COMPV_CHECK_EXP_RETURN(!box, COMPV_ERROR_CODE_E_INVALID_PARAMETER);
    CompVPtr<CompVBoxInterestPoint* > box_;

    box_ = new CompVBoxInterestPoint(nCapacity, bLockable);
    COMPV_CHECK_EXP_RETURN(!box_, COMPV_ERROR_CODE_E_OUT_OF_MEMORY);
    COMPV_CHECK_EXP_RETURN(bLockable && !box_->m_Mutex, COMPV_ERROR_CODE_E_OUT_OF_MEMORY);
    COMPV_CHECK_EXP_RETURN(nCapacity && !box_->m_pMem, COMPV_ERROR_CODE_E_OUT_OF_MEMORY);

    *box = box_;

    return COMPV_ERROR_CODE_S_OK;
}

static void sortByStrengthRange(CompVBoxInterestPoint* self, intptr_t left, intptr_t right)
{
    CompVPtr<CompVThreadDispatcher* >threadDisp = CompVEngine::getThreadDispatcher();
    int32_t threadsCount = threadDisp ? threadDisp->getThreadsCount() : 0;
    uint32_t threadIdx0 = UINT_MAX, threadIdx1 = UINT_MAX;
    const CompVInterestPoint pivot = *self->ptr((left + right) >> 1);
    CompVInterestPoint atk, *ati = self->ptr(left), *atj = self->ptr(right);
    const CompVInterestPoint *ati_ = ati, *atj_ = atj;
    while (ati <= atj) {
        while (ati->strength > pivot.strength) {
            ++ati;
        }
        while (pivot.strength > atj->strength) {
            --atj;
        }
        if (ati > atj) {
            break;
        }
        atk = *ati;
        *ati = *atj;
        *atj = atk;
        ++ati;
        --atj;
    }
    intptr_t i = left + (ati - ati_);
    intptr_t j = right + (atj - atj_);
    if (left < j) {
        if (threadsCount > 2 && (j - left) > COMPV_QUICKSORT_MIN_SAMPLES_PER_THREAD && !threadDisp->isMotherOfTheCurrentThread()) {
            threadIdx0 = threadDisp->getThreadIdxForNextToCurrentCore();
            COMPV_CHECK_CODE_ASSERT(threadDisp->execute(threadIdx0, COMPV_TOKENIDX0, sortByStrengthRangeAsynExec,
                                    COMPV_ASYNCTASK_SET_PARAM_ASISS(self, left, j),
                                    COMPV_ASYNCTASK_SET_PARAM_NULL()));
        }
        else {
            sortByStrengthRange(self, left, j);
        }
    }
    if (i < right) {
        if (threadsCount > 2 && (right - i) > COMPV_QUICKSORT_MIN_SAMPLES_PER_THREAD && !threadDisp->isMotherOfTheCurrentThread()) {
            threadIdx1 = threadDisp->getThreadIdxForNextToCurrentCore() + 1;
            COMPV_CHECK_CODE_ASSERT(threadDisp->execute(threadIdx1, COMPV_TOKENIDX1, sortByStrengthRangeAsynExec,
                                    COMPV_ASYNCTASK_SET_PARAM_ASISS(self, i, right),
                                    COMPV_ASYNCTASK_SET_PARAM_NULL()));
        }
        else {
            sortByStrengthRange(self, i, right);
        }
    }
    if (threadIdx0 != UINT_MAX) {
        COMPV_CHECK_CODE_ASSERT(threadDisp->wait(threadIdx0, COMPV_TOKENIDX0));
    }
    if (threadIdx1 != UINT_MAX) {
        COMPV_CHECK_CODE_ASSERT(threadDisp->wait(threadIdx1, COMPV_TOKENIDX1));
    }
}

static COMPV_ERROR_CODE sortByStrengthRangeAsynExec(const struct compv_asynctoken_param_xs* pc_params)
{
    CompVBoxInterestPoint* self = COMPV_ASYNCTASK_GET_PARAM_ASIS(pc_params[0].pcParamPtr, CompVBoxInterestPoint*);
    intptr_t left = COMPV_ASYNCTASK_GET_PARAM_ASIS(pc_params[1].pcParamPtr, intptr_t);
    intptr_t right = COMPV_ASYNCTASK_GET_PARAM_ASIS(pc_params[2].pcParamPtr, intptr_t);
    sortByStrengthRange(self, left, right);
    return COMPV_ERROR_CODE_S_OK;
}

// Scale the point: xf *= sf, yf *= sf
// Round the point: xi = round(xf), yi = round(yf)
// Convert the angle to radian: angleInRad = degToRad(angleInDegree)
// Get the angle cos and sin: cos = cos(angleInRad), sin = sin(angleInRad)
void CompVInterestPointScaleAndRoundAndGetAngleSinCos(COMPV_ALIGNED(x) const float* xf, COMPV_ALIGNED(x) const float *yf, COMPV_ALIGNED(x) const float *sf, COMPV_ALIGNED(x) const float* angleInDegree, COMPV_ALIGNED(x) int32_t* xi, COMPV_ALIGNED(x) int32_t* yi, COMPV_ALIGNED(x) float* cos, COMPV_ALIGNED(x) float* sin, compv_scalar_t count)
{
    void(*scaleAndRoundAndGetAngleSinCos)(COMPV_ALIGNED(x) const float* xf, COMPV_ALIGNED(x) const float *yf, COMPV_ALIGNED(x) const float *sf, COMPV_ALIGNED(x) const float* angleInDegree, COMPV_ALIGNED(x) int32_t* xi, COMPV_ALIGNED(x) int32_t* yi, COMPV_ALIGNED(x) float* cos, COMPV_ALIGNED(x) float* sin, compv_scalar_t count)
        = scaleAndRoundAndGetAngleSinCos_C;

    scaleAndRoundAndGetAngleSinCos(xf, yf, sf, angleInDegree, xi, yi, cos, sin, count);
}

static void scaleAndRoundAndGetAngleSinCos_C(COMPV_ALIGNED(x) const float* xf, COMPV_ALIGNED(x) const float *yf, COMPV_ALIGNED(x) const float *sf, COMPV_ALIGNED(x) const float* angleInDegree, COMPV_ALIGNED(x) int32_t* xi, COMPV_ALIGNED(x) int32_t* yi, COMPV_ALIGNED(x) float* cos, COMPV_ALIGNED(x) float* sin, compv_scalar_t count)
{
    COMPV_DEBUG_INFO_CODE_NOT_OPTIMIZED(); // TODO: SIMD
    float fx, fy, angleInRad;
    for (compv_scalar_t i = 0; i < count; ++i) {
        // Scale
        fx = (xf[i] * sf[i]);
        fy = (yf[i] * sf[i]);
        // Convert the angle from degree to radian
        angleInRad = COMPV_MATH_DEGREE_TO_RADIAN_FLOAT(angleInDegree[i]);
        // Get angle's cos and sin
        cos[i] = ::cos(angleInRad);
        sin[i] = ::sin(angleInRad);
        // Round the point
        xi[i] = COMPV_MATH_ROUNDFU_2_INT(fx, int32_t);
        yi[i] = COMPV_MATH_ROUNDFU_2_INT(fy, int32_t);
    }
}

COMPV_NAMESPACE_END()
