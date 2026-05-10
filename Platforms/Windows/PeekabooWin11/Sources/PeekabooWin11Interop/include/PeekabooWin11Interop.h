#ifndef PEEKABOO_WIN11_INTEROP_H
#define PEEKABOO_WIN11_INTEROP_H

#include <stdint.h>

#define PEEKABOO_WIN11_UIA_TEXT_CAPACITY 256

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

typedef struct PeekabooWin11UIAutomationElementSnapshot {
    int32_t index;
    int32_t parentIndex;
    int32_t depth;
    int32_t controlType;
    int32_t processIdentifier;
    uint64_t nativeWindowHandle;
    int32_t hasBoundingRectangle;
    int32_t boundsX;
    int32_t boundsY;
    int32_t boundsWidth;
    int32_t boundsHeight;
    int32_t hasIsEnabled;
    int32_t isEnabled;
    int32_t hasIsKeyboardFocusable;
    int32_t isKeyboardFocusable;
    int32_t hasHasKeyboardFocus;
    int32_t hasKeyboardFocus;
    int32_t hasIsOffscreen;
    int32_t isOffscreen;
    uint64_t supportedPatternMask;
    int32_t childCount;
    char name[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char automationIdentifier[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char className[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char localizedControlType[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
} PeekabooWin11UIAutomationElementSnapshot;

typedef struct PeekabooWin11UIAutomationSnapshotResult {
    int32_t scope;
    int32_t maxDepth;
    int32_t maxElements;
    int32_t elementCount;
    int32_t didTruncate;
    int32_t didInitializeCOM;
    int32_t initializeResult;
    int32_t createResult;
    int32_t rootResult;
    int32_t walkerResult;
    int32_t errorResult;
    PeekabooWin11UIAutomationElementSnapshot *elements;
} PeekabooWin11UIAutomationSnapshotResult;

PeekabooWin11UIAutomationSnapshotResult PeekabooWin11CopyUIAutomationSnapshot(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements);

void PeekabooWin11FreeUIAutomationSnapshot(
    PeekabooWin11UIAutomationSnapshotResult *result);

const char *PeekabooWin11UIAutomationElementName(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementAutomationIdentifier(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementClassName(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementLocalizedControlType(
    const PeekabooWin11UIAutomationElementSnapshot *element);

#ifdef __cplusplus
}
#endif

#endif
