#include "include/CXplorerUSB.h"

// IOUSBLib is deprecated in favor of IOUSBHost.framework, but it remains the
// only userspace USB API with seize semantics and is verified working on
// macOS 26 (see github.com/mynamebrody/xinput-controller).
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/usb/USBSpec.h>
#include <stdlib.h>
#include <string.h>

struct XplorerDevice {
    IOCFPlugInInterface **devicePlugin;
    IOUSBDeviceInterface650 **device;
    IOCFPlugInInterface **interfacePlugin;
    IOUSBInterfaceInterface800 **interface;
    UInt8 inPipe;  // pipeRef of the interrupt IN endpoint
    UInt8 outPipe; // pipeRef of the interrupt OUT endpoint (0 if none)
};

static XplorerResult map_kr(IOReturn kr) {
    switch (kr) {
        case kIOReturnAborted:
            return XPLORER_ABORTED;
        case kIOReturnNoDevice:
        case kIOReturnNotAttached:
        case kIOReturnNotResponding:
            return XPLORER_DISCONNECTED;
        case kIOReturnExclusiveAccess:
            return XPLORER_BUSY;
        default:
            return XPLORER_IO_ERROR;
    }
}

const char *xplorer_result_name(int result) {
    switch (result) {
        case XPLORER_OK:           return "ok";
        case XPLORER_NOT_FOUND:    return "not found";
        case XPLORER_OPEN_FAILED:  return "open failed";
        case XPLORER_BUSY:         return "busy (exclusive access denied)";
        case XPLORER_IO_ERROR:     return "I/O error";
        case XPLORER_DISCONNECTED: return "disconnected";
        case XPLORER_ABORTED:      return "aborted";
        default:                   return "unknown";
    }
}

static io_service_t find_device_service(uint16_t vid, uint16_t pid) {
    CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBDeviceClassName);
    if (matching == NULL) {
        return IO_OBJECT_NULL;
    }
    SInt32 vidValue = vid;
    SInt32 pidValue = pid;
    CFNumberRef vidNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vidValue);
    CFNumberRef pidNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pidValue);
    CFDictionarySetValue(matching, CFSTR(kUSBVendorID), vidNumber);
    CFDictionarySetValue(matching, CFSTR(kUSBProductID), pidNumber);
    CFRelease(vidNumber);
    CFRelease(pidNumber);

    io_iterator_t iterator = IO_OBJECT_NULL;
    // IOServiceGetMatchingServices consumes `matching`.
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator);
    if (kr != KERN_SUCCESS) {
        return IO_OBJECT_NULL;
    }
    io_service_t service = IOIteratorNext(iterator); // v1: first match wins
    IOObjectRelease(iterator);
    return service;
}

// Claim the interface service and discover its interrupt pipes.
// Returns true on success with dev->interface/inPipe/outPipe populated.
static bool claim_interface(XplorerDevice *dev, io_service_t interfaceService) {
    SInt32 score = 0;
    kern_return_t kr = IOCreatePlugInInterfaceForService(
        interfaceService, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID,
        &dev->interfacePlugin, &score);
    if (kr != KERN_SUCCESS || dev->interfacePlugin == NULL) {
        return false;
    }
    HRESULT hr = (*dev->interfacePlugin)->QueryInterface(
        dev->interfacePlugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID800),
        (LPVOID *)&dev->interface);
    if (hr != S_OK || dev->interface == NULL) {
        return false;
    }
    IOReturn ior = (*dev->interface)->USBInterfaceOpenSeize(dev->interface);
    if (ior != kIOReturnSuccess) {
        return false;
    }

    UInt8 endpointCount = 0;
    (*dev->interface)->GetNumEndpoints(dev->interface, &endpointCount);
    for (UInt8 pipeRef = 1; pipeRef <= endpointCount; ++pipeRef) {
        UInt8 direction = 0, number = 0, transferType = 0, interval = 0;
        UInt16 maxPacketSize = 0;
        ior = (*dev->interface)->GetPipeProperties(
            dev->interface, pipeRef, &direction, &number, &transferType,
            &maxPacketSize, &interval);
        if (ior != kIOReturnSuccess || transferType != kUSBInterrupt) {
            continue;
        }
        if (direction == kUSBIn && dev->inPipe == 0) {
            dev->inPipe = pipeRef;
        } else if (direction == kUSBOut && dev->outPipe == 0) {
            dev->outPipe = pipeRef;
        }
    }
    return dev->inPipe != 0;
}

XplorerDevice *xplorer_open(uint16_t vid, uint16_t pid, XplorerResult *outErr) {
    XplorerResult err = XPLORER_OPEN_FAILED;
    XplorerDevice *dev = calloc(1, sizeof(XplorerDevice));
    if (dev == NULL) {
        if (outErr) *outErr = XPLORER_OPEN_FAILED;
        return NULL;
    }

    io_service_t deviceService = find_device_service(vid, pid);
    if (deviceService == IO_OBJECT_NULL) {
        err = XPLORER_NOT_FOUND;
        goto fail;
    }

    SInt32 score = 0;
    kern_return_t kr = IOCreatePlugInInterfaceForService(
        deviceService, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
        &dev->devicePlugin, &score);
    IOObjectRelease(deviceService);
    if (kr != KERN_SUCCESS || dev->devicePlugin == NULL) {
        goto fail;
    }

    HRESULT hr = (*dev->devicePlugin)->QueryInterface(
        dev->devicePlugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID650),
        (LPVOID *)&dev->device);
    if (hr != S_OK || dev->device == NULL) {
        goto fail;
    }

    IOReturn ior = (*dev->device)->USBDeviceOpenSeize(dev->device);
    if (ior != kIOReturnSuccess) {
        err = map_kr(ior) == XPLORER_BUSY ? XPLORER_BUSY : XPLORER_OPEN_FAILED;
        goto fail;
    }

    // The X-plorer enumerates unconfigured (no kernel driver touches it).
    UInt8 config = 0;
    ior = (*dev->device)->GetConfiguration(dev->device, &config);
    if (ior == kIOReturnSuccess && config == 0) {
        ior = (*dev->device)->SetConfiguration(dev->device, 1);
        if (ior != kIOReturnSuccess) {
            goto fail;
        }
    }

    // XInput input/control interface: class 0xFF, subclass 0x5D, protocol 0x01.
    IOUSBFindInterfaceRequest request = {
        .bInterfaceClass = 0xFF,
        .bInterfaceSubClass = 0x5D,
        .bInterfaceProtocol = 0x01,
        .bAlternateSetting = kIOUSBFindInterfaceDontCare,
    };
    io_iterator_t interfaceIterator = IO_OBJECT_NULL;
    ior = (*dev->device)->CreateInterfaceIterator(dev->device, &request, &interfaceIterator);
    io_service_t interfaceService = IO_OBJECT_NULL;
    if (ior == kIOReturnSuccess) {
        interfaceService = IOIteratorNext(interfaceIterator);
        IOObjectRelease(interfaceIterator);
    }
    if (interfaceService == IO_OBJECT_NULL) {
        // Fallback: take the first interface of any class that has an
        // interrupt IN pipe (covers nonstandard XInput clones).
        IOUSBFindInterfaceRequest anyRequest = {
            kIOUSBFindInterfaceDontCare, kIOUSBFindInterfaceDontCare,
            kIOUSBFindInterfaceDontCare, kIOUSBFindInterfaceDontCare,
        };
        ior = (*dev->device)->CreateInterfaceIterator(dev->device, &anyRequest, &interfaceIterator);
        if (ior == kIOReturnSuccess) {
            interfaceService = IOIteratorNext(interfaceIterator);
            IOObjectRelease(interfaceIterator);
        }
    }
    if (interfaceService == IO_OBJECT_NULL) {
        goto fail;
    }

    bool claimed = claim_interface(dev, interfaceService);
    IOObjectRelease(interfaceService);
    if (!claimed) {
        goto fail;
    }

    if (outErr) *outErr = XPLORER_OK;
    return dev;

fail:
    xplorer_close(dev);
    if (outErr) *outErr = err;
    return NULL;
}

int xplorer_read(XplorerDevice *dev, uint8_t *buf, uint32_t bufLen) {
    if (dev == NULL || dev->interface == NULL || dev->inPipe == 0) {
        return XPLORER_IO_ERROR;
    }
    UInt32 size = bufLen;
    IOReturn ior = (*dev->interface)->ReadPipe(dev->interface, dev->inPipe, buf, &size);
    if (ior != kIOReturnSuccess) {
        return map_kr(ior);
    }
    return (int)size;
}

void xplorer_abort(XplorerDevice *dev) {
    if (dev != NULL && dev->interface != NULL && dev->inPipe != 0) {
        (*dev->interface)->AbortPipe(dev->interface, dev->inPipe);
    }
}

int xplorer_write(XplorerDevice *dev, const uint8_t *data, uint32_t len) {
    if (dev == NULL || dev->interface == NULL || dev->outPipe == 0) {
        return XPLORER_IO_ERROR;
    }
    IOReturn ior = (*dev->interface)->WritePipe(dev->interface, dev->outPipe,
                                                (void *)data, len);
    if (ior != kIOReturnSuccess) {
        return map_kr(ior);
    }
    return XPLORER_OK;
}

void xplorer_close(XplorerDevice *dev) {
    if (dev == NULL) {
        return;
    }
    if (dev->interface != NULL) {
        (*dev->interface)->USBInterfaceClose(dev->interface);
        (*dev->interface)->Release(dev->interface);
        dev->interface = NULL;
    }
    if (dev->interfacePlugin != NULL) {
        IODestroyPlugInInterface(dev->interfacePlugin);
        dev->interfacePlugin = NULL;
    }
    if (dev->device != NULL) {
        (*dev->device)->USBDeviceClose(dev->device);
        (*dev->device)->Release(dev->device);
        dev->device = NULL;
    }
    if (dev->devicePlugin != NULL) {
        IODestroyPlugInInterface(dev->devicePlugin);
        dev->devicePlugin = NULL;
    }
    free(dev);
}

#pragma clang diagnostic pop
