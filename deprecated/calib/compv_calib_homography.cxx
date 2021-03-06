/* Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>
* File author: Mamadou DIOP (Doubango Telecom, France).
* License: GPLv3. For commercial license please contact us.
* Source code: https://github.com/DoubangoTelecom/compv
* WebSite: http://compv.org
*/
#include "compv/calib/compv_calib_homography.h"
#include "compv/math/compv_math_eigen.h"
#include "compv/math/compv_math_matrix.h"
#include "compv/math/compv_math_stats.h"
#include "compv/compv_engine.h"

#include <vector>

#if !defined (COMPV_PRNG11)
#	define COMPV_PRNG11 1
#endif

#if !defined (COMPV_HOMOGRAPHY_OUTLIER_THRESHOLD)
#	define	COMPV_HOMOGRAPHY_OUTLIER_THRESHOLD 30
#endif
#define COMPV_PROMOTE_ZEROS(_h_, _i_) if (CompVEigen<T>::isCloseToZero((_h_)[(_i_)])) (_h_)[(_i_)] = 0;

#if COMPV_PRNG11
#	include <random>
#endif

#define COMPV_RANSAC_HOMOGRAPHY_MIN_SAMPLES_PER_THREAD	(4*5) // number of samples per thread

COMPV_NAMESPACE_BEGIN()

#define kModuleNameHomography "Homography"

template class CompVHomography<compv_float64_t >;
template class CompVHomography<compv_float32_t >;

template<typename T>
struct CompVTempArraysCountInliers {
    CompVPtrArray(T) b_;
    CompVPtrArray(T) mseb_;
    CompVPtrArray(T) a_;
    CompVPtrArray(T) msea_;
    CompVPtrArray(T) Hinv_;
    CompVPtrArray(T) distances_;
};

template<typename T>
static COMPV_ERROR_CODE computeH(const CompVPtrArray(T) &src, const CompVPtrArray(T) &dst, CompVPtrArray(T) &H, bool promoteZeros = false);
template<typename T>
static COMPV_ERROR_CODE ransac(const CompVPtrArray(T) &src, const CompVPtrArray(T) &dst, CompVPtrArray(size_t)& inliers, T& variance, size_t threadsCount);
template<typename T>
static COMPV_ERROR_CODE countInliers(const CompVPtrArray(T) &src, const CompVPtrArray(T) &dst, const CompVPtrArray(T) &H, CompVTempArraysCountInliers<T>& tempArrays, size_t &inliersCount, CompVPtrArray(size_t)& inliers, T &variance);

// Homography 'double' is faster because EigenValues/EigenVectors computation converge faster (less residual error)
// src: 3xN homogeneous array (X, Y, Z=1). N-cols with N >= 4. The N points must not be colinear.
// dst: 3xN homogeneous array (X, Y, Z=1). N-cols with N >= 4. The N points must not be colinear.
// H: (3 x 3) array. Will be created if NULL.
// src and dst must have the same number of columns.
template<class T>
COMPV_ERROR_CODE CompVHomography<T>::find(const CompVPtrArray(T) &src, const CompVPtrArray(T) &dst, CompVPtrArray(T) &H, COMPV_MODELEST_TYPE model /*= COMPV_MODELEST_TYPE_RANSAC*/)
{
    // Homography requires at least #4 points
    // src and dst must be 2-rows array. 1st row = X, 2nd-row = Y
    COMPV_CHECK_EXP_RETURN(!src || !dst || src->rows() != 3 || dst->rows() != 3 || src->cols() < 4 || src->cols() != dst->cols(), COMPV_ERROR_CODE_E_INVALID_PARAMETER);

    // Make sure coordinates are homogeneous 2D
    size_t numPoints_ = src->cols();
    const T* srcz_ = src->ptr(2);
    const T* dstz_ = dst->ptr(2);
    for (size_t i = 0; i < numPoints_; ++i) {
        if (srcz_[i] != 1 || dstz_[i] != 1) {
            COMPV_CHECK_CODE_RETURN(COMPV_ERROR_CODE_E_INVALID_PARAMETER);
        }
    }

    // No estimation model selected -> compute homography using all points (inliers + outliers)
    if (model == COMPV_MODELEST_TYPE_NONE) {
        COMPV_CHECK_CODE_RETURN(computeH<T>(src, dst, H, true));
        return COMPV_ERROR_CODE_S_OK;
    }

    CompVPtrArray(size_t) bestInliers_;
    size_t bestInliersCount_ = 0;
    size_t threadsCount_ = 1;
    CompVPtr<CompVThreadDispatcher11* >threadDisp = CompVEngine::getThreadDispatcher11();
    if (threadDisp && threadDisp->getThreadsCount() > 1 && !threadDisp->isMotherOfTheCurrentThread()) {
        threadsCount_ = COMPV_MATH_MIN(numPoints_ / COMPV_RANSAC_HOMOGRAPHY_MIN_SAMPLES_PER_THREAD, size_t(threadDisp->getThreadsCount()));
    }
    if (threadsCount_ > 1) {
        std::vector<T> variances_(threadsCount_); // variance used when number of inliers are equal
        std::vector<CompVPtrArray(size_t)> inliers_(threadsCount_);
        CompVAsyncTaskIds taskIds;
        taskIds.reserve(threadsCount_);
        auto funcPtr = [&](const CompVPtrArray(T) &src, const CompVPtrArray(T) &dst, size_t threadIdx_) -> COMPV_ERROR_CODE {
            return ransac<T>(src, dst, inliers_[threadIdx_], variances_[threadIdx_], threadsCount_);
        };
        // Run threads
        for (size_t threadIdx_ = 0; threadIdx_ < threadsCount_; ++threadIdx_) {
            COMPV_CHECK_CODE_RETURN(threadDisp->invoke(std::bind(funcPtr, src, dst, threadIdx_), taskIds));
        }
        // Find best homography index for the threads
        size_t bestHomographyIndex_ = 0;
        T bestVariance_ = T(FLT_MAX);
        for (size_t threadIdx_ = 0; threadIdx_ < threadsCount_; ++threadIdx_) {
            COMPV_CHECK_CODE_RETURN(threadDisp->waitOne(taskIds[threadIdx_]));
            if (inliers_[threadIdx_] && (inliers_[threadIdx_]->cols() > bestInliersCount_ || (inliers_[threadIdx_]->cols() == bestInliersCount_ && variances_[threadIdx_] < bestVariance_))) {
                bestVariance_ = variances_[threadIdx_];
                bestInliersCount_ = inliers_[threadIdx_]->cols();
                bestHomographyIndex_ = threadIdx_;
            }
        }
        bestInliers_ = inliers_[bestHomographyIndex_];
    }
    else {
        T variance_;
        COMPV_CHECK_CODE_RETURN(ransac(src, dst, bestInliers_, variance_, 1));
        bestInliersCount_ = bestInliers_ ? bestInliers_->cols() : 0;
    }

    // RANSAC failed to find more than #4 inliers (must never happen)
    // -> compute homography using all points
    if (bestInliersCount_ < 4) {
        COMPV_DEBUG_INFO_EX(kModuleNameHomography, "Not enought inliers(< 4). InlinersCount = %lu, NumPoints = %lu, threadsCount = %lu", bestInliersCount_, numPoints_, threadsCount_);
        COMPV_CHECK_CODE_RETURN(computeH<T>(src, dst, H, true));
        return COMPV_ERROR_CODE_S_OK;
    }

    if (bestInliersCount_ == numPoints_) {
#if defined(DEBUG_) || defined(DEBUG)
        COMPV_DEBUG_INFO_EX(kModuleNameHomography, "All %llu points are inliers", numPoints_);
#endif
        // Copy H
        COMPV_CHECK_CODE_RETURN(computeH<T>(src, dst, H, true));
        return COMPV_ERROR_CODE_S_OK;
    }
    else {

        // Compute final H using inliers only
        CompVPtrArray(T) srcinliers_;
        CompVPtrArray(T) dstinliers_;
        COMPV_CHECK_CODE_RETURN(CompVArray<T>::newObjAligned(&srcinliers_, 3, bestInliersCount_));
        COMPV_CHECK_CODE_RETURN(CompVArray<T>::newObjAligned(&dstinliers_, 3, bestInliersCount_));
        T* srcinliersx_ = const_cast<T*>(srcinliers_->ptr(0));
        T* srcinliersy_ = const_cast<T*>(srcinliers_->ptr(1));
        T* srcinliersz_ = const_cast<T*>(srcinliers_->ptr(2));
        T* dstinliersx_ = const_cast<T*>(dstinliers_->ptr(0));
        T* dstinliersy_ = const_cast<T*>(dstinliers_->ptr(1));
        T* dstinliersz_ = const_cast<T*>(dstinliers_->ptr(2));

        size_t idx;
        const size_t* inliersIdx_ = bestInliers_->ptr();
        const T* srcx_ = src->ptr(0);
        const T* srcy_ = src->ptr(1);
        const T* dstx_ = dst->ptr(0);
        const T* dsty_ = dst->ptr(1);
        for (size_t i = 0; i < bestInliersCount_; ++i) {
            idx = inliersIdx_[i];
            srcinliersx_[i] = srcx_[idx], srcinliersy_[i] = srcy_[idx], srcinliersz_[i] = 1;
            dstinliersx_[i] = dstx_[idx], dstinliersy_[i] = dsty_[idx], dstinliersz_[i] = 1;
        }

        COMPV_CHECK_CODE_RETURN(computeH<T>(srcinliers_, dstinliers_, H, true));
        return COMPV_ERROR_CODE_S_OK;
    }
}

template<typename T>
static COMPV_ERROR_CODE ransac(const CompVPtrArray(T) &src, const CompVPtrArray(T) &dst, CompVPtrArray(size_t)& inliers, T& variance, size_t threadsCount)
{
    COMPV_CHECK_EXP_RETURN(!threadsCount, COMPV_ERROR_CODE_E_INVALID_PARAMETER);
    const T *srcx_, *srcy_, *dstx1_, *dsty1_;

    variance = T(FLT_MAX);

    srcx_ = src->ptr(0);
    srcy_ = src->ptr(1);
    dstx1_ = dst->ptr(0);
    dsty1_ = dst->ptr(1);

    size_t k_ = src->cols(); // total number of elements (must be > 4)
    float p_ = 0.99f; // probability for inlier (TODO(dmi): try with 0.95f which is more realistic)
    size_t d_ = (size_t)(p_ * k_); // minimum number of inliers to stop the tries
    size_t subset_ = 4; // subset size: 2 for line, 3 for plane, 4 for homography, 8 for essential / essential matrix
    float e_ = 0.70f; // outliers ratio (70% is a worst case, will be updated) = 1 - (inliersCount/total)
    size_t n_; // maximum number of tries
    size_t t_; // number of tries

    size_t inliersCount_, bestInlinersCount_ = 0;
    T variance_; // Using variance instead of standard deviation because it's the same result as we are doing comparison
    bool colinear;
    CompVPtrArray(T) Hsubset_;

    size_t idx0, idx1, idx2, idx3;
#if COMPV_PRNG11
#	if 0
    std::random_device rd_;
    std::mt19937 prng_ { rd_() };
#	else
    // CompVThread::getIdCurrent() must return different number for each thread otherwise we'll generate the same suite of numbers
    // We're not using a random device number (std::random_device) in order to generate the same suite of numbers for each thread everytime
    std::mt19937 prng_(CompVThread::getIdCurrent());
#	endif
    std::uniform_int_distribution<> unifd_ { 0, static_cast<int>(k_ - 1) };
#else
    srand(CompVThread::getIdCurrent());
    uint32_t rand4[4];
#endif

    n_ = ((static_cast<size_t>(logf(1 - p_) / logf(1 - powf(1 - e_, static_cast<float>(subset_))))) / threadsCount) + 1;
    t_ = 0;

    CompVPtrArray(size_t) inliersubset_; // inliers indexes
    COMPV_CHECK_CODE_RETURN(CompVArray<size_t>::newObjAligned(&inliersubset_, 1, k_));

    CompVPtrArray(T) srcsubset_;
    CompVPtrArray(T) dstsubset_;
    COMPV_CHECK_CODE_RETURN(CompVArray<T>::newObjAligned(&srcsubset_, 3, subset_));
    COMPV_CHECK_CODE_RETURN(CompVArray<T>::newObjAligned(&dstsubset_, 3, subset_));
    T* srcsubsetx_ = const_cast<T*>(srcsubset_->ptr(0));
    T* srcsubsety_ = const_cast<T*>(srcsubset_->ptr(1));
    T* srcsubsetz_ = const_cast<T*>(srcsubset_->ptr(2));
    T* dstsubsetx_ = const_cast<T*>(dstsubset_->ptr(0));
    T* dstsubsety_ = const_cast<T*>(dstsubset_->ptr(1));
    T* dstsubsetz_ = const_cast<T*>(dstsubset_->ptr(2));
    // 2D planar
    srcsubsetz_[0] = srcsubsetz_[1] = srcsubsetz_[2] = srcsubsetz_[3] = 1;
    dstsubsetz_[0] = dstsubsetz_[1] = dstsubsetz_[2] = dstsubsetz_[3] = 1;

    CompVTempArraysCountInliers<T> tempArrays_;

    while (t_ < n_ && bestInlinersCount_ < d_) {
        // Generate the random points
#if COMPV_PRNG11
        idx0 = static_cast<uint32_t>(unifd_(prng_));
        do {
            idx1 = static_cast<uint32_t>(unifd_(prng_));
        }
        while (idx1 == idx0);
        do {
            idx2 = static_cast<uint32_t>(unifd_(prng_));
        }
        while (idx2 == idx0 || idx2 == idx1);
        do {
            idx3 = static_cast<uint32_t>(unifd_(prng_));
        }
        while (idx3 == idx0 || idx3 == idx1 || idx3 == idx2);
#else
        idx0 = static_cast<uint32_t>(rand()) % k_;
        do {
            idx1 = static_cast<uint32_t>(rand()) % k_;
        }
        while (idx1 == idx0);
        do {
            idx2 = static_cast<uint32_t>(rand()) % k_;
        }
        while (idx2 == idx0 || idx2 == idx1);
        do {
            idx3 = static_cast<uint32_t>(rand()) % k_;
        }
        while (idx3 == idx0 || idx3 == idx1 || idx3 == idx2);
#endif

        // Set the #4 random points (src)
        srcsubsetx_[0] = srcx_[idx0],	srcsubsetx_[1] = srcx_[idx1],	srcsubsetx_[2] = srcx_[idx2],	srcsubsetx_[3] = srcx_[idx3];
        srcsubsety_[0] = srcy_[idx0],	srcsubsety_[1] = srcy_[idx1],	srcsubsety_[2] = srcy_[idx2],	srcsubsety_[3] = srcy_[idx3];

        // Reject colinear points
        // TODO(dmi): doesn't worth it -> colinear points will compute a wrong homography with too much outliers -> not an issue
        COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::isColinear2D(srcsubset_, colinear));
        if (colinear) {
            COMPV_DEBUG_INFO_EX(kModuleNameHomography, "ignore colinear points ...");
            ++t_; // to avoid endless loops
            continue;
        }
        // Set the #4 random points (dst)
        dstsubsetx_[0] = dstx1_[idx0], dstsubsetx_[1] = dstx1_[idx1], dstsubsetx_[2] = dstx1_[idx2], dstsubsetx_[3] = dstx1_[idx3];
        dstsubsety_[0] = dsty1_[idx0], dstsubsety_[1] = dsty1_[idx1], dstsubsety_[2] = dsty1_[idx2], dstsubsety_[3] = dsty1_[idx3];

        // Compute Homography using the #4 random points selected above (subset)
        COMPV_CHECK_CODE_RETURN(computeH<T>(srcsubset_, dstsubset_, Hsubset_));

        // Count outliers using all points and current homography using the inliers only
        COMPV_CHECK_CODE_RETURN(countInliers<T>(src, dst, Hsubset_, tempArrays_, inliersCount_, inliersubset_, variance_));

        if (inliersCount_ >= subset_ && (inliersCount_ > bestInlinersCount_ || (inliersCount_ == bestInlinersCount_ && variance_ < variance))) {
            bestInlinersCount_ = inliersCount_;
            variance = variance_;
            // Copy inliers
            COMPV_CHECK_CODE_RETURN(CompVArray<size_t>::newObjAligned(&inliers, 1, inliersCount_));
            CompVMem::copyNTA(const_cast<size_t*>(inliers->ptr(0)), inliersubset_->ptr(0), (inliersCount_ * sizeof(size_t)));
        }

        // update outliers ratio
        e_ = (1 - (COMPV_MATH_MAX(1, inliersCount_) / static_cast<float>(k_))); // "inliersCount_" == 0 lead to NaN for "n_"
        // update total tries
        n_ = (static_cast<size_t>(logf(1 - p_) / logf(1 - powf(1 - e_, static_cast<float>(subset_)))) / threadsCount) + 1;

        ++t_;
    }

    if (bestInlinersCount_ < subset_) { // not enought points ?
        inliers = NULL; // If the user provided a valid array, reset it
        // Not an error if there more threads
        COMPV_DEBUG_INFO_EX(kModuleNameHomography, "[RANSAC] Not enought inliers(< 4). InlinersCount = %lu, k = %lu", bestInlinersCount_, k_);
    }

    return COMPV_ERROR_CODE_S_OK;
}

template<typename T>
static COMPV_ERROR_CODE computeH(const CompVPtrArray(T) &src, const CompVPtrArray(T) &dst, CompVPtrArray(T) &H, bool promoteZeros /*= false*/)
{
    // Private function, do not check input parameters
    COMPV_ERROR_CODE err_ = COMPV_ERROR_CODE_S_OK;
    const CompVArray<T >* src_ = *src;
    const CompVArray<T >* dst_ = *dst;
    const T *srcX_, *srcY_, *srcZ_, *dstX_, *dstY_, *dstZ_;
    T *row_;
    size_t numPoints_ = src_->cols();

    srcX_ = src_->ptr(0);
    srcY_ = src_->ptr(1);
    srcZ_ = dst_->ptr(2);
    dstX_ = dst_->ptr(0);
    dstY_ = dst_->ptr(1);
    dstZ_ = dst_->ptr(2);

    /* Resolving Ha = b equation (4-point algorithm) */
    // -> Ah = 0 (homogeneous equation), with h a 9x1 vector
    // -> h is in the nullspace of A, means eigenvector with the smallest eigenvalue. If the equation is exactly determined then, the smallest eigenvalue must be equal to zero.

    /* Normalize the points as described at https://en.wikipedia.org/wiki/Eight-point_algorithm#How_it_can_be_solved */
    T srcTX_, srcTY_, dstTX_, dstTY_; // translation (to the centroid) values
    T srcScale_, dstScale_; // scaling factors to have mean distance to the centroid = sqrt(2)
    COMPV_CHECK_CODE_RETURN(CompVMathStats<T>::normalize2D_hartley(srcX_, srcY_, numPoints_, &srcTX_, &srcTY_, &srcScale_));
    COMPV_CHECK_CODE_RETURN(CompVMathStats<T>::normalize2D_hartley(dstX_, dstY_, numPoints_, &dstTX_, &dstTY_, &dstScale_));

    /* Build transformation matrixes (T1 and T2) using the translation and scaling values from the normalization process */
    // Translation(t) to centroid then scaling(s) operation:
    // -> b = (a+t)s = as+ts = as+t' with t'= ts
    // T matrix
    //	scale	0		-Tx*scale
    //	0		scale	-Ty*scale
    //	0		0		1
    CompVPtrArray(T) T1_;
    CompVPtrArray(T) srcn_;
    COMPV_CHECK_CODE_RETURN(err_ = CompVArray<T>::newObjAligned(&T1_, 3, 3));
    // Normalize src_: srcn_ = T.src_
    row_ = const_cast<T*>(T1_->ptr(0)), row_[0] = srcScale_, row_[1] = 0, row_[2] = -srcTX_ * srcScale_;
    row_ = const_cast<T*>(T1_->ptr(1)), row_[0] = 0, row_[1] = srcScale_, row_[2] = -srcTY_ * srcScale_;
    row_ = const_cast<T*>(T1_->ptr(2)), row_[0] = 0, row_[1] = 0, row_[2] = 1;
    COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::mulAB(T1_, src, srcn_));
    // Normilize dst_: dstn_ = T.dst_
    CompVPtrArray(T) T2_;
    CompVPtrArray(T) dstn_;
    COMPV_CHECK_CODE_RETURN(err_ = CompVArray<T>::newObjAligned(&T2_, 3, 3));
    row_ = const_cast<T*>(T2_->ptr(0)), row_[0] = dstScale_, row_[1] = 0, row_[2] = -dstTX_ * dstScale_;
    row_ = const_cast<T*>(T2_->ptr(1)), row_[0] = 0, row_[1] = dstScale_, row_[2] = -dstTY_ * dstScale_;
    row_ = const_cast<T*>(T2_->ptr(2)), row_[0] = 0, row_[1] = 0, row_[2] = 1;
    COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::mulAB(T2_, dst, dstn_));

    // Build M for homogeneous equation: Mh = 0
    CompVPtrArray(T) M_;
    COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::buildHomographyEqMatrix(srcn_->ptr(0), srcn_->ptr(1), dstn_->ptr(0), dstn_->ptr(1), M_, numPoints_));

    // Build symmetric matrix S = M*M
    CompVPtrArray(T) S_; // temp symmetric array
    COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::mulAtA(M_, S_));

    // Find eigenvalues and eigenvectors (no sorting and vectors in rows instead of columns)
    CompVPtrArray(T) D_; // 9x9 diagonal matrix containing the eigenvalues
    CompVPtrArray(T) Qt_; // 9x9 matrix containing the eigenvectors (rows) - transposed
    COMPV_CHECK_CODE_RETURN(CompVEigen<T>::findSymm(S_, D_, Qt_, false, true, false));

    // Find index of the smallest eigenvalue (this code is required because findSymm() is called without sorting for speed-up)
    // Eigenvector corresponding to the smallest eigenvalue is the nullspace of M and equal h (homogeneous equation: Ah = 0)
    signed minIndex_ = 8;
    T minEigenValue_ = *D_->ptr(8);
    for (signed j = 7; j >= 0; --j) { // starting at the end as the smallest value is probably there
        if (*D_->ptr(j, j) < minEigenValue_) {
            minEigenValue_ = *D_->ptr(j, j);
            minIndex_ = j;
        }
    }

    // Set homography values (normalized) using the egeinvector at "minIndex_"
    if (!H || H->rows() != 3 || H->cols() != 3) {
        COMPV_CHECK_CODE_RETURN(err_ = CompVArray<T>::newObjAligned(&H, 3, 3));
    }
    const T* q_ = Qt_->ptr(minIndex_);
    T* hn0_ = const_cast<T*>(H->ptr(0));
    T* hn1_ = const_cast<T*>(H->ptr(1));
    T* hn2_ = const_cast<T*>(H->ptr(2));
    // Hn = H normalized
    hn0_[0] = q_[0];
    hn0_[1] = q_[1];
    hn0_[2] = q_[2];
    hn1_[0] = q_[3];
    hn1_[1] = q_[4];
    hn1_[2] = q_[5];
    hn2_[0] = q_[6];
    hn2_[1] = q_[7];
    hn2_[2] = q_[8];

    // change T1 = T1^
    row_ = const_cast<T*>(T1_->ptr(0)), row_[0] = srcScale_, row_[1] = 0, row_[2] = 0;
    row_ = const_cast<T*>(T1_->ptr(1)), row_[0] = 0, row_[1] = srcScale_, row_[2] = 0;
    row_ = const_cast<T*>(T1_->ptr(2)), row_[0] = -srcTX_ * srcScale_, row_[1] = -srcTY_ * srcScale_, row_[2] = 1;

    // change T2 = T2* - Matrix to obtain "a" from "b" (transformed by equation Ta=b)
    // -> b = as+t' (see above for t'=ts)
    // -> a = b(1/s)-t'(1/s) = b(1/s)+t'' whith t'' = -t'/s = -(ts)/s = -t
    // { 1 / s, 0, +tx },
    // { 0, 1 / s, +ty },
    // { 0, 0, 1 }
    row_ = const_cast<T*>(T2_->ptr(0)), row_[0] = 1 / dstScale_, row_[1] = 0, row_[2] = dstTX_;
    row_ = const_cast<T*>(T2_->ptr(1)), row_[0] = 0, row_[1] = 1 / dstScale_, row_[2] = dstTY_;
    row_ = const_cast<T*>(T2_->ptr(2)), row_[0] = 0, row_[1] = 0, row_[2] = 1;

    // De-normalize
    // HnAn = Bn, with An=T1A and Bn=T2B are normalized points
    // ->HnT1A = T2B
    // ->T2^HnT1A = T2^T2B = B
    // ->(T2^HnT1)A = B -> H'A = B whith H' = T2^HnT1 our final homography matrix
    // T2^HnT1 = T2^(T1*Hn*)* = T2^(T3Hn*)* with T3 = T1*
    COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::mulABt(T1_, H, M_));
    COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::mulABt(T2_, M_, H));

    if (promoteZeros) {
        COMPV_PROMOTE_ZEROS(hn0_, 0);
        COMPV_PROMOTE_ZEROS(hn0_, 1);
        COMPV_PROMOTE_ZEROS(hn0_, 2);
        COMPV_PROMOTE_ZEROS(hn1_, 0);
        COMPV_PROMOTE_ZEROS(hn1_, 1);
        COMPV_PROMOTE_ZEROS(hn1_, 2);
        COMPV_PROMOTE_ZEROS(hn2_, 0);
        COMPV_PROMOTE_ZEROS(hn2_, 1);
    }

    // Scale H to make it homogeneous (Z = 1)
    T h22_ = hn2_[2] ? (T(1) / hn2_[2]) : T(1);
    hn0_[0] *= h22_;
    hn0_[1] *= h22_;
    hn0_[2] *= h22_;
    hn1_[0] *= h22_;
    hn1_[1] *= h22_;
    hn1_[2] *= h22_;
    hn2_[0] *= h22_;
    hn2_[1] *= h22_;
    hn2_[2] *= h22_; // should be #1

    return err_;
}

template<typename T>
static COMPV_ERROR_CODE countInliers(const CompVPtrArray(T) &src, const CompVPtrArray(T) &dst, const CompVPtrArray(T) &H, CompVTempArraysCountInliers<T>& tempArrays, size_t &inliersCount, CompVPtrArray(size_t)& inliers, T &variance)
{
    // Private function, do not check input parameters
    size_t numPoints_ = src->cols();
    inliersCount = 0;
    variance = T(FLT_MAX);

    size_t* indexes_ = const_cast<size_t*>(inliers->ptr());

    // Apply H to the source and compute mse: Ha = b, mse(Ha, b)
    COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::mulAB(H, src, tempArrays.b_));
    COMPV_CHECK_CODE_RETURN(CompVMathStats<T>::mse2D_homogeneous(tempArrays.b_->ptr(0), tempArrays.b_->ptr(1), tempArrays.b_->ptr(2), dst->ptr(0), dst->ptr(1), tempArrays.mseb_, numPoints_));

    // Apply H* to the destination and compute mse: a = H*b, mse(a, H*b)
    COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::invA3x3(H, tempArrays.Hinv_));
    COMPV_CHECK_CODE_RETURN(CompVMatrix<T>::mulAB(tempArrays.Hinv_, dst, tempArrays.a_));
    COMPV_CHECK_CODE_RETURN(CompVMathStats<T>::mse2D_homogeneous(tempArrays.a_->ptr(0), tempArrays.a_->ptr(1), tempArrays.a_->ptr(2), src->ptr(0), src->ptr(1), tempArrays.msea_, numPoints_));

    // Sum the MSE values and build the inliers
    const T* mseaPtr_ = tempArrays.msea_->ptr();
    const T* msebPtr_ = tempArrays.mseb_->ptr();
    T sumd_ = 0; // sum deviations
    T d_;
    COMPV_CHECK_CODE_RETURN(CompVArray<T>::newObjAligned(&tempArrays.distances_, 1, numPoints_)); // "inliersCount" values only are needed but for now we don't now how many we have
    T* distancesPtr_ = const_cast<T*>(tempArrays.distances_->ptr());
    for (size_t i_ = 0; i_ < numPoints_; ++i_) {
        d_ = mseaPtr_[i_] + msebPtr_[i_];
        if (d_ < COMPV_HOMOGRAPHY_OUTLIER_THRESHOLD) {
            indexes_[inliersCount] = i_;
            distancesPtr_[inliersCount] = d_;
            ++inliersCount;
            sumd_ += d_;
        }
    }

    // Compute standard deviation (or variance)
    if (inliersCount > 1) {
        T mean_ = T(sumd_ / inliersCount);
        CompVMathStats<T>::variance(distancesPtr_, inliersCount, &mean_, &variance);
    }

    return COMPV_ERROR_CODE_S_OK;
}

COMPV_NAMESPACE_END()