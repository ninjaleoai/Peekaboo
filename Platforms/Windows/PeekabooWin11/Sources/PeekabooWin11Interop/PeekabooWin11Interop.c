#include "PeekabooWin11Interop.h"

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define COBJMACROS
#include <windows.h>
#include <UIAutomation.h>

#define PEEKABOO_WIN11_UIA_ACTION_INVOKE 1
#define PEEKABOO_WIN11_UIA_ACTION_SET_VALUE 2
#define PEEKABOO_WIN11_UIA_ACTION_TOGGLE 3
#define PEEKABOO_WIN11_UIA_ACTION_EXPAND 4
#define PEEKABOO_WIN11_UIA_ACTION_COLLAPSE 5
#define PEEKABOO_WIN11_UIA_ACTION_SELECT 6
#define PEEKABOO_WIN11_UIA_ACTION_SET_RANGE_VALUE 7
#define PEEKABOO_WIN11_UIA_ACTION_SET_SCROLL_PERCENT 8
#define PEEKABOO_WIN11_UIA_ACTION_SET_WINDOW_VISUAL_STATE 9
#define PEEKABOO_WIN11_UIA_ACTION_MOVE 10
#define PEEKABOO_WIN11_UIA_ACTION_RESIZE 11
#define PEEKABOO_WIN11_UIA_ACTION_ROTATE 12
#define PEEKABOO_WIN11_UIA_ACTION_SCROLL_INTO_VIEW 13
#define PEEKABOO_WIN11_UIA_ACTION_ADD_TO_SELECTION 14
#define PEEKABOO_WIN11_UIA_ACTION_REMOVE_FROM_SELECTION 15
#define PEEKABOO_WIN11_UIA_ACTION_SET_DOCK_POSITION 16
#define PEEKABOO_WIN11_UIA_ACTION_FOCUS 17
#define PEEKABOO_WIN11_UIA_ACTION_PERFORM_LEGACY_DEFAULT_ACTION 18
#define PEEKABOO_WIN11_UIA_ACTION_SET_LEGACY_VALUE 19
#define PEEKABOO_WIN11_UIA_ACTION_CLOSE_WINDOW 20
#define PEEKABOO_WIN11_UIA_ACTION_WAIT_FOR_WINDOW_INPUT_IDLE 21
#define PEEKABOO_WIN11_UIA_ACTION_SET_CURRENT_VIEW 22
#define PEEKABOO_WIN11_UIA_ACTION_SET_ZOOM_LEVEL 23
#define PEEKABOO_WIN11_UIA_ACTION_ZOOM_BY_UNIT 24
#define PEEKABOO_WIN11_UIA_ACTION_REALIZE_VIRTUALIZED_ITEM 25
#define PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL -1.0

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

static void PeekabooWin11AppendUTF8Text(char *target, size_t targetSize, const char *value) {
    if (target == NULL || targetSize == 0 || value == NULL) {
        return;
    }

    size_t used = strlen(target);
    if (used >= targetSize - 1) {
        target[targetSize - 1] = '\0';
        return;
    }

    strncat(target, value, targetSize - used - 1);
    target[targetSize - 1] = '\0';
}

static void PeekabooWin11CopyTextRangeArrayText(
    IUIAutomationTextRangeArray *ranges,
    char *textTarget,
    size_t textTargetSize,
    int32_t *hasText,
    int32_t *hasRangeCount,
    int32_t *rangeCount)
{
    if (ranges == NULL || textTarget == NULL || hasText == NULL ||
        hasRangeCount == NULL || rangeCount == NULL)
    {
        return;
    }

    int textRangeCount = 0;
    HRESULT lengthResult = IUIAutomationTextRangeArray_get_Length(
        ranges,
        &textRangeCount);
    if (!PeekabooWin11Succeeded(lengthResult) || textRangeCount < 0) {
        return;
    }

    *hasRangeCount = 1;
    *rangeCount = textRangeCount;
    if (textRangeCount == 0) {
        *hasText = 1;
        textTarget[0] = '\0';
        return;
    }

    for (int index = 0; index < textRangeCount; index += 1) {
        IUIAutomationTextRange *textRange = NULL;
        HRESULT rangeResult = IUIAutomationTextRangeArray_GetElement(
            ranges,
            index,
            &textRange);
        if (!PeekabooWin11Succeeded(rangeResult) || textRange == NULL) {
            continue;
        }

        BSTR text = NULL;
        HRESULT textResult = IUIAutomationTextRange_GetText(
            textRange,
            PEEKABOO_WIN11_UIA_TEXT_CAPACITY - 1,
            &text);
        if (PeekabooWin11Succeeded(textResult)) {
            char textPart[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
            PeekabooWin11CopyBSTR(text, textPart, PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
            if (*hasText != 0) {
                PeekabooWin11AppendUTF8Text(textTarget, textTargetSize, "\n");
            }
            *hasText = 1;
            PeekabooWin11AppendUTF8Text(textTarget, textTargetSize, textPart);
        }
        if (text != NULL) {
            SysFreeString(text);
        }
        IUIAutomationTextRange_Release(textRange);
    }
}

static BSTR PeekabooWin11CopyUTF8BSTR(const char *value) {
    const char *source = value == NULL ? "" : value;
    int wideLength = MultiByteToWideChar(CP_UTF8, 0, source, -1, NULL, 0);
    if (wideLength <= 0) {
        return NULL;
    }

    BSTR result = SysAllocStringLen(NULL, (UINT)(wideLength - 1));
    if (result == NULL) {
        return NULL;
    }

    int written = MultiByteToWideChar(CP_UTF8, 0, source, -1, result, wideLength);
    if (written == 0) {
        SysFreeString(result);
        return NULL;
    }
    return result;
}

static void PeekabooWin11CopyElementStringResult(
    HRESULT result,
    BSTR value,
    char *target,
    size_t targetSize)
{
    if (PeekabooWin11Succeeded(result)) {
        PeekabooWin11CopyBSTR(value, target, targetSize);
    }
    if (value != NULL) {
        SysFreeString(value);
    }
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

static void PeekabooWin11CopyElementAccessKey(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentAccessKey(element, &value);
    PeekabooWin11CopyElementStringResult(result, value, target, targetSize);
}

static void PeekabooWin11CopyElementAcceleratorKey(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentAcceleratorKey(element, &value);
    PeekabooWin11CopyElementStringResult(result, value, target, targetSize);
}

static void PeekabooWin11CopyElementFrameworkId(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentFrameworkId(element, &value);
    PeekabooWin11CopyElementStringResult(result, value, target, targetSize);
}

static void PeekabooWin11CopyElementHelpText(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentHelpText(element, &value);
    PeekabooWin11CopyElementStringResult(result, value, target, targetSize);
}

static void PeekabooWin11CopyElementItemStatus(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentItemStatus(element, &value);
    PeekabooWin11CopyElementStringResult(result, value, target, targetSize);
}

static void PeekabooWin11CopyElementItemType(
    IUIAutomationElement *element,
    char *target,
    size_t targetSize)
{
    BSTR value = NULL;
    HRESULT result = IUIAutomationElement_get_CurrentItemType(element, &value);
    PeekabooWin11CopyElementStringResult(result, value, target, targetSize);
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
    PeekabooWin11MarkPattern(element, UIA_GridPatternId, 1ULL << 10, snapshot);
    PeekabooWin11MarkPattern(element, UIA_GridItemPatternId, 1ULL << 11, snapshot);
    PeekabooWin11MarkPattern(element, UIA_TransformPatternId, 1ULL << 12, snapshot);
    PeekabooWin11MarkPattern(element, UIA_ScrollItemPatternId, 1ULL << 13, snapshot);
    PeekabooWin11MarkPattern(element, UIA_SelectionPatternId, 1ULL << 14, snapshot);
    PeekabooWin11MarkPattern(element, UIA_DockPatternId, 1ULL << 15, snapshot);
    PeekabooWin11MarkPattern(element, UIA_TablePatternId, 1ULL << 16, snapshot);
    PeekabooWin11MarkPattern(element, UIA_TableItemPatternId, 1ULL << 17, snapshot);
    PeekabooWin11MarkPattern(element, UIA_TransformPattern2Id, 1ULL << 18, snapshot);
    PeekabooWin11MarkPattern(element, UIA_MultipleViewPatternId, 1ULL << 19, snapshot);
    PeekabooWin11MarkPattern(element, UIA_VirtualizedItemPatternId, 1ULL << 20, snapshot);
    PeekabooWin11MarkPattern(element, UIA_AnnotationPatternId, 1ULL << 21, snapshot);
    PeekabooWin11MarkPattern(element, UIA_StylesPatternId, 1ULL << 22, snapshot);
    PeekabooWin11MarkPattern(element, UIA_DragPatternId, 1ULL << 23, snapshot);
    PeekabooWin11MarkPattern(element, UIA_DropTargetPatternId, 1ULL << 24, snapshot);
    PeekabooWin11MarkPattern(element, UIA_TextPattern2Id, 1ULL << 25, snapshot);
    PeekabooWin11MarkPattern(element, UIA_TextEditPatternId, 1ULL << 26, snapshot);
    PeekabooWin11MarkPattern(element, UIA_TextChildPatternId, 1ULL << 27, snapshot);
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

static void PeekabooWin11CopyElementRangeValuePattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_RangeValuePatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationRangeValuePattern *rangeValuePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationRangeValuePattern,
        (void **)&rangeValuePattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || rangeValuePattern == NULL) {
        return;
    }

    double value = 0.0;
    HRESULT valueResult = IUIAutomationRangeValuePattern_get_CurrentValue(
        rangeValuePattern,
        &value);
    if (PeekabooWin11Succeeded(valueResult)) {
        snapshot->hasRangeValue = 1;
        snapshot->rangeValue = value;
    }

    double minimum = 0.0;
    HRESULT minimumResult = IUIAutomationRangeValuePattern_get_CurrentMinimum(
        rangeValuePattern,
        &minimum);
    if (PeekabooWin11Succeeded(minimumResult)) {
        snapshot->hasRangeMinimum = 1;
        snapshot->rangeMinimum = minimum;
    }

    double maximum = 0.0;
    HRESULT maximumResult = IUIAutomationRangeValuePattern_get_CurrentMaximum(
        rangeValuePattern,
        &maximum);
    if (PeekabooWin11Succeeded(maximumResult)) {
        snapshot->hasRangeMaximum = 1;
        snapshot->rangeMaximum = maximum;
    }

    double smallChange = 0.0;
    HRESULT smallChangeResult = IUIAutomationRangeValuePattern_get_CurrentSmallChange(
        rangeValuePattern,
        &smallChange);
    if (PeekabooWin11Succeeded(smallChangeResult)) {
        snapshot->hasRangeSmallChange = 1;
        snapshot->rangeSmallChange = smallChange;
    }

    double largeChange = 0.0;
    HRESULT largeChangeResult = IUIAutomationRangeValuePattern_get_CurrentLargeChange(
        rangeValuePattern,
        &largeChange);
    if (PeekabooWin11Succeeded(largeChangeResult)) {
        snapshot->hasRangeLargeChange = 1;
        snapshot->rangeLargeChange = largeChange;
    }

    BOOL isReadOnly = FALSE;
    HRESULT readOnlyResult = IUIAutomationRangeValuePattern_get_CurrentIsReadOnly(
        rangeValuePattern,
        &isReadOnly);
    if (PeekabooWin11Succeeded(readOnlyResult)) {
        snapshot->hasIsRangeValueReadOnly = 1;
        snapshot->isRangeValueReadOnly = isReadOnly ? 1 : 0;
    }

    IUIAutomationRangeValuePattern_Release(rangeValuePattern);
}

static void PeekabooWin11CopyElementScrollPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_ScrollPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationScrollPattern *scrollPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationScrollPattern,
        (void **)&scrollPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || scrollPattern == NULL) {
        return;
    }

    double horizontalPercent = 0.0;
    HRESULT horizontalPercentResult = IUIAutomationScrollPattern_get_CurrentHorizontalScrollPercent(
        scrollPattern,
        &horizontalPercent);
    if (PeekabooWin11Succeeded(horizontalPercentResult)) {
        snapshot->hasHorizontalScrollPercent = 1;
        snapshot->horizontalScrollPercent = horizontalPercent;
    }

    double verticalPercent = 0.0;
    HRESULT verticalPercentResult = IUIAutomationScrollPattern_get_CurrentVerticalScrollPercent(
        scrollPattern,
        &verticalPercent);
    if (PeekabooWin11Succeeded(verticalPercentResult)) {
        snapshot->hasVerticalScrollPercent = 1;
        snapshot->verticalScrollPercent = verticalPercent;
    }

    double horizontalViewSize = 0.0;
    HRESULT horizontalViewSizeResult = IUIAutomationScrollPattern_get_CurrentHorizontalViewSize(
        scrollPattern,
        &horizontalViewSize);
    if (PeekabooWin11Succeeded(horizontalViewSizeResult)) {
        snapshot->hasHorizontalScrollViewSize = 1;
        snapshot->horizontalScrollViewSize = horizontalViewSize;
    }

    double verticalViewSize = 0.0;
    HRESULT verticalViewSizeResult = IUIAutomationScrollPattern_get_CurrentVerticalViewSize(
        scrollPattern,
        &verticalViewSize);
    if (PeekabooWin11Succeeded(verticalViewSizeResult)) {
        snapshot->hasVerticalScrollViewSize = 1;
        snapshot->verticalScrollViewSize = verticalViewSize;
    }

    BOOL isHorizontallyScrollable = FALSE;
    HRESULT horizontalScrollableResult =
        IUIAutomationScrollPattern_get_CurrentHorizontallyScrollable(
            scrollPattern,
            &isHorizontallyScrollable);
    if (PeekabooWin11Succeeded(horizontalScrollableResult)) {
        snapshot->hasIsHorizontallyScrollable = 1;
        snapshot->isHorizontallyScrollable = isHorizontallyScrollable ? 1 : 0;
    }

    BOOL isVerticallyScrollable = FALSE;
    HRESULT verticalScrollableResult =
        IUIAutomationScrollPattern_get_CurrentVerticallyScrollable(
            scrollPattern,
            &isVerticallyScrollable);
    if (PeekabooWin11Succeeded(verticalScrollableResult)) {
        snapshot->hasIsVerticallyScrollable = 1;
        snapshot->isVerticallyScrollable = isVerticallyScrollable ? 1 : 0;
    }

    IUIAutomationScrollPattern_Release(scrollPattern);
}

static void PeekabooWin11CopyElementTogglePattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TogglePatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationTogglePattern *togglePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTogglePattern,
        (void **)&togglePattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || togglePattern == NULL) {
        return;
    }

    enum ToggleState toggleState = ToggleState_Off;
    HRESULT stateResult = IUIAutomationTogglePattern_get_CurrentToggleState(
        togglePattern,
        &toggleState);
    if (PeekabooWin11Succeeded(stateResult)) {
        snapshot->hasToggleState = 1;
        snapshot->toggleState = (int32_t)toggleState;
    }

    IUIAutomationTogglePattern_Release(togglePattern);
}

static void PeekabooWin11CopyElementExpandCollapsePattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_ExpandCollapsePatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationExpandCollapsePattern *expandCollapsePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationExpandCollapsePattern,
        (void **)&expandCollapsePattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || expandCollapsePattern == NULL) {
        return;
    }

    enum ExpandCollapseState expandCollapseState = ExpandCollapseState_Collapsed;
    HRESULT stateResult = IUIAutomationExpandCollapsePattern_get_CurrentExpandCollapseState(
        expandCollapsePattern,
        &expandCollapseState);
    if (PeekabooWin11Succeeded(stateResult)) {
        snapshot->hasExpandCollapseState = 1;
        snapshot->expandCollapseState = (int32_t)expandCollapseState;
    }

    IUIAutomationExpandCollapsePattern_Release(expandCollapsePattern);
}

static void PeekabooWin11CopyElementWindowPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_WindowPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationWindowPattern *windowPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationWindowPattern,
        (void **)&windowPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || windowPattern == NULL) {
        return;
    }

    enum WindowVisualState visualState = WindowVisualState_Normal;
    HRESULT visualStateResult = IUIAutomationWindowPattern_get_CurrentWindowVisualState(
        windowPattern,
        &visualState);
    if (PeekabooWin11Succeeded(visualStateResult)) {
        snapshot->hasWindowVisualState = 1;
        snapshot->windowVisualState = (int32_t)visualState;
    }

    enum WindowInteractionState interactionState = WindowInteractionState_Running;
    HRESULT interactionStateResult =
        IUIAutomationWindowPattern_get_CurrentWindowInteractionState(
            windowPattern,
            &interactionState);
    if (PeekabooWin11Succeeded(interactionStateResult)) {
        snapshot->hasWindowInteractionState = 1;
        snapshot->windowInteractionState = (int32_t)interactionState;
    }

    BOOL canMaximize = FALSE;
    HRESULT canMaximizeResult = IUIAutomationWindowPattern_get_CurrentCanMaximize(
        windowPattern,
        &canMaximize);
    if (PeekabooWin11Succeeded(canMaximizeResult)) {
        snapshot->hasCanMaximizeWindow = 1;
        snapshot->canMaximizeWindow = canMaximize ? 1 : 0;
    }

    BOOL canMinimize = FALSE;
    HRESULT canMinimizeResult = IUIAutomationWindowPattern_get_CurrentCanMinimize(
        windowPattern,
        &canMinimize);
    if (PeekabooWin11Succeeded(canMinimizeResult)) {
        snapshot->hasCanMinimizeWindow = 1;
        snapshot->canMinimizeWindow = canMinimize ? 1 : 0;
    }

    BOOL isModal = FALSE;
    HRESULT isModalResult = IUIAutomationWindowPattern_get_CurrentIsModal(
        windowPattern,
        &isModal);
    if (PeekabooWin11Succeeded(isModalResult)) {
        snapshot->hasIsModalWindow = 1;
        snapshot->isModalWindow = isModal ? 1 : 0;
    }

    BOOL isTopmost = FALSE;
    HRESULT isTopmostResult = IUIAutomationWindowPattern_get_CurrentIsTopmost(
        windowPattern,
        &isTopmost);
    if (PeekabooWin11Succeeded(isTopmostResult)) {
        snapshot->hasIsTopmostWindow = 1;
        snapshot->isTopmostWindow = isTopmost ? 1 : 0;
    }

    IUIAutomationWindowPattern_Release(windowPattern);
}

static void PeekabooWin11CopyElementDockPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_DockPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationDockPattern *dockPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationDockPattern,
        (void **)&dockPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || dockPattern == NULL) {
        return;
    }

    enum DockPosition dockPosition = DockPosition_None;
    HRESULT dockPositionResult = IUIAutomationDockPattern_get_CurrentDockPosition(
        dockPattern,
        &dockPosition);
    if (PeekabooWin11Succeeded(dockPositionResult)) {
        snapshot->hasDockPosition = 1;
        snapshot->dockPosition = (int32_t)dockPosition;
    }

    IUIAutomationDockPattern_Release(dockPattern);
}

static void PeekabooWin11CopyElementTextPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TextPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationTextPattern *textPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTextPattern,
        (void **)&textPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || textPattern == NULL) {
        return;
    }

    IUIAutomationTextRange *documentRange = NULL;
    HRESULT documentRangeResult = IUIAutomationTextPattern_get_DocumentRange(
        textPattern,
        &documentRange);
    if (PeekabooWin11Succeeded(documentRangeResult) && documentRange != NULL) {
        BSTR text = NULL;
        HRESULT textResult = IUIAutomationTextRange_GetText(
            documentRange,
            PEEKABOO_WIN11_UIA_TEXT_CAPACITY - 1,
            &text);
        if (PeekabooWin11Succeeded(textResult)) {
            snapshot->hasText = 1;
            PeekabooWin11CopyBSTR(text, snapshot->text, PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
        }
        if (text != NULL) {
            SysFreeString(text);
        }
        IUIAutomationTextRange_Release(documentRange);
    }

    enum SupportedTextSelection supportedTextSelection = SupportedTextSelection_None;
    HRESULT selectionResult = IUIAutomationTextPattern_get_SupportedTextSelection(
        textPattern,
        &supportedTextSelection);
    if (PeekabooWin11Succeeded(selectionResult)) {
        snapshot->hasSupportedTextSelection = 1;
        snapshot->supportedTextSelection = (int32_t)supportedTextSelection;
    }

    IUIAutomationTextRangeArray *selectedRanges = NULL;
    HRESULT selectedRangesResult = IUIAutomationTextPattern_GetSelection(
        textPattern,
        &selectedRanges);
    if (PeekabooWin11Succeeded(selectedRangesResult) && selectedRanges != NULL) {
        PeekabooWin11CopyTextRangeArrayText(
            selectedRanges,
            snapshot->selectedText,
            PEEKABOO_WIN11_UIA_TEXT_CAPACITY,
            &snapshot->hasSelectedText,
            &snapshot->hasSelectedTextRangeCount,
            &snapshot->selectedTextRangeCount);
        IUIAutomationTextRangeArray_Release(selectedRanges);
    }

    IUIAutomationTextRangeArray *visibleRanges = NULL;
    HRESULT visibleRangesResult = IUIAutomationTextPattern_GetVisibleRanges(
        textPattern,
        &visibleRanges);
    if (PeekabooWin11Succeeded(visibleRangesResult) && visibleRanges != NULL) {
        PeekabooWin11CopyTextRangeArrayText(
            visibleRanges,
            snapshot->visibleText,
            PEEKABOO_WIN11_UIA_TEXT_CAPACITY,
            &snapshot->hasVisibleText,
            &snapshot->hasVisibleTextRangeCount,
            &snapshot->visibleTextRangeCount);
        IUIAutomationTextRangeArray_Release(visibleRanges);
    }

    IUIAutomationTextPattern_Release(textPattern);
}

static void PeekabooWin11CopyTextRangeBoundingRectangleCount(
    HRESULT result,
    SAFEARRAY *rectangles,
    int32_t *hasCount,
    int32_t *count)
{
    if (PeekabooWin11Succeeded(result) && rectangles != NULL) {
        LONG lowerBound = 0;
        LONG upperBound = -1;
        HRESULT lowerBoundResult = SafeArrayGetLBound(rectangles, 1, &lowerBound);
        HRESULT upperBoundResult = SafeArrayGetUBound(rectangles, 1, &upperBound);
        if (PeekabooWin11Succeeded(lowerBoundResult) &&
            PeekabooWin11Succeeded(upperBoundResult))
        {
            LONG valueCount = upperBound >= lowerBound ? upperBound - lowerBound + 1 : 0;
            *hasCount = 1;
            *count = (int32_t)(valueCount / 4);
        }
    }
    if (rectangles != NULL) {
        SafeArrayDestroy(rectangles);
    }
}

static void PeekabooWin11CopyElementTextPattern2(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TextPattern2Id,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationTextPattern2 *textPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTextPattern2,
        (void **)&textPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || textPattern == NULL) {
        return;
    }

    BOOL isActive = FALSE;
    IUIAutomationTextRange *caretRange = NULL;
    HRESULT caretResult = IUIAutomationTextPattern2_GetCaretRange(
        textPattern,
        &isActive,
        &caretRange);
    if (PeekabooWin11Succeeded(caretResult)) {
        snapshot->hasTextCaretIsActive = 1;
        snapshot->textCaretIsActive = isActive ? 1 : 0;
    }
    if (PeekabooWin11Succeeded(caretResult) && caretRange != NULL) {
        SAFEARRAY *rectangles = NULL;
        HRESULT rectanglesResult = IUIAutomationTextRange_GetBoundingRectangles(
            caretRange,
            &rectangles);
        PeekabooWin11CopyTextRangeBoundingRectangleCount(
            rectanglesResult,
            rectangles,
            &snapshot->hasTextCaretBoundingRectangleCount,
            &snapshot->textCaretBoundingRectangleCount);
        IUIAutomationTextRange_Release(caretRange);
    }

    IUIAutomationTextPattern2_Release(textPattern);
}

static void PeekabooWin11CopyTextEditRangeMetadata(
    HRESULT rangeResult,
    IUIAutomationTextRange *range,
    int32_t *hasRange,
    int32_t *hasRangeValue,
    int32_t *hasBoundingRectangleCount,
    int32_t *boundingRectangleCount)
{
    if (PeekabooWin11Succeeded(rangeResult)) {
        *hasRange = 1;
        *hasRangeValue = range != NULL ? 1 : 0;
    }

    if (PeekabooWin11Succeeded(rangeResult) && range != NULL) {
        SAFEARRAY *rectangles = NULL;
        HRESULT rectanglesResult = IUIAutomationTextRange_GetBoundingRectangles(
            range,
            &rectangles);
        PeekabooWin11CopyTextRangeBoundingRectangleCount(
            rectanglesResult,
            rectangles,
            hasBoundingRectangleCount,
            boundingRectangleCount);
    }

    if (range != NULL) {
        IUIAutomationTextRange_Release(range);
    }
}

static void PeekabooWin11CopyElementTextEditPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TextEditPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationTextEditPattern *textEditPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTextEditPattern,
        (void **)&textEditPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || textEditPattern == NULL) {
        return;
    }

    IUIAutomationTextRange *activeCompositionRange = NULL;
    HRESULT activeCompositionResult = IUIAutomationTextEditPattern_GetActiveComposition(
        textEditPattern,
        &activeCompositionRange);
    PeekabooWin11CopyTextEditRangeMetadata(
        activeCompositionResult,
        activeCompositionRange,
        &snapshot->hasTextEditActiveComposition,
        &snapshot->textEditHasActiveComposition,
        &snapshot->hasTextEditActiveCompositionBoundingRectangleCount,
        &snapshot->textEditActiveCompositionBoundingRectangleCount);

    IUIAutomationTextRange *conversionTargetRange = NULL;
    HRESULT conversionTargetResult = IUIAutomationTextEditPattern_GetConversionTarget(
        textEditPattern,
        &conversionTargetRange);
    PeekabooWin11CopyTextEditRangeMetadata(
        conversionTargetResult,
        conversionTargetRange,
        &snapshot->hasTextEditConversionTarget,
        &snapshot->textEditHasConversionTarget,
        &snapshot->hasTextEditConversionTargetBoundingRectangleCount,
        &snapshot->textEditConversionTargetBoundingRectangleCount);

    IUIAutomationTextEditPattern_Release(textEditPattern);
}

static void PeekabooWin11CopyElementTextChildPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TextChildPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationTextChildPattern *textChildPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTextChildPattern,
        (void **)&textChildPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || textChildPattern == NULL) {
        return;
    }

    IUIAutomationElement *textContainer = NULL;
    HRESULT containerResult = IUIAutomationTextChildPattern_get_TextContainer(
        textChildPattern,
        &textContainer);
    if (PeekabooWin11Succeeded(containerResult) && textContainer != NULL) {
        BSTR containerName = NULL;
        PeekabooWin11CopyPatternString(
            IUIAutomationElement_get_CurrentName(textContainer, &containerName),
            containerName,
            &snapshot->hasTextChildContainerName,
            snapshot->textChildContainerName);
        IUIAutomationElement_Release(textContainer);
    }

    IUIAutomationTextRange *textRange = NULL;
    HRESULT rangeResult = IUIAutomationTextChildPattern_get_TextRange(
        textChildPattern,
        &textRange);
    if (PeekabooWin11Succeeded(rangeResult)) {
        snapshot->hasTextChildTextRange = 1;
        snapshot->textChildHasTextRange = textRange != NULL ? 1 : 0;
    }
    if (PeekabooWin11Succeeded(rangeResult) && textRange != NULL) {
        SAFEARRAY *rectangles = NULL;
        HRESULT rectanglesResult = IUIAutomationTextRange_GetBoundingRectangles(
            textRange,
            &rectangles);
        PeekabooWin11CopyTextRangeBoundingRectangleCount(
            rectanglesResult,
            rectangles,
            &snapshot->hasTextChildRangeBoundingRectangleCount,
            &snapshot->textChildRangeBoundingRectangleCount);
        IUIAutomationTextRange_Release(textRange);
    }

    IUIAutomationTextChildPattern_Release(textChildPattern);
}

static void PeekabooWin11CopyElementGridPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_GridPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationGridPattern *gridPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationGridPattern,
        (void **)&gridPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || gridPattern == NULL) {
        return;
    }

    int rowCount = 0;
    HRESULT rowCountResult = IUIAutomationGridPattern_get_CurrentRowCount(
        gridPattern,
        &rowCount);
    if (PeekabooWin11Succeeded(rowCountResult)) {
        snapshot->hasGridRowCount = 1;
        snapshot->gridRowCount = (int32_t)rowCount;
    }

    int columnCount = 0;
    HRESULT columnCountResult = IUIAutomationGridPattern_get_CurrentColumnCount(
        gridPattern,
        &columnCount);
    if (PeekabooWin11Succeeded(columnCountResult)) {
        snapshot->hasGridColumnCount = 1;
        snapshot->gridColumnCount = (int32_t)columnCount;
    }

    IUIAutomationGridPattern_Release(gridPattern);
}

static void PeekabooWin11CopyElementGridItemPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_GridItemPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationGridItemPattern *gridItemPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationGridItemPattern,
        (void **)&gridItemPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || gridItemPattern == NULL) {
        return;
    }

    int row = 0;
    HRESULT rowResult = IUIAutomationGridItemPattern_get_CurrentRow(
        gridItemPattern,
        &row);
    if (PeekabooWin11Succeeded(rowResult)) {
        snapshot->hasGridItemRow = 1;
        snapshot->gridItemRow = (int32_t)row;
    }

    int column = 0;
    HRESULT columnResult = IUIAutomationGridItemPattern_get_CurrentColumn(
        gridItemPattern,
        &column);
    if (PeekabooWin11Succeeded(columnResult)) {
        snapshot->hasGridItemColumn = 1;
        snapshot->gridItemColumn = (int32_t)column;
    }

    int rowSpan = 0;
    HRESULT rowSpanResult = IUIAutomationGridItemPattern_get_CurrentRowSpan(
        gridItemPattern,
        &rowSpan);
    if (PeekabooWin11Succeeded(rowSpanResult)) {
        snapshot->hasGridItemRowSpan = 1;
        snapshot->gridItemRowSpan = (int32_t)rowSpan;
    }

    int columnSpan = 0;
    HRESULT columnSpanResult = IUIAutomationGridItemPattern_get_CurrentColumnSpan(
        gridItemPattern,
        &columnSpan);
    if (PeekabooWin11Succeeded(columnSpanResult)) {
        snapshot->hasGridItemColumnSpan = 1;
        snapshot->gridItemColumnSpan = (int32_t)columnSpan;
    }

    IUIAutomationGridItemPattern_Release(gridItemPattern);
}

static void PeekabooWin11CopyElementArrayCount(
    HRESULT result,
    IUIAutomationElementArray *elements,
    int32_t *hasCount,
    int32_t *count)
{
    if (PeekabooWin11Succeeded(result) && elements != NULL) {
        int length = 0;
        HRESULT lengthResult = IUIAutomationElementArray_get_Length(elements, &length);
        if (PeekabooWin11Succeeded(lengthResult)) {
            *hasCount = 1;
            *count = (int32_t)length;
        }
    }
    if (elements != NULL) {
        IUIAutomationElementArray_Release(elements);
    }
}

static void PeekabooWin11CopySafeArrayCount(
    HRESULT result,
    SAFEARRAY *values,
    int32_t *hasCount,
    int32_t *count)
{
    if (PeekabooWin11Succeeded(result) && values != NULL) {
        LONG lowerBound = 0;
        LONG upperBound = -1;
        HRESULT lowerBoundResult = SafeArrayGetLBound(values, 1, &lowerBound);
        HRESULT upperBoundResult = SafeArrayGetUBound(values, 1, &upperBound);
        if (PeekabooWin11Succeeded(lowerBoundResult) &&
            PeekabooWin11Succeeded(upperBoundResult))
        {
            *hasCount = 1;
            *count = upperBound >= lowerBound ? (int32_t)(upperBound - lowerBound + 1) : 0;
        }
    }
    if (values != NULL) {
        SafeArrayDestroy(values);
    }
}

static void PeekabooWin11CopyElementTablePattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TablePatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationTablePattern *tablePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTablePattern,
        (void **)&tablePattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || tablePattern == NULL) {
        return;
    }

    enum RowOrColumnMajor rowOrColumnMajor = RowOrColumnMajor_RowMajor;
    HRESULT rowOrColumnMajorResult = IUIAutomationTablePattern_get_CurrentRowOrColumnMajor(
        tablePattern,
        &rowOrColumnMajor);
    if (PeekabooWin11Succeeded(rowOrColumnMajorResult)) {
        snapshot->hasTableRowOrColumnMajor = 1;
        snapshot->tableRowOrColumnMajor = (int32_t)rowOrColumnMajor;
    }

    IUIAutomationElementArray *rowHeaders = NULL;
    PeekabooWin11CopyElementArrayCount(
        IUIAutomationTablePattern_GetCurrentRowHeaders(tablePattern, &rowHeaders),
        rowHeaders,
        &snapshot->hasTableRowHeaderCount,
        &snapshot->tableRowHeaderCount);

    IUIAutomationElementArray *columnHeaders = NULL;
    PeekabooWin11CopyElementArrayCount(
        IUIAutomationTablePattern_GetCurrentColumnHeaders(tablePattern, &columnHeaders),
        columnHeaders,
        &snapshot->hasTableColumnHeaderCount,
        &snapshot->tableColumnHeaderCount);

    IUIAutomationTablePattern_Release(tablePattern);
}

static void PeekabooWin11CopyElementTableItemPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TableItemPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationTableItemPattern *tableItemPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTableItemPattern,
        (void **)&tableItemPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || tableItemPattern == NULL) {
        return;
    }

    IUIAutomationElementArray *rowHeaders = NULL;
    PeekabooWin11CopyElementArrayCount(
        IUIAutomationTableItemPattern_GetCurrentRowHeaderItems(tableItemPattern, &rowHeaders),
        rowHeaders,
        &snapshot->hasTableItemRowHeaderCount,
        &snapshot->tableItemRowHeaderCount);

    IUIAutomationElementArray *columnHeaders = NULL;
    PeekabooWin11CopyElementArrayCount(
        IUIAutomationTableItemPattern_GetCurrentColumnHeaderItems(tableItemPattern, &columnHeaders),
        columnHeaders,
        &snapshot->hasTableItemColumnHeaderCount,
        &snapshot->tableItemColumnHeaderCount);

    IUIAutomationTableItemPattern_Release(tableItemPattern);
}

static void PeekabooWin11CopyElementTransformPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TransformPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationTransformPattern *transformPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTransformPattern,
        (void **)&transformPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || transformPattern == NULL) {
        return;
    }

    BOOL canMove = FALSE;
    HRESULT canMoveResult = IUIAutomationTransformPattern_get_CurrentCanMove(
        transformPattern,
        &canMove);
    if (PeekabooWin11Succeeded(canMoveResult)) {
        snapshot->hasCanMove = 1;
        snapshot->canMove = canMove ? 1 : 0;
    }

    BOOL canResize = FALSE;
    HRESULT canResizeResult = IUIAutomationTransformPattern_get_CurrentCanResize(
        transformPattern,
        &canResize);
    if (PeekabooWin11Succeeded(canResizeResult)) {
        snapshot->hasCanResize = 1;
        snapshot->canResize = canResize ? 1 : 0;
    }

    BOOL canRotate = FALSE;
    HRESULT canRotateResult = IUIAutomationTransformPattern_get_CurrentCanRotate(
        transformPattern,
        &canRotate);
    if (PeekabooWin11Succeeded(canRotateResult)) {
        snapshot->hasCanRotate = 1;
        snapshot->canRotate = canRotate ? 1 : 0;
    }

    IUIAutomationTransformPattern_Release(transformPattern);
}

static void PeekabooWin11CopyElementTransform2Pattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TransformPattern2Id,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationTransformPattern2 *transformPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTransformPattern2,
        (void **)&transformPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || transformPattern == NULL) {
        return;
    }

    BOOL canZoom = FALSE;
    HRESULT canZoomResult = IUIAutomationTransformPattern2_get_CurrentCanZoom(
        transformPattern,
        &canZoom);
    if (PeekabooWin11Succeeded(canZoomResult)) {
        snapshot->hasCanZoom = 1;
        snapshot->canZoom = canZoom ? 1 : 0;
    }

    double zoomLevel = 0.0;
    HRESULT zoomLevelResult = IUIAutomationTransformPattern2_get_CurrentZoomLevel(
        transformPattern,
        &zoomLevel);
    if (PeekabooWin11Succeeded(zoomLevelResult)) {
        snapshot->hasZoomLevel = 1;
        snapshot->zoomLevel = zoomLevel;
    }

    double zoomMinimum = 0.0;
    HRESULT zoomMinimumResult = IUIAutomationTransformPattern2_get_CurrentZoomMinimum(
        transformPattern,
        &zoomMinimum);
    if (PeekabooWin11Succeeded(zoomMinimumResult)) {
        snapshot->hasZoomMinimum = 1;
        snapshot->zoomMinimum = zoomMinimum;
    }

    double zoomMaximum = 0.0;
    HRESULT zoomMaximumResult = IUIAutomationTransformPattern2_get_CurrentZoomMaximum(
        transformPattern,
        &zoomMaximum);
    if (PeekabooWin11Succeeded(zoomMaximumResult)) {
        snapshot->hasZoomMaximum = 1;
        snapshot->zoomMaximum = zoomMaximum;
    }

    IUIAutomationTransformPattern2_Release(transformPattern);
}

static void PeekabooWin11CopyElementMultipleViewPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_MultipleViewPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationMultipleViewPattern *multipleViewPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationMultipleViewPattern,
        (void **)&multipleViewPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || multipleViewPattern == NULL) {
        return;
    }

    int currentView = 0;
    HRESULT currentViewResult = IUIAutomationMultipleViewPattern_get_CurrentCurrentView(
        multipleViewPattern,
        &currentView);
    if (PeekabooWin11Succeeded(currentViewResult)) {
        snapshot->hasMultipleViewCurrentView = 1;
        snapshot->multipleViewCurrentView = (int32_t)currentView;

        BSTR viewName = NULL;
        HRESULT viewNameResult = IUIAutomationMultipleViewPattern_GetViewName(
            multipleViewPattern,
            currentView,
            &viewName);
        if (PeekabooWin11Succeeded(viewNameResult)) {
            snapshot->hasMultipleViewCurrentViewName = 1;
            PeekabooWin11CopyBSTR(
                viewName,
                snapshot->multipleViewCurrentViewName,
                PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
        }
        if (viewName != NULL) {
            SysFreeString(viewName);
        }
    }

    SAFEARRAY *supportedViews = NULL;
    HRESULT supportedViewsResult = IUIAutomationMultipleViewPattern_GetCurrentSupportedViews(
        multipleViewPattern,
        &supportedViews);
    if (PeekabooWin11Succeeded(supportedViewsResult) && supportedViews != NULL) {
        LONG lowerBound = 0;
        LONG upperBound = -1;
        HRESULT lowerBoundResult = SafeArrayGetLBound(supportedViews, 1, &lowerBound);
        HRESULT upperBoundResult = SafeArrayGetUBound(supportedViews, 1, &upperBound);
        if (PeekabooWin11Succeeded(lowerBoundResult) &&
            PeekabooWin11Succeeded(upperBoundResult))
        {
            snapshot->hasMultipleViewSupportedViewCount = 1;
            snapshot->multipleViewSupportedViewCount =
                upperBound >= lowerBound ? (int32_t)(upperBound - lowerBound + 1) : 0;
        }
        SafeArrayDestroy(supportedViews);
    }

    IUIAutomationMultipleViewPattern_Release(multipleViewPattern);
}

static void PeekabooWin11CopyPatternString(
    HRESULT result,
    BSTR value,
    int32_t *hasValue,
    char *target)
{
    if (PeekabooWin11Succeeded(result)) {
        *hasValue = 1;
        PeekabooWin11CopyBSTR(value, target, PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    }
    if (value != NULL) {
        SysFreeString(value);
    }
}

static void PeekabooWin11CopyElementAnnotationPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_AnnotationPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationAnnotationPattern *annotationPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationAnnotationPattern,
        (void **)&annotationPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || annotationPattern == NULL) {
        return;
    }

    int annotationTypeId = 0;
    HRESULT typeIdResult = IUIAutomationAnnotationPattern_get_CurrentAnnotationTypeId(
        annotationPattern,
        &annotationTypeId);
    if (PeekabooWin11Succeeded(typeIdResult)) {
        snapshot->hasAnnotationTypeId = 1;
        snapshot->annotationTypeId = (int32_t)annotationTypeId;
    }

    BSTR typeName = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationAnnotationPattern_get_CurrentAnnotationTypeName(annotationPattern, &typeName),
        typeName,
        &snapshot->hasAnnotationTypeName,
        snapshot->annotationTypeName);

    BSTR author = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationAnnotationPattern_get_CurrentAuthor(annotationPattern, &author),
        author,
        &snapshot->hasAnnotationAuthor,
        snapshot->annotationAuthor);

    BSTR dateTime = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationAnnotationPattern_get_CurrentDateTime(annotationPattern, &dateTime),
        dateTime,
        &snapshot->hasAnnotationDateTime,
        snapshot->annotationDateTime);

    IUIAutomationElement *targetElement = NULL;
    HRESULT targetResult = IUIAutomationAnnotationPattern_get_CurrentTarget(
        annotationPattern,
        &targetElement);
    if (PeekabooWin11Succeeded(targetResult) && targetElement != NULL) {
        BSTR targetName = NULL;
        PeekabooWin11CopyPatternString(
            IUIAutomationElement_get_CurrentName(targetElement, &targetName),
            targetName,
            &snapshot->hasAnnotationTargetName,
            snapshot->annotationTargetName);
        IUIAutomationElement_Release(targetElement);
    }

    IUIAutomationAnnotationPattern_Release(annotationPattern);
}

static void PeekabooWin11CopyElementStylesPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_StylesPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationStylesPattern *stylesPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationStylesPattern,
        (void **)&stylesPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || stylesPattern == NULL) {
        return;
    }

    int styleId = 0;
    HRESULT styleIdResult = IUIAutomationStylesPattern_get_CurrentStyleId(
        stylesPattern,
        &styleId);
    if (PeekabooWin11Succeeded(styleIdResult)) {
        snapshot->hasStyleId = 1;
        snapshot->styleId = (int32_t)styleId;
    }

    int fillColor = 0;
    HRESULT fillColorResult = IUIAutomationStylesPattern_get_CurrentFillColor(
        stylesPattern,
        &fillColor);
    if (PeekabooWin11Succeeded(fillColorResult)) {
        snapshot->hasStyleFillColor = 1;
        snapshot->styleFillColor = (int32_t)fillColor;
    }

    int fillPatternColor = 0;
    HRESULT fillPatternColorResult = IUIAutomationStylesPattern_get_CurrentFillPatternColor(
        stylesPattern,
        &fillPatternColor);
    if (PeekabooWin11Succeeded(fillPatternColorResult)) {
        snapshot->hasStyleFillPatternColor = 1;
        snapshot->styleFillPatternColor = (int32_t)fillPatternColor;
    }

    BSTR styleName = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationStylesPattern_get_CurrentStyleName(stylesPattern, &styleName),
        styleName,
        &snapshot->hasStyleName,
        snapshot->styleName);

    BSTR shape = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationStylesPattern_get_CurrentShape(stylesPattern, &shape),
        shape,
        &snapshot->hasStyleShape,
        snapshot->styleShape);

    BSTR extendedProperties = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationStylesPattern_get_CurrentExtendedProperties(
            stylesPattern,
            &extendedProperties),
        extendedProperties,
        &snapshot->hasStyleExtendedProperties,
        snapshot->styleExtendedProperties);

    IUIAutomationStylesPattern_Release(stylesPattern);
}

static void PeekabooWin11CopyElementDragPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_DragPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationDragPattern *dragPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationDragPattern,
        (void **)&dragPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || dragPattern == NULL) {
        return;
    }

    BOOL isGrabbed = FALSE;
    HRESULT isGrabbedResult = IUIAutomationDragPattern_get_CurrentIsGrabbed(
        dragPattern,
        &isGrabbed);
    if (PeekabooWin11Succeeded(isGrabbedResult)) {
        snapshot->hasDragIsGrabbed = 1;
        snapshot->dragIsGrabbed = isGrabbed ? 1 : 0;
    }

    BSTR dropEffect = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationDragPattern_get_CurrentDropEffect(dragPattern, &dropEffect),
        dropEffect,
        &snapshot->hasDragDropEffect,
        snapshot->dragDropEffect);

    SAFEARRAY *dropEffects = NULL;
    PeekabooWin11CopySafeArrayCount(
        IUIAutomationDragPattern_get_CurrentDropEffects(dragPattern, &dropEffects),
        dropEffects,
        &snapshot->hasDragDropEffectCount,
        &snapshot->dragDropEffectCount);

    IUIAutomationElementArray *grabbedItems = NULL;
    PeekabooWin11CopyElementArrayCount(
        IUIAutomationDragPattern_GetCurrentGrabbedItems(dragPattern, &grabbedItems),
        grabbedItems,
        &snapshot->hasDragGrabbedItemCount,
        &snapshot->dragGrabbedItemCount);

    IUIAutomationDragPattern_Release(dragPattern);
}

static void PeekabooWin11CopyElementDropTargetPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_DropTargetPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationDropTargetPattern *dropTargetPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationDropTargetPattern,
        (void **)&dropTargetPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || dropTargetPattern == NULL) {
        return;
    }

    BSTR dropTargetEffect = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationDropTargetPattern_get_CurrentDropTargetEffect(
            dropTargetPattern,
            &dropTargetEffect),
        dropTargetEffect,
        &snapshot->hasDropTargetEffect,
        snapshot->dropTargetEffect);

    SAFEARRAY *dropTargetEffects = NULL;
    PeekabooWin11CopySafeArrayCount(
        IUIAutomationDropTargetPattern_get_CurrentDropTargetEffects(
            dropTargetPattern,
            &dropTargetEffects),
        dropTargetEffects,
        &snapshot->hasDropTargetEffectCount,
        &snapshot->dropTargetEffectCount);

    IUIAutomationDropTargetPattern_Release(dropTargetPattern);
}

static void PeekabooWin11CopyElementLegacyIAccessiblePattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_LegacyIAccessiblePatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationLegacyIAccessiblePattern *legacyPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationLegacyIAccessiblePattern,
        (void **)&legacyPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || legacyPattern == NULL) {
        return;
    }

    int childId = 0;
    HRESULT childIdResult = IUIAutomationLegacyIAccessiblePattern_get_CurrentChildId(
        legacyPattern,
        &childId);
    if (PeekabooWin11Succeeded(childIdResult)) {
        snapshot->hasLegacyChildId = 1;
        snapshot->legacyChildId = (int32_t)childId;
    }

    DWORD role = 0;
    HRESULT roleResult = IUIAutomationLegacyIAccessiblePattern_get_CurrentRole(
        legacyPattern,
        &role);
    if (PeekabooWin11Succeeded(roleResult)) {
        snapshot->hasLegacyRole = 1;
        snapshot->legacyRole = (int32_t)role;
    }

    DWORD state = 0;
    HRESULT stateResult = IUIAutomationLegacyIAccessiblePattern_get_CurrentState(
        legacyPattern,
        &state);
    if (PeekabooWin11Succeeded(stateResult)) {
        snapshot->hasLegacyState = 1;
        snapshot->legacyState = (int32_t)state;
    }

    BSTR name = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationLegacyIAccessiblePattern_get_CurrentName(legacyPattern, &name),
        name,
        &snapshot->hasLegacyName,
        snapshot->legacyName);

    BSTR value = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationLegacyIAccessiblePattern_get_CurrentValue(legacyPattern, &value),
        value,
        &snapshot->hasLegacyValue,
        snapshot->legacyValue);

    BSTR description = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationLegacyIAccessiblePattern_get_CurrentDescription(legacyPattern, &description),
        description,
        &snapshot->hasLegacyDescription,
        snapshot->legacyDescription);

    BSTR help = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationLegacyIAccessiblePattern_get_CurrentHelp(legacyPattern, &help),
        help,
        &snapshot->hasLegacyHelp,
        snapshot->legacyHelp);

    BSTR shortcut = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationLegacyIAccessiblePattern_get_CurrentKeyboardShortcut(legacyPattern, &shortcut),
        shortcut,
        &snapshot->hasLegacyKeyboardShortcut,
        snapshot->legacyKeyboardShortcut);

    BSTR defaultAction = NULL;
    PeekabooWin11CopyPatternString(
        IUIAutomationLegacyIAccessiblePattern_get_CurrentDefaultAction(
            legacyPattern,
            &defaultAction),
        defaultAction,
        &snapshot->hasLegacyDefaultAction,
        snapshot->legacyDefaultAction);

    IUIAutomationLegacyIAccessiblePattern_Release(legacyPattern);
}

static void PeekabooWin11CopySelectionPatternFromElement(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_SelectionPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationSelectionPattern *selectionPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationSelectionPattern,
        (void **)&selectionPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || selectionPattern == NULL) {
        return;
    }

    BOOL canSelectMultiple = FALSE;
    HRESULT canSelectMultipleResult = IUIAutomationSelectionPattern_get_CurrentCanSelectMultiple(
        selectionPattern,
        &canSelectMultiple);
    if (PeekabooWin11Succeeded(canSelectMultipleResult)) {
        snapshot->hasSelectionCanSelectMultiple = 1;
        snapshot->selectionCanSelectMultiple = canSelectMultiple ? 1 : 0;
    }

    BOOL isSelectionRequired = FALSE;
    HRESULT isSelectionRequiredResult = IUIAutomationSelectionPattern_get_CurrentIsSelectionRequired(
        selectionPattern,
        &isSelectionRequired);
    if (PeekabooWin11Succeeded(isSelectionRequiredResult)) {
        snapshot->hasSelectionIsRequired = 1;
        snapshot->selectionIsRequired = isSelectionRequired ? 1 : 0;
    }

    IUIAutomationElementArray *selectedElements = NULL;
    HRESULT selectionResult = IUIAutomationSelectionPattern_GetCurrentSelection(
        selectionPattern,
        &selectedElements);
    if (PeekabooWin11Succeeded(selectionResult) && selectedElements != NULL) {
        int selectedCount = 0;
        HRESULT lengthResult = IUIAutomationElementArray_get_Length(
            selectedElements,
            &selectedCount);
        if (PeekabooWin11Succeeded(lengthResult)) {
            snapshot->hasSelectionSelectedItemCount = 1;
            snapshot->selectionSelectedItemCount = (int32_t)selectedCount;
        }
        IUIAutomationElementArray_Release(selectedElements);
    }

    IUIAutomationSelectionPattern_Release(selectionPattern);
}

static void PeekabooWin11CopyElementSelectionPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    PeekabooWin11CopySelectionPatternFromElement(element, snapshot);
}

static void PeekabooWin11CopyElementSelectionItemPattern(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationElementSnapshot *snapshot)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_SelectionItemPatternId,
        &patternObject);
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        return;
    }

    IUIAutomationSelectionItemPattern *selectionItemPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationSelectionItemPattern,
        (void **)&selectionItemPattern);
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || selectionItemPattern == NULL) {
        return;
    }

    BOOL isSelected = FALSE;
    HRESULT selectedResult = IUIAutomationSelectionItemPattern_get_CurrentIsSelected(
        selectionItemPattern,
        &isSelected);
    if (PeekabooWin11Succeeded(selectedResult)) {
        snapshot->hasIsSelected = 1;
        snapshot->isSelected = isSelected ? 1 : 0;
    }

    IUIAutomationElement *selectionContainer = NULL;
    HRESULT containerResult = IUIAutomationSelectionItemPattern_get_CurrentSelectionContainer(
        selectionItemPattern,
        &selectionContainer);
    if (PeekabooWin11Succeeded(containerResult) && selectionContainer != NULL) {
        PeekabooWin11CopySelectionPatternFromElement(selectionContainer, snapshot);
        IUIAutomationElement_Release(selectionContainer);
    }

    IUIAutomationSelectionItemPattern_Release(selectionItemPattern);
}

static void PeekabooWin11InvokeElement(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_InvokePatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationInvokePattern *invokePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationInvokePattern,
        (void **)&invokePattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || invokePattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationInvokePattern_Invoke(invokePattern);
    IUIAutomationInvokePattern_Release(invokePattern);
}

static void PeekabooWin11SetElementValue(
    IUIAutomationElement *element,
    const char *value,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_ValuePatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationValuePattern *valuePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationValuePattern,
        (void **)&valuePattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || valuePattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    BOOL isReadOnly = FALSE;
    HRESULT readOnlyResult = IUIAutomationValuePattern_get_CurrentIsReadOnly(
        valuePattern,
        &isReadOnly);
    result->readOnlyResult = (int32_t)readOnlyResult;
    result->isReadOnly = isReadOnly ? 1 : 0;
    if (PeekabooWin11Succeeded(readOnlyResult) && isReadOnly) {
        result->actionResult = (int32_t)E_ACCESSDENIED;
        IUIAutomationValuePattern_Release(valuePattern);
        return;
    }

    BSTR bstrValue = PeekabooWin11CopyUTF8BSTR(value);
    if (bstrValue == NULL) {
        result->actionResult = (int32_t)E_OUTOFMEMORY;
        IUIAutomationValuePattern_Release(valuePattern);
        return;
    }

    result->actionResult = (int32_t)IUIAutomationValuePattern_SetValue(
        valuePattern,
        bstrValue);
    SysFreeString(bstrValue);
    IUIAutomationValuePattern_Release(valuePattern);
}

static void PeekabooWin11SetElementRangeValue(
    IUIAutomationElement *element,
    double value,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_RangeValuePatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationRangeValuePattern *rangeValuePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationRangeValuePattern,
        (void **)&rangeValuePattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || rangeValuePattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    BOOL isReadOnly = FALSE;
    HRESULT readOnlyResult = IUIAutomationRangeValuePattern_get_CurrentIsReadOnly(
        rangeValuePattern,
        &isReadOnly);
    result->readOnlyResult = (int32_t)readOnlyResult;
    result->isReadOnly = isReadOnly ? 1 : 0;
    if (PeekabooWin11Succeeded(readOnlyResult) && isReadOnly) {
        result->actionResult = (int32_t)E_ACCESSDENIED;
        IUIAutomationRangeValuePattern_Release(rangeValuePattern);
        return;
    }

    result->actionResult = (int32_t)IUIAutomationRangeValuePattern_SetValue(
        rangeValuePattern,
        value);
    IUIAutomationRangeValuePattern_Release(rangeValuePattern);
}

static void PeekabooWin11SetElementScrollPercent(
    IUIAutomationElement *element,
    double horizontalPercent,
    double verticalPercent,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_ScrollPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationScrollPattern *scrollPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationScrollPattern,
        (void **)&scrollPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || scrollPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationScrollPattern_SetScrollPercent(
        scrollPattern,
        horizontalPercent,
        verticalPercent);
    IUIAutomationScrollPattern_Release(scrollPattern);
}

static void PeekabooWin11SetElementWindowVisualState(
    IUIAutomationElement *element,
    int32_t visualState,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_WindowPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationWindowPattern *windowPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationWindowPattern,
        (void **)&windowPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || windowPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationWindowPattern_SetWindowVisualState(
        windowPattern,
        (enum WindowVisualState)visualState);
    IUIAutomationWindowPattern_Release(windowPattern);
}

static void PeekabooWin11CloseWindow(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_WindowPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationWindowPattern *windowPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationWindowPattern,
        (void **)&windowPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || windowPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationWindowPattern_Close(windowPattern);
    IUIAutomationWindowPattern_Release(windowPattern);
}

static void PeekabooWin11WaitForWindowInputIdle(
    IUIAutomationElement *element,
    int32_t timeoutMilliseconds,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_WindowPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationWindowPattern *windowPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationWindowPattern,
        (void **)&windowPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || windowPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    BOOL didBecomeIdle = FALSE;
    result->actionResult = (int32_t)IUIAutomationWindowPattern_WaitForInputIdle(
        windowPattern,
        timeoutMilliseconds,
        &didBecomeIdle);
    if (PeekabooWin11Succeeded((HRESULT)result->actionResult)) {
        result->hasBoolResult = 1;
        result->boolResult = didBecomeIdle ? 1 : 0;
    }
    IUIAutomationWindowPattern_Release(windowPattern);
}

static void PeekabooWin11SetElementDockPosition(
    IUIAutomationElement *element,
    int32_t dockPosition,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_DockPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationDockPattern *dockPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationDockPattern,
        (void **)&dockPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || dockPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationDockPattern_SetDockPosition(
        dockPattern,
        (enum DockPosition)dockPosition);
    IUIAutomationDockPattern_Release(dockPattern);
}

static void PeekabooWin11SetElementCurrentView(
    IUIAutomationElement *element,
    int32_t viewId,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_MultipleViewPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationMultipleViewPattern *multipleViewPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationMultipleViewPattern,
        (void **)&multipleViewPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || multipleViewPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationMultipleViewPattern_SetCurrentView(
        multipleViewPattern,
        viewId);
    IUIAutomationMultipleViewPattern_Release(multipleViewPattern);
}

static void PeekabooWin11SetElementZoomLevel(
    IUIAutomationElement *element,
    double zoomLevel,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TransformPattern2Id,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationTransformPattern2 *transformPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTransformPattern2,
        (void **)&transformPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || transformPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationTransformPattern2_Zoom(
        transformPattern,
        zoomLevel);
    IUIAutomationTransformPattern2_Release(transformPattern);
}

static void PeekabooWin11ZoomElementByUnit(
    IUIAutomationElement *element,
    int32_t zoomUnit,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TransformPattern2Id,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationTransformPattern2 *transformPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTransformPattern2,
        (void **)&transformPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || transformPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationTransformPattern2_ZoomByUnit(
        transformPattern,
        (enum ZoomUnit)zoomUnit);
    IUIAutomationTransformPattern2_Release(transformPattern);
}

static void PeekabooWin11FocusElement(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationActionResult *result)
{
    result->actionResult = (int32_t)IUIAutomationElement_SetFocus(element);
}

static void PeekabooWin11PerformElementLegacyDefaultAction(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_LegacyIAccessiblePatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationLegacyIAccessiblePattern *legacyPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationLegacyIAccessiblePattern,
        (void **)&legacyPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || legacyPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationLegacyIAccessiblePattern_DoDefaultAction(
        legacyPattern);
    IUIAutomationLegacyIAccessiblePattern_Release(legacyPattern);
}

static void PeekabooWin11SetElementLegacyValue(
    IUIAutomationElement *element,
    const char *value,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_LegacyIAccessiblePatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationLegacyIAccessiblePattern *legacyPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationLegacyIAccessiblePattern,
        (void **)&legacyPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || legacyPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    BSTR bstrValue = PeekabooWin11CopyUTF8BSTR(value);
    if (bstrValue == NULL) {
        result->actionResult = (int32_t)E_OUTOFMEMORY;
        IUIAutomationLegacyIAccessiblePattern_Release(legacyPattern);
        return;
    }

    result->actionResult = (int32_t)IUIAutomationLegacyIAccessiblePattern_SetValue(
        legacyPattern,
        bstrValue);
    SysFreeString(bstrValue);
    IUIAutomationLegacyIAccessiblePattern_Release(legacyPattern);
}

static void PeekabooWin11TransformElement(
    IUIAutomationElement *element,
    int32_t action,
    double firstValue,
    double secondValue,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TransformPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationTransformPattern *transformPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTransformPattern,
        (void **)&transformPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || transformPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    if (action == PEEKABOO_WIN11_UIA_ACTION_MOVE) {
        result->actionResult = (int32_t)IUIAutomationTransformPattern_Move(
            transformPattern,
            firstValue,
            secondValue);
    } else if (action == PEEKABOO_WIN11_UIA_ACTION_RESIZE) {
        result->actionResult = (int32_t)IUIAutomationTransformPattern_Resize(
            transformPattern,
            firstValue,
            secondValue);
    } else {
        result->actionResult = (int32_t)IUIAutomationTransformPattern_Rotate(
            transformPattern,
            firstValue);
    }
    IUIAutomationTransformPattern_Release(transformPattern);
}

static void PeekabooWin11RealizeVirtualizedItem(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_VirtualizedItemPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationVirtualizedItemPattern *virtualizedItemPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationVirtualizedItemPattern,
        (void **)&virtualizedItemPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || virtualizedItemPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationVirtualizedItemPattern_Realize(
        virtualizedItemPattern);
    IUIAutomationVirtualizedItemPattern_Release(virtualizedItemPattern);
}

static void PeekabooWin11ToggleElement(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_TogglePatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationTogglePattern *togglePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationTogglePattern,
        (void **)&togglePattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || togglePattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationTogglePattern_Toggle(togglePattern);
    IUIAutomationTogglePattern_Release(togglePattern);
}

static void PeekabooWin11ExpandCollapseElement(
    IUIAutomationElement *element,
    int32_t shouldExpand,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_ExpandCollapsePatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationExpandCollapsePattern *expandCollapsePattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationExpandCollapsePattern,
        (void **)&expandCollapsePattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || expandCollapsePattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    if (shouldExpand) {
        result->actionResult = (int32_t)IUIAutomationExpandCollapsePattern_Expand(
            expandCollapsePattern);
    } else {
        result->actionResult = (int32_t)IUIAutomationExpandCollapsePattern_Collapse(
            expandCollapsePattern);
    }
    IUIAutomationExpandCollapsePattern_Release(expandCollapsePattern);
}

static void PeekabooWin11SelectElement(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_SelectionItemPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationSelectionItemPattern *selectionItemPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationSelectionItemPattern,
        (void **)&selectionItemPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || selectionItemPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationSelectionItemPattern_Select(
        selectionItemPattern);
    IUIAutomationSelectionItemPattern_Release(selectionItemPattern);
}

static void PeekabooWin11ChangeElementSelection(
    IUIAutomationElement *element,
    int32_t shouldAdd,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_SelectionItemPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationSelectionItemPattern *selectionItemPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationSelectionItemPattern,
        (void **)&selectionItemPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || selectionItemPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    if (shouldAdd) {
        result->actionResult = (int32_t)IUIAutomationSelectionItemPattern_AddToSelection(
            selectionItemPattern);
    } else {
        result->actionResult = (int32_t)IUIAutomationSelectionItemPattern_RemoveFromSelection(
            selectionItemPattern);
    }
    IUIAutomationSelectionItemPattern_Release(selectionItemPattern);
}

static void PeekabooWin11ScrollElementIntoView(
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationActionResult *result)
{
    IUnknown *patternObject = NULL;
    HRESULT patternResult = IUIAutomationElement_GetCurrentPattern(
        element,
        UIA_ScrollItemPatternId,
        &patternObject);
    result->patternResult = (int32_t)patternResult;
    if (!PeekabooWin11Succeeded(patternResult) || patternObject == NULL) {
        if (PeekabooWin11Succeeded(patternResult)) {
            result->patternResult = (int32_t)E_POINTER;
        }
        return;
    }

    IUIAutomationScrollItemPattern *scrollItemPattern = NULL;
    HRESULT queryResult = IUnknown_QueryInterface(
        patternObject,
        &IID_IUIAutomationScrollItemPattern,
        (void **)&scrollItemPattern);
    result->queryResult = (int32_t)queryResult;
    IUnknown_Release(patternObject);

    if (!PeekabooWin11Succeeded(queryResult) || scrollItemPattern == NULL) {
        if (PeekabooWin11Succeeded(queryResult)) {
            result->queryResult = (int32_t)E_POINTER;
        }
        return;
    }

    result->actionResult = (int32_t)IUIAutomationScrollItemPattern_ScrollIntoView(
        scrollItemPattern);
    IUIAutomationScrollItemPattern_Release(scrollItemPattern);
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
    PeekabooWin11CopyElementAccessKey(
        element,
        snapshot->accessKey,
        PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    PeekabooWin11CopyElementAcceleratorKey(
        element,
        snapshot->acceleratorKey,
        PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    PeekabooWin11CopyElementFrameworkId(
        element,
        snapshot->frameworkId,
        PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    PeekabooWin11CopyElementHelpText(
        element,
        snapshot->helpText,
        PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    PeekabooWin11CopyElementItemStatus(
        element,
        snapshot->itemStatus,
        PEEKABOO_WIN11_UIA_TEXT_CAPACITY);
    PeekabooWin11CopyElementItemType(
        element,
        snapshot->itemType,
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

    POINT clickablePoint = {0, 0};
    BOOL gotClickable = FALSE;
    if (PeekabooWin11Succeeded(
        IUIAutomationElement_GetClickablePoint(element, &clickablePoint, &gotClickable)))
    {
        snapshot->hasClickablePointResult = 1;
        snapshot->hasClickablePoint = gotClickable ? 1 : 0;
        if (gotClickable) {
            snapshot->clickablePointX = (int32_t)clickablePoint.x;
            snapshot->clickablePointY = (int32_t)clickablePoint.y;
        }
    }

    PeekabooWin11CopyElementPatterns(element, snapshot);
    PeekabooWin11CopyElementValuePattern(element, snapshot);
    PeekabooWin11CopyElementRangeValuePattern(element, snapshot);
    PeekabooWin11CopyElementScrollPattern(element, snapshot);
    PeekabooWin11CopyElementTogglePattern(element, snapshot);
    PeekabooWin11CopyElementExpandCollapsePattern(element, snapshot);
    PeekabooWin11CopyElementWindowPattern(element, snapshot);
    PeekabooWin11CopyElementDockPattern(element, snapshot);
    PeekabooWin11CopyElementTextPattern(element, snapshot);
    PeekabooWin11CopyElementTextPattern2(element, snapshot);
    PeekabooWin11CopyElementTextEditPattern(element, snapshot);
    PeekabooWin11CopyElementTextChildPattern(element, snapshot);
    PeekabooWin11CopyElementGridPattern(element, snapshot);
    PeekabooWin11CopyElementGridItemPattern(element, snapshot);
    PeekabooWin11CopyElementTablePattern(element, snapshot);
    PeekabooWin11CopyElementTableItemPattern(element, snapshot);
    PeekabooWin11CopyElementTransformPattern(element, snapshot);
    PeekabooWin11CopyElementTransform2Pattern(element, snapshot);
    PeekabooWin11CopyElementMultipleViewPattern(element, snapshot);
    PeekabooWin11CopyElementAnnotationPattern(element, snapshot);
    PeekabooWin11CopyElementStylesPattern(element, snapshot);
    PeekabooWin11CopyElementDragPattern(element, snapshot);
    PeekabooWin11CopyElementDropTargetPattern(element, snapshot);
    PeekabooWin11CopyElementLegacyIAccessiblePattern(element, snapshot);
    PeekabooWin11CopyElementSelectionPattern(element, snapshot);
    PeekabooWin11CopyElementSelectionItemPattern(element, snapshot);
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

static int32_t PeekabooWin11VisitElementForAction(
    IUIAutomationTreeWalker *walker,
    IUIAutomationElement *element,
    PeekabooWin11UIAutomationActionResult *result,
    const char *value,
    double rangeValue,
    double horizontalScrollPercent,
    double verticalScrollPercent,
    int32_t windowVisualState,
    int32_t dockPosition,
    double transformFirstValue,
    double transformSecondValue,
    int32_t depth)
{
    if (result->elementCount >= result->maxElements) {
        result->didTruncate = 1;
        return -1;
    }

    int32_t index = result->elementCount;
    result->elementCount += 1;

    if (index == result->elementIndex) {
        result->foundElement = 1;
        if (result->action == PEEKABOO_WIN11_UIA_ACTION_TOGGLE) {
            PeekabooWin11ToggleElement(element, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_EXPAND) {
            PeekabooWin11ExpandCollapseElement(element, 1, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_COLLAPSE) {
            PeekabooWin11ExpandCollapseElement(element, 0, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SELECT) {
            PeekabooWin11SelectElement(element, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_ADD_TO_SELECTION) {
            PeekabooWin11ChangeElementSelection(element, 1, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_REMOVE_FROM_SELECTION) {
            PeekabooWin11ChangeElementSelection(element, 0, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SCROLL_INTO_VIEW) {
            PeekabooWin11ScrollElementIntoView(element, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SET_RANGE_VALUE) {
            PeekabooWin11SetElementRangeValue(element, rangeValue, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SET_SCROLL_PERCENT) {
            PeekabooWin11SetElementScrollPercent(
                element,
                horizontalScrollPercent,
                verticalScrollPercent,
                result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SET_WINDOW_VISUAL_STATE) {
            PeekabooWin11SetElementWindowVisualState(element, windowVisualState, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_CLOSE_WINDOW) {
            PeekabooWin11CloseWindow(element, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_WAIT_FOR_WINDOW_INPUT_IDLE) {
            PeekabooWin11WaitForWindowInputIdle(element, windowVisualState, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SET_DOCK_POSITION) {
            PeekabooWin11SetElementDockPosition(element, dockPosition, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SET_CURRENT_VIEW) {
            PeekabooWin11SetElementCurrentView(element, (int32_t)transformFirstValue, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SET_ZOOM_LEVEL) {
            PeekabooWin11SetElementZoomLevel(element, transformFirstValue, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_ZOOM_BY_UNIT) {
            PeekabooWin11ZoomElementByUnit(element, dockPosition, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_FOCUS) {
            PeekabooWin11FocusElement(element, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_PERFORM_LEGACY_DEFAULT_ACTION) {
            PeekabooWin11PerformElementLegacyDefaultAction(element, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SET_LEGACY_VALUE) {
            PeekabooWin11SetElementLegacyValue(element, value, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_MOVE ||
            result->action == PEEKABOO_WIN11_UIA_ACTION_RESIZE ||
            result->action == PEEKABOO_WIN11_UIA_ACTION_ROTATE)
        {
            PeekabooWin11TransformElement(
                element,
                result->action,
                transformFirstValue,
                transformSecondValue,
                result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_REALIZE_VIRTUALIZED_ITEM) {
            PeekabooWin11RealizeVirtualizedItem(element, result);
        } else if (result->action == PEEKABOO_WIN11_UIA_ACTION_SET_VALUE) {
            PeekabooWin11SetElementValue(element, value, result);
        } else {
            PeekabooWin11InvokeElement(element, result);
        }
        return index;
    }

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

        PeekabooWin11VisitElementForAction(
            walker,
            child,
            result,
            value,
            rangeValue,
            horizontalScrollPercent,
            verticalScrollPercent,
            windowVisualState,
            dockPosition,
            transformFirstValue,
            transformSecondValue,
            depth + 1);
        if (result->foundElement) {
            IUIAutomationElement_Release(child);
            break;
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

static PeekabooWin11UIAutomationActionResult PeekabooWin11PerformUIAutomationAction(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t action,
    const char *value,
    double rangeValue,
    double horizontalScrollPercent,
    double verticalScrollPercent,
    int32_t windowVisualState,
    int32_t dockPosition,
    double transformFirstValue,
    double transformSecondValue)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = action;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;

    if (scope != 0 && scope != 1 && scope != 2 && scope != 3) {
        result.errorResult = (int32_t)E_INVALIDARG;
        return result;
    }
    if (maxDepth < 0 || maxElements < 1 || elementIndex < 0) {
        result.errorResult = (int32_t)E_INVALIDARG;
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
        PeekabooWin11VisitElementForAction(
            walker,
            rootElement,
            &result,
            value,
            rangeValue,
            horizontalScrollPercent,
            verticalScrollPercent,
            windowVisualState,
            dockPosition,
            transformFirstValue,
            transformSecondValue,
            0);
        IUIAutomationTreeWalker_Release(walker);
    }

    IUIAutomationElement_Release(rootElement);
    IUIAutomation_Release(automation);

    if (result.didInitializeCOM) {
        CoUninitialize();
    }

    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11InvokeUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_INVOKE,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11FocusUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_FOCUS,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11PerformUIAutomationElementLegacyDefaultAction(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_PERFORM_LEGACY_DEFAULT_ACTION,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementLegacyValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    const char *value)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SET_LEGACY_VALUE,
        value,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    const char *value)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SET_VALUE,
        value,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementRangeValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double value)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SET_RANGE_VALUE,
        NULL,
        value,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementScrollPercent(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double horizontalPercent,
    double verticalPercent)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SET_SCROLL_PERCENT,
        NULL,
        0.0,
        horizontalPercent,
        verticalPercent,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementWindowVisualState(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t visualState)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SET_WINDOW_VISUAL_STATE,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        visualState,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11CloseUIAutomationWindow(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_CLOSE_WINDOW,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11WaitForUIAutomationWindowInputIdle(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t timeoutMilliseconds)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_WAIT_FOR_WINDOW_INPUT_IDLE,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        timeoutMilliseconds,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementDockPosition(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t dockPosition)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SET_DOCK_POSITION,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        dockPosition,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementCurrentView(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t viewId)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SET_CURRENT_VIEW,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        (double)viewId,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementZoomLevel(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double zoomLevel)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SET_ZOOM_LEVEL,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        zoomLevel,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ZoomUIAutomationElementByUnit(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t zoomUnit)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_ZOOM_BY_UNIT,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        zoomUnit,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11MoveUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double x,
    double y)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_MOVE,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        x,
        y);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ResizeUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double width,
    double height)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_RESIZE,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        width,
        height);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11RotateUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double degrees)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_ROTATE,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        degrees,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11RealizeUIAutomationVirtualizedItem(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_REALIZE_VIRTUALIZED_ITEM,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ToggleUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_TOGGLE,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ExpandUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_EXPAND,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11CollapseUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_COLLAPSE,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SelectUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SELECT,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11AddUIAutomationElementToSelection(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_ADD_TO_SELECTION,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11RemoveUIAutomationElementFromSelection(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_REMOVE_FROM_SELECTION,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ScrollUIAutomationElementIntoView(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    return PeekabooWin11PerformUIAutomationAction(
        scope,
        maxDepth,
        maxElements,
        elementIndex,
        PEEKABOO_WIN11_UIA_ACTION_SCROLL_INTO_VIEW,
        NULL,
        0.0,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        PEEKABOO_WIN11_UIA_SCROLL_NO_SCROLL,
        0,
        0,
        0.0,
        0.0);
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

PeekabooWin11UIAutomationActionResult PeekabooWin11InvokeUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 1;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11FocusUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 17;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11PerformUIAutomationElementLegacyDefaultAction(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 18;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementLegacyValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    const char *value)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 19;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)value;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    const char *value)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 2;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)value;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementRangeValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double value)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 7;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)value;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementScrollPercent(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double horizontalPercent,
    double verticalPercent)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 8;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)horizontalPercent;
    (void)verticalPercent;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementWindowVisualState(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t visualState)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 9;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)visualState;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11CloseUIAutomationWindow(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 20;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11WaitForUIAutomationWindowInputIdle(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t timeoutMilliseconds)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 21;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)timeoutMilliseconds;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementDockPosition(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t dockPosition)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 16;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)dockPosition;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementCurrentView(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t viewId)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 22;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)viewId;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementZoomLevel(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double zoomLevel)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 23;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)zoomLevel;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ZoomUIAutomationElementByUnit(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t zoomUnit)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 24;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)zoomUnit;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11MoveUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double x,
    double y)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 10;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)x;
    (void)y;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ResizeUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double width,
    double height)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 11;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)width;
    (void)height;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11RotateUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double degrees)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 12;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    (void)degrees;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11RealizeUIAutomationVirtualizedItem(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 25;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ToggleUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 3;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ExpandUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 4;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11CollapseUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 5;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11SelectUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 6;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11AddUIAutomationElementToSelection(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 14;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11RemoveUIAutomationElementFromSelection(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 15;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
    result.initializeResult = -2147467263;
    return result;
}

PeekabooWin11UIAutomationActionResult PeekabooWin11ScrollUIAutomationElementIntoView(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex)
{
    PeekabooWin11UIAutomationActionResult result;
    memset(&result, 0, sizeof(result));
    result.action = 13;
    result.scope = scope;
    result.maxDepth = maxDepth;
    result.maxElements = maxElements;
    result.elementIndex = elementIndex;
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

const char *PeekabooWin11UIAutomationElementAccessKey(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->accessKey;
}

const char *PeekabooWin11UIAutomationElementAcceleratorKey(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->acceleratorKey;
}

const char *PeekabooWin11UIAutomationElementFrameworkId(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->frameworkId;
}

const char *PeekabooWin11UIAutomationElementHelpText(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->helpText;
}

const char *PeekabooWin11UIAutomationElementItemStatus(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->itemStatus;
}

const char *PeekabooWin11UIAutomationElementItemType(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->itemType;
}

const char *PeekabooWin11UIAutomationElementValue(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->value;
}

const char *PeekabooWin11UIAutomationElementText(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->text;
}

const char *PeekabooWin11UIAutomationElementSelectedText(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->selectedText;
}

const char *PeekabooWin11UIAutomationElementVisibleText(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->visibleText;
}

const char *PeekabooWin11UIAutomationElementTextChildContainerName(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->textChildContainerName;
}

const char *PeekabooWin11UIAutomationElementMultipleViewCurrentViewName(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->multipleViewCurrentViewName;
}

const char *PeekabooWin11UIAutomationElementAnnotationTypeName(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->annotationTypeName;
}

const char *PeekabooWin11UIAutomationElementAnnotationAuthor(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->annotationAuthor;
}

const char *PeekabooWin11UIAutomationElementAnnotationDateTime(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->annotationDateTime;
}

const char *PeekabooWin11UIAutomationElementAnnotationTargetName(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->annotationTargetName;
}

const char *PeekabooWin11UIAutomationElementStyleName(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->styleName;
}

const char *PeekabooWin11UIAutomationElementStyleShape(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->styleShape;
}

const char *PeekabooWin11UIAutomationElementStyleExtendedProperties(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->styleExtendedProperties;
}

const char *PeekabooWin11UIAutomationElementDragDropEffect(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->dragDropEffect;
}

const char *PeekabooWin11UIAutomationElementDropTargetEffect(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->dropTargetEffect;
}

const char *PeekabooWin11UIAutomationElementLegacyName(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->legacyName;
}

const char *PeekabooWin11UIAutomationElementLegacyValue(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->legacyValue;
}

const char *PeekabooWin11UIAutomationElementLegacyDescription(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->legacyDescription;
}

const char *PeekabooWin11UIAutomationElementLegacyHelp(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->legacyHelp;
}

const char *PeekabooWin11UIAutomationElementLegacyKeyboardShortcut(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->legacyKeyboardShortcut;
}

const char *PeekabooWin11UIAutomationElementLegacyDefaultAction(
    const PeekabooWin11UIAutomationElementSnapshot *element)
{
    return element == NULL ? "" : element->legacyDefaultAction;
}
