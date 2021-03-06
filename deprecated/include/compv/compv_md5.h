/* Copyright (C) 2016-2017 Doubango Telecom <https://www.doubango.org>
* File author: Mamadou DIOP (Doubango Telecom, France).
* License: GPLv3. For commercial license please contact us.
* Source code: https://github.com/DoubangoTelecom/compv
* WebSite: http://compv.org
*/
#if !defined(_COMPV_MD5_H_)
#define _COMPV_MD5_H_

#include "compv/compv_config.h"
#include "compv/compv_common.h"
#include "compv/compv_obj.h"

#define COMPV_MD5_DIGEST_SIZE		16
#define COMPV_MD5_BLOCK_SIZE		64
#define COMPV_MD5_STRING_SIZE		(COMPV_MD5_DIGEST_SIZE << 1)

#define COMPV_MD5_EMPTY				"d41d8cd98f00b204e9800998ecf8427e"

typedef char compv_md5string_t[COMPV_MD5_STRING_SIZE + 1]; /**< Hexadecimal MD5 string. */
typedef uint8_t compv_md5digest_t[COMPV_MD5_STRING_SIZE]; /**< MD5 digest bytes. */

COMPV_NAMESPACE_BEGIN()

class COMPV_API CompVMd5 : public CompVObj
{
protected:
    CompVMd5();
public:
    virtual ~CompVMd5();
    virtual COMPV_INLINE const char* getObjectId() {
        return "CompVMd5";
    };

    COMPV_ERROR_CODE update(uint8_t const *buf, size_t len);
    COMPV_ERROR_CODE final(compv_md5digest_t digest);
    COMPV_ERROR_CODE transform(uint32_t buf[4], uint32_t const in[COMPV_MD5_DIGEST_SIZE]);
    std::string compute(const void* input = NULL, size_t size = 0);

    static std::string compute2(const void* input, size_t size);
    static COMPV_ERROR_CODE newObj(CompVPtr<CompVMd5*>* md5);

private:
    void init();

private:
    uint32_t m_buf[4];
    uint32_t m_bytes[2];
    uint32_t m_in[16];
};

COMPV_NAMESPACE_END()

#endif /* _COMPV_MD5_H_ */
