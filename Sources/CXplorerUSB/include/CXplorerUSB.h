#ifndef CXPLORER_USB_H
#define CXPLORER_USB_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to an opened Guitar Hero X-plorer (or any XInput) USB device.
typedef struct XplorerDevice XplorerDevice;

typedef enum {
    XPLORER_OK           = 0,
    XPLORER_NOT_FOUND    = -1, // no matching VID/PID device enumerated
    XPLORER_OPEN_FAILED  = -2, // open/SetConfiguration/interface claim failed
    XPLORER_BUSY         = -3, // kIOReturnExclusiveAccess even with seize
    XPLORER_IO_ERROR     = -4, // unexpected pipe error
    XPLORER_DISCONNECTED = -5, // device went away mid-operation
    XPLORER_ABORTED      = -6, // xplorer_abort() interrupted a blocking read
} XplorerResult;

// Match the first VID/PID device, USBDeviceOpenSeize it, SetConfiguration(1)
// if unconfigured, claim the XInput input interface (class 0xFF, subclass
// 0x5D, protocol 0x01; falls back to the first interface with an interrupt IN
// pipe), and locate the interrupt IN/OUT pipes.
// Returns NULL on failure with *outErr set.
XplorerDevice *xplorer_open(uint16_t vid, uint16_t pid, XplorerResult *outErr);

// Blocking ReadPipe on the interrupt IN pipe. Returns bytes read (> 0) or a
// negative XplorerResult. NOTE: interrupt pipes do not support read timeouts
// (ReadPipeTO is bulk-only); call xplorer_abort() from another thread to
// unblock a pending read.
int xplorer_read(XplorerDevice *dev, uint8_t *buf, uint32_t bufLen);

// AbortPipe on the IN pipe: a pending xplorer_read returns XPLORER_ABORTED.
// Safe to call from any thread.
void xplorer_abort(XplorerDevice *dev);

// WritePipe on the interrupt OUT pipe (e.g. LED command {0x01, 0x03, code}).
// Returns XPLORER_OK or a negative XplorerResult. No-op error if the device
// exposes no OUT pipe.
int xplorer_write(XplorerDevice *dev, const uint8_t *data, uint32_t len);

// Release interface + device and free the handle. NULL-safe.
void xplorer_close(XplorerDevice *dev);

// Human-readable name for an XplorerResult (for logging).
const char *xplorer_result_name(int result);

#ifdef __cplusplus
}
#endif

#endif /* CXPLORER_USB_H */
