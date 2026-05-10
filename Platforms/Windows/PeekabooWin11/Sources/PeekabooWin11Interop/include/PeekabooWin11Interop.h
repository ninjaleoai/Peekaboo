#ifndef PEEKABOO_WIN11_INTEROP_H
#define PEEKABOO_WIN11_INTEROP_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PeekabooWin11UIAutomationProbeResult {
    int32_t isAvailable;
    int32_t rootElementAvailable;
    int32_t didInitializeCOM;
    int32_t initializeResult;
    int32_t createResult;
    int32_t rootResult;
} PeekabooWin11UIAutomationProbeResult;

PeekabooWin11UIAutomationProbeResult PeekabooWin11ProbeUIAutomation(void);

#ifdef __cplusplus
}
#endif

#endif
