#include <compv/compv_api.h>

#include "../common.h"

using namespace compv;

#define FAST_THRESHOLD				10
#define FAST_NONMAXIMA				true
#define ORB_MAX_FEATURES			-1
#define ORB_PYRAMID_LEVELS			8
#define ORB_PYRAMID_SCALEFACTOR		0.83f
#define ORB_PYRAMID_SCALE_TYPE		COMPV_SCALE_TYPE_BILINEAR
#define ORB_LOOOP_COUNT				1
#define ORB_DESC_MD5_FLOAT			"7a46dadf433e1e6d49f7fb60a6626064"
#define ORB_DESC_MD5_FLOAT_MT		"7f4f847671fb369774120c5ad8aad334" // multithreaded (convolution create temporary memory) - FIXME: set borders to zero
#define ORB_DESC_MD5_FXP			"8b5f9ec67cb5accf848a65f82c6b6b61"
#define ORB_DESC_MD5_FXP_MT			"ac6b661432e1bcd28cccd3e2096e91de"
#define JPEG_IMG					"C:/Projects/GitHub/pan360/tests/sphere_mapping/7019363969_a80a5d6acc_o.jpg" // voiture (2000*1000 = 2times more bytes than 720p)

COMPV_ERROR_CODE TestORB()
{
    CompVPtr<CompVCornerDete* > dete; // feature detector
    CompVPtr<CompVCornerDesc* > desc; // feature descriptor
    CompVPtr<CompVImage *> image;
    CompVPtr<CompVBoxInterestPoint* > interestPoints;
    CompVPtr<CompVArray<uint8_t>* > descriptions;
    int32_t val32;
    bool valBool;
    float valFloat;
    uint64_t timeStart, timeEnd;

    // Decode the jpeg image
    COMPV_CHECK_CODE_RETURN(CompVImageDecoder::decodeFile(JPEG_IMG, &image));
    // Convert the image to grayscal (required by feture detectors)
    COMPV_CHECK_CODE_RETURN(image->convert(COMPV_PIXEL_FORMAT_GRAYSCALE, &image));

    // Create the ORB feature detector
    COMPV_CHECK_CODE_RETURN(CompVCornerDete::newObj(COMPV_ORB_ID, &dete));
    // Create the ORB feature descriptor
    COMPV_CHECK_CODE_RETURN(CompVCornerDesc::newObj(COMPV_ORB_ID, &desc));
    COMPV_CHECK_CODE_RETURN(desc->attachDete(dete)); // attach detector to make sure we'll share context

    // Set the default values for the detector
    val32 = FAST_THRESHOLD;
    COMPV_CHECK_CODE_RETURN(dete->set(COMPV_ORB_SET_INT32_FAST_THRESHOLD, &val32, sizeof(val32)));
    valBool = FAST_NONMAXIMA;
    COMPV_CHECK_CODE_RETURN(dete->set(COMPV_ORB_SET_BOOL_FAST_NON_MAXIMA_SUPP, &valBool, sizeof(valBool)));
    val32 = ORB_PYRAMID_LEVELS;
    COMPV_CHECK_CODE_RETURN(dete->set(COMPV_ORB_SET_INT32_PYRAMID_LEVELS, &val32, sizeof(val32)));
    val32 = ORB_PYRAMID_SCALE_TYPE;
    COMPV_CHECK_CODE_RETURN(dete->set(COMPV_ORB_SET_INT32_PYRAMID_SCALE_TYPE, &val32, sizeof(val32)));
    valFloat = ORB_PYRAMID_SCALEFACTOR;
    COMPV_CHECK_CODE_RETURN(dete->set(COMPV_ORB_SET_FLT32_PYRAMID_SCALE_FACTOR, &valFloat, sizeof(valFloat)));
    val32 = ORB_MAX_FEATURES;
    COMPV_CHECK_CODE_RETURN(dete->set(COMPV_ORB_SET_INT32_MAX_FEATURES, &val32, sizeof(val32)));

    timeStart = CompVTime::getNowMills();
    for (int i = 0; i < ORB_LOOOP_COUNT; ++i) {
        // Detect keypoints
        COMPV_CHECK_CODE_RETURN(dete->process(image, interestPoints));

        // Describe keypoints
        COMPV_CHECK_CODE_RETURN(desc->process(image, interestPoints, &descriptions));
    }
    timeEnd = CompVTime::getNowMills();
    COMPV_DEBUG_INFO("Elapsed time = [[[ %llu millis ]]]", (timeEnd - timeStart));

    // Compute Descriptions MD5
    const std::string md5 = descriptions ? arrayMD5<uint8_t>(descriptions) : "";
    bool ok;
    if (CompVEngine::isMathFixedPoint()) {
        ok = (md5 == (CompVEngine::isMultiThreadingEnabled() ? ORB_DESC_MD5_FXP_MT : ORB_DESC_MD5_FXP));
    }
    else {
        ok = (md5 == (CompVEngine::isMultiThreadingEnabled() ? ORB_DESC_MD5_FLOAT_MT : ORB_DESC_MD5_FLOAT));
    }
    COMPV_CHECK_EXP_RETURN(!ok, COMPV_ERROR_CODE_E_UNITTEST_FAILED);

    return COMPV_ERROR_CODE_S_OK;
}