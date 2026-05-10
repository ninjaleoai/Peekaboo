#include "PeekabooWin11Interop.h"

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define COBJMACROS
#include <windows.h>
#include <UIAutomation.h>

static int PeekabooWin11Succeeded(HRESULT result) {
    return result >= 0;
}

PeekabooWin11UIAutomationProbeResult PeekabooWin11ProbeUIAutomation(void) {
    PeekabooWin11UIAutomationProbeResult result = {0, 0, 0, 0, 0, 0};

    HRESULT initializeResult = CoInitialize(NULL);
    result.initializeResult = (int32_t)initializeResult;
    result.didInitializeCOM = PeekabooWin11Succeeded(initializeResult) ? 1 : 0;

    if (!result.didInitializeCOM && initializeResult != RPC_E_CHANGED_MODE) {
        return result;
    }

    IUIAutomation *automation = NULL;
    HRESULT createResult = CoCreateInstance(
        &CLSID_CUIAutomation,
        NULL,
        CLSCTX_INPROC_SERVER,
        &IID_IUIAutomation,
        (void **)&automation);
    result.createResult = (int32_t)createResult;

    if (PeekabooWin11Succeeded(createResult) && automation == NULL) {
        result.createResult = (int32_t)E_POINTER;
    }

    if (!PeekabooWin11Succeeded(result.createResult) || automation == NULL) {
        if (result.didInitializeCOM) {
            CoUninitialize();
        }
        return result;
    }

    result.isAvailable = 1;

    IUIAutomationElement *rootElement = NULL;
    HRESULT rootResult = IUIAutomation_GetRootElement(automation, &rootElement);
    result.rootResult = (int32_t)rootResult;

    if (PeekabooWin11Succeeded(rootResult) && rootElement != NULL) {
        result.rootElementAvailable = 1;
        IUIAutomationElement_Release(rootElement);
    }

    IUIAutomation_Release(automation);

    if (result.didInitializeCOM) {
        CoUninitialize();
    }

    return result;
}

static void PeekabooWin11CopyBSTR(BSTR value, char *target, size_t targetSize) {
    if (target == NULL || targetSize == 0) {
        return;
    }

    target[0] = '\0';
    if (value == NULL) {
        return;
    }

    int written = WideCharToMultiByte(
        CP_UTF8,
        0,
        value,
        -1,
        target,
        (int)targetSize,
        NULL,
        NULL);
    if (written == 0) {
        target[0] = '\0';
    }
    target[targetSize - 1] = '\0';
}

static void PeekabooWin11CopyElementName(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentName(element, &value);
    if (PeekabooWin11Succeeded(result)) {
        PeekabooWin11CopyBSTR(value, target, targetSize);
    }
    if (value != NULL) {
        SysFreeString(value);
    }
}

static void PeekabooWin11CopyElementAutomationIdentifier(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentAutomationId(element, &value);
    if (PeekabooWin11Succeeded(result)) {
        PeekabooWin11CopyBSTR(value, target, targetSize);
    }
    if (value != NULL) {
        SysFreeString(value);
    }
}

static void PeekabooWin11CopyElementClassName(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentClassName(element, &value);
    if (PeekabooWin11Succeeded(result)) {
        PeekabooWin11CopyBSTR(value, target, targetSize);
    }
    if (value != NULL) {
        SysFreeString(value);
    }
}

static void PeekabooWin11CopyElementLocalizedControlType(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentLocalizedControlType(element, &value);
    if (PeekabooWin11Succeeded(result)) {
        PeekabooWin11CopyBSTR(value, target, targetSize);
    }
    if (value != NULL) {
        SysFreeString(value);
    }
}

static HRESULT PeekabooWin11CopySnapshotRoot(
    IUIAutomation *automation,
    int32_t scope,
    IUIAutomationElement **rootElement)
{
    if (scope == 3) {
        POINT point = {0, 0};
        if (!GetCursorPos(&point)) {
            return HRESULT_FROM_WIN32(GetLastError());
        }
        return IUIAutomation_ElementFromPoint(automation, point, rootElement);
    }

    if (scope == 2) {
        return IUIAutomation_GetFocusedElement(automation, rootElement);
    }

    if (scope == 1) {
        HWND foregroundWindow = GetForegroundWindow();
        if (foregroundWindow == NULL) {
            return HRESULT_FROM_WIN32(ERROR_INVALID_WINDOW_HANDLE);
        }
        return IUIAutomation_ElementFromHandle(automation, foregroundWindow, rootElement);
    }

    return IUIAutomation_GetRootElement(automation, rootElement);
}

static void PeekabooWin11MarkPattern(
    IUIAutomationElement *element,
    PATTERNID patternId,
    uint64_t patternBit,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *pattern = NULL;
    HRESULT result = IUIAutomationElement_GetCurrentPattern(element, patternId, &pattern);
    if (PeekabooWin11Succeeded(result) && pattern != NULL) {
        snapshot->supportedPatternMask |= patternBit;
        IUnknown_Release(pattern);
    }
}

static void PeekabooWin11CopyElementPatterns(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    PeekabooWin11MarkPattern(element, UIA_InvokePatternId, 1ULL << 0, snapshot);
    PeekabooWin11MarkPattern(element, UIA_ValuePatternId, 1ULL << 1, snapshot);
    PeekabooWin11MarkPattern(element, UIA_RangeValuePatternId, 1ULL << 2, snapshot);
    PeekabooWin11MarkPattern(element, UIA_ScrollPatternId, 1ULL << 3, snapshot);
    PeekabooWin11MarkPattern(element, UIA_ExpandCollapsePatternId, 1ULL << 4, snapshot);
    PeekabooWin11MarkPattern(element, UIA_WindowPatternId, 1ULL << 5, snapshot);
    PeekabooWin11MarkPattern(element, UIA_SelectionItemPatternId, 1ULL << 6, snapshot);
    PeekabooWin11MarkPattern(element, UIA_TextPatternId, 1ULL << 7, snapshot);
    PeekabooWin11MarkPattern(element, UIA_TogglePatternId, 1ULL << 8, snapshot);
    PeekabooWin11MarkPattern(element, UIA_LegacyIAccessiblePatternId, 1ULL << 9, snapshot);
}

static void PeekabooWin11CopyElementValuePattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_ValuePatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationValuePattern *valuePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationValuePattern,
        (void **)&valuePattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || valuePattern == NULL) {
        return;
    }

    BSTR value = NULL;
    HRESULT valueResult = IUIAutomationValuePattern_get_CurrentValue(valuePattern, &value);
    if (PeekabooWin11Succeeded(valueResult)) {
        snapshot->hasValue = 1;
        PeekabooWin11CopyBSTR(value, snapshot->value, PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    }
    if (value != NULL) {
        SysFreeString(value);
    }

    BOOL isReadOnly = FALSE;
    HRESULT readOnlyResult = IUIAutomationValuePattern_get_CurrentIsReadOnly(
        valuePattern,
        &isReadOnly);
    if (PeekabooWin11Succeeded(readOnlyResult)) {
        snapshot->hasIsValueReadOnly = 1;
        snapshot->isValueReadOnly = isReadOnly ? 1 : 0;
    }

    IUIAutomationValuePattern_Release(valuePattern);
}

static void PeekabooWin11CopyElementProperties(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    PeekabooWin11CopyElementName(
        element,
        snapshot->name,
        PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    PeekabooWin11CopyElementAutomationIdentifier(
        element,
        snapshot->automationIdentifier,
        PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    PeekabooWin11CopyElementClassName(
        element,
        snapshot->className,
        PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    PeekabooWin11CopyElementLocalizedControlType(
        element,
        snapshot->localizedControlType,
        PEEKABOO_WIN11_UIA_TEXT_CAPACITY);

    CONTROLTYPEID controlType = 0;
    if (PeekabooWin11Succeeded(IUIAutomationElement_get_CurrentControlType(element, &controlType))) {
        snapshot->controlType = (int32_t)controlType;
    }

    int processIdentifier = 0;
    if (PeekabooWin11Succeeded(IUIAutomationElement_get_CurrentProcessId(element, &processIdentifier))) {
        snapshot->processIdentifier = (int32_t)processIdentifier;
    }

    UIA_HWND nativeWindowHandle = 0;
    if (PeekabooWin11Succeeded(
        IUIAutomationElement_get_CurrentNativeWindowHandle(element, &nativeWindowHandle)))
    {
        snapshot->nativeWindowHandle = (uint64_t)(uintptr_t)nativeWindowHandle;
    }

    RECT bounds = {0, 0, 0, 0};
    if (PeekabooWin11Succeeded(IUIAutomationElement_get_CurrentBoundingRectangle(element, &bounds))) {
        snapshot->hasBoundingRectangle = 1;
        snapshot->boundsX = (int32_t)bounds.left;
        snapshot->boundsY = (int32_t)bounds.top;
        snapshot->boundsWidth = (int32_t)(bounds.right - bounds.left);
        snapshot->boundsHeight = (int32_t)(bounds.bottom - bounds.top);
    }

    BOOL isEnabled = FALSE;
    if (PeekabooWin11Succeeded(IUIAutomationElement_get_CurrentIsEnabled(element, &isEnabled))) {
        snapshot->hasIsEnabled = 1;
        snapshot->isEnabled = isEnabled ? 1 : 0;
    }

    BOOL isKeyboardFocusable = FALSE;
    if (PeekabooWin11Succeeded(
        IUIAutomationElement_get_CurrentIsKeyboardFocusable(element, &isKeyboardFocusable)))
    {
        snapshot->hasIsKeyboardFocusable = 1;
        snapshot->isKeyboardFocusable = isKeyboardFocusable ? 1 : 0;
    }

    BOOL hasKeyboardFocus = FALSE;
    if (PeekabooWin11Succeeded(
        IUIAutomationElement_get_CurrentHasKeyboardFocus(element, &hasKeyboardFocus)))
    {
        snapshot->hasHasKeyboardFocus = 1;
        snapshot->hasKeyboardFocus = hasKeyboardFocus ? 1 : 0;
    }

    BOOL isOffscreen = FALSE;
    if (PeekabooWin11Succeeded(IUIAutomationElement_get_CurrentIsOffscreen(element, &isOffscreen))) {
        snapshot->hasIsOffscreen = 1;
        snapshot->isOffscreen = isOffscreen ? 1 : 0;
    }

    PeekabooWin11CopyElementPatterns(element, snapshot);
    PeekabooWin11CopyElementValuePattern(element, snapshot);
}

static int32_t PeekabooWin11AppendElementSnapshot(
    IUIAutomationTreeWalker *walker,
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationSnapshotResult *result,
    int32_t parentIndex,
    int32_t depth)
{
    if (result->elementCount >= result->maxElements) {
        result->didTruncate = 1;
        return -1;
    }

    int32_t index = result->elementCount;
    result->elementCount += 1;

    PeekabooWin11UIAutomationElementSnapshot *snapshot = &result->elements[index];
    memset(snapshot, 0, sizeof(*snapshot));
    snapshot->index = index;
    snapshot->parentIndex = parentIndex;
    snapshot->depth = depth;

    PeekabooWin11CopyElementProperties(element, snapshot);

    if (depth >= result->maxDepth) {
        return index;
    }

    IUIAutomationElement *child = NULL;
    HRESULT firstChildResult = IUIAutomationTreeWalker_GetFirstChildElement(walker, element, &child);
    if (!PeekabooWin11Succeeded(firstChildResult)) {
        if (result->walkerResult == 0) {
            result->walkerResult = (int32_t)firstChildResult;
        }
        return index;
    }

    while (child != NULL) {
        if (result->elementCount >= result->maxElements) {
            result->didTruncate = 1;
            IUIAutomationElement_Release(child);
            break;
        }

        int32_t childIndex = PeekabooWin11AppendElementSnapshot(
            walker,
            child,
            result,
            index,
            depth + 1);
        if (childIndex >= 0) {
            snapshot->childCount += 1;
        }

        IUIAutomationElement *next = NULL;
        HRESULT nextResult = IUIAutomationTreeWalker_GetNextSiblingElement(walker, child, &next);
        IUIAutomationElement_Release(child);
        if (!PeekabooWin11Succeeded(nextResult)) {
            if (result->walkerResult == 0) {
                result->walkerResult = (int32_t)nextResult;
            }
            break;
        }
        child = next;
    }

    return index;
}

PeekabooWin11UIAutomationSnapshotResult PeekabooWin11CopyUIAutomationSnapshot(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements)
{
    PeekabooWin11UIAutomationSnapshotResult result;
    memset(&result, 0, sizeof(result));
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;

    if (scope != 0 && scope != 1 && scope != 2 && scope != 3) {
        result.errorResult = (int32_t)E_INVALIDARG;
        return result;
    }
    if (maxDepth < 0 || maxElements < 1) {
        result.errorResult = (int32_t)E_INVALIDARG;
        return result;
    }

    result.elements = (PeekabooWin11UIAutomationElementSnapshot *)calloc(
        (size_t)maxElements,
        sizeof(PeekabooWin11UIAutomationElementSnapshot));
    if (result.elements == NULL) {
        result.errorResult = (int32_t)E_OUTOFMEMORY;
        return result;
    }

    HRESULT initializeResult = CoInitialize(NULL);
    result.initializeResult = (int32_t)initializeResult;
    result.didInitializeCOM = PeekabooWin11Succeeded(initializeResult) ? 1 : 0;

    if (!result.didInitializeCOM && initializeResult != RPC_E_CHANGED_MODE) {
        return result;
    }

    IUIAutomation *automation = NULL;
    HRESULT createResult = CoCreateInstance(
        &CLSID_CUIAutomation,
        NULL,
        CLSCTX_INPROC_SERVER,
        &IID_IUIAutomation,
        (void **)&automation);
    result.createResult = (int32_t)createResult;

    if (PeekabooWin11Succeeded(createResult) && automation == NULL) {
        result.createResult = (int32_t)E_POINTER;
    }

    if (!PeekabooWin11Succeeded(result.createResult) || automation == NULL) {
        if (result.didInitializeCOM) {
            CoUninitialize();
        }
        return result;
    }

    IUIAutomationElement *rootElement = NULL;
    HRESULT rootResult = PeekabooWin11CopySnapshotRoot(automation, scope, &rootElement);
    result.rootResult = (int32_t)rootResult;
    if (PeekabooWin11Succeeded(rootResult) && rootElement == NULL) {
        result.rootResult = (int32_t)E_POINTER;
    }

    if (!PeekabooWin11Succeeded(result.rootResult) || rootElement == NULL) {
        IUIAutomation_Release(automation);
        if (result.didInitializeCOM) {
            CoUninitialize();
        }
        return result;
    }

    IUIAutomationTreeWalker *walker = NULL;
    HRESULT walkerResult = IUIAutomation_get_ControlViewWalker(automation, &walker);
    result.walkerResult = (int32_t)walkerResult;
    if (PeekabooWin11Succeeded(walkerResult) && walker == NULL) {
        result.walkerResult = (int32_t)E_POINTER;
    }

    if (PeekabooWin11Succeeded(result.walkerResult) && walker != NULL) {
        PeekabooWin11AppendElementSnapshot(walker, rootElement, &result, -1, 0);
        IUIAutomationTreeWalker_Release(walker);
    }

    IUIAutomationElement_Release(rootElement);
    IUIAutomation_Release(automation);

    if (result.didInitializeCOM) {
        CoUninitialize();
    }

    return result;
}
#else
PeekabooWin11UIAutomationProbeResult PeekabooWin11ProbeUIAutomation(void) {
    PeekabooWin11UIAutomationProbeResult result = {0, 0, 0, -2147467263, 0, 0};
    return result;
}

PeekabooWin11UIAutomationSnapshotResult PeekabooWin11CopyUIAutomationSnapshot(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements)
{
    PeekabooWin11UIAutomationSnapshotResult result;
    memset(&result, 0, sizeof(result));
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.initializeResult = -2147467263;
    return result;
}
#endif

void PeekabooWin11FreeUIAutomationSnapshot(
    PeekabooWin11UIAutomationSnapshotResult *result)
{
    if (result == NULL) {
        return;
    }
    free(result->elements);
    result->elements = NULL;
    result->elementCount = 0;
}

const char *PeekabooWin11UIAutomationElementName(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->name;
}

const char *PeekabooWin11UIAutomationElementAutomationIdentifier(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->automationIdentifier;
}

const char *PeekabooWin11UIAutomationElementClassName(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->className;
}

const char *PeekabooWin11UIAutomationElementLocalizedControlType(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->localizedControlType;
}

const char *PeekabooWin11UIAutomationElementValue(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->value;
}
