#include "zcm/transport.h"
#include "zcm/transport_registrar.h"
#include "zcm/transport_register.hpp"
#include "zcm/util/debug.h"

#include "util/TimeUtil.hpp"

#include <cassert>
#include <cstring>

// Define this the class name you want
#define ZCM_TRANS_CLASSNAME TransportNonblockTest
#define MTU (1<<20)

using u8  = uint8_t;
using u16 = uint16_t;
using u32 = uint32_t;
using u64 = uint64_t;

struct ZCM_TRANS_CLASSNAME : public zcm_trans_t
{
    char channel[33];
    char message[MTU];
    size_t messageSize;
    bool used = false;

    ZCM_TRANS_CLASSNAME(zcm_url_t *url)
    {
        trans_type = ZCM_NONBLOCKING;
        vtbl = &methods;
    }

    ~ZCM_TRANS_CLASSNAME()
    {
        // TODO shutdown
    }

    /********************** METHODS **********************/
    size_t getMtu()
    {
        return MTU;
    }

    int sendmsg(zcm_msg_t msg)
    {
        if (used)
            return ZCM_EAGAIN;

        strcpy(channel, msg.channel);
        memcpy(message, msg.buf, msg.len);
        messageSize = msg.len;
        used = true;

        return ZCM_EOK;
    }

    // Note: this transport simply listens to all channels
    int recvmsgEnable(const char *channel, bool enable)
    {
        return ZCM_EOK;
    }

    int recvmsg(zcm_msg_t *msg, int timeout)
    {
        if (!used)
            return ZCM_EAGAIN;

        msg->utime = TimeUtil::utime();
        msg->channel = channel;
        msg->len = messageSize;
        msg->buf = message;
        used = false;
        return ZCM_EOK;

    }

    int update()
    {
        return ZCM_EOK;
    }

    /********************** STATICS **********************/
    static zcm_trans_methods_t methods;
    static ZCM_TRANS_CLASSNAME *cast(zcm_trans_t *zt)
    {
        assert(zt->vtbl == &methods);
        return (ZCM_TRANS_CLASSNAME*)zt;
    }

    static size_t _getMtu(zcm_trans_t *zt)
    { return cast(zt)->getMtu(); }

    static int _sendmsg(zcm_trans_t *zt, zcm_msg_t msg)
    { return cast(zt)->sendmsg(msg); }

    static int _recvmsgEnable(zcm_trans_t *zt, const char *channel, bool enable)
    { return cast(zt)->recvmsgEnable(channel, enable); }

    static int _recvmsg(zcm_trans_t *zt, zcm_msg_t *msg, int timeout)
    { return cast(zt)->recvmsg(msg, timeout); }

    static int _update(zcm_trans_t *zt)
    { return cast(zt)->update(); }

    static void _destroy(zcm_trans_t *zt)
    { delete cast(zt); }

    static const TransportRegister reg;
};


zcm_trans_methods_t ZCM_TRANS_CLASSNAME::methods = {
    &ZCM_TRANS_CLASSNAME::_getMtu,
    &ZCM_TRANS_CLASSNAME::_sendmsg,
    &ZCM_TRANS_CLASSNAME::_recvmsgEnable,
    &ZCM_TRANS_CLASSNAME::_recvmsg,
    &ZCM_TRANS_CLASSNAME::_update,
    &ZCM_TRANS_CLASSNAME::_destroy,
};

static zcm_trans_t *create(zcm_url_t *url)
{
    return new ZCM_TRANS_CLASSNAME(url);
}

// Register this transport with ZCM
const TransportRegister ZCM_TRANS_CLASSNAME::reg(
    "nonblock-test", "Test impl for non-block transport", create);
