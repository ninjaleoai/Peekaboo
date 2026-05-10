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
    int32_t hasValue;
    int32_t hasIsValueReadOnly;
    int32_t isValueReadOnly;
    int32_t hasRangeValue;
    double rangeValue;
    int32_t hasRangeMinimum;
    double rangeMinimum;
    int32_t hasRangeMaximum;
    double rangeMaximum;
    int32_t hasRangeSmallChange;
    double rangeSmallChange;
    int32_t hasRangeLargeChange;
    double rangeLargeChange;
    int32_t hasIsRangeValueReadOnly;
    int32_t isRangeValueReadOnly;
    int32_t hasHorizontalScrollPercent;
    double horizontalScrollPercent;
    int32_t hasVerticalScrollPercent;
    double verticalScrollPercent;
    int32_t hasHorizontalScrollViewSize;
    double horizontalScrollViewSize;
    int32_t hasVerticalScrollViewSize;
    double verticalScrollViewSize;
    int32_t hasIsHorizontallyScrollable;
    int32_t isHorizontallyScrollable;
    int32_t hasIsVerticallyScrollable;
    int32_t isVerticallyScrollable;
    int32_t hasToggleState;
    int32_t toggleState;
    int32_t hasExpandCollapseState;
    int32_t expandCollapseState;
    int32_t hasWindowVisualState;
    int32_t windowVisualState;
    int32_t hasWindowInteractionState;
    int32_t windowInteractionState;
    int32_t hasCanMaximizeWindow;
    int32_t canMaximizeWindow;
    int32_t hasCanMinimizeWindow;
    int32_t canMinimizeWindow;
    int32_t hasIsModalWindow;
    int32_t isModalWindow;
    int32_t hasIsTopmostWindow;
    int32_t isTopmostWindow;
    int32_t hasDockPosition;
    int32_t dockPosition;
    int32_t hasText;
    int32_t hasSupportedTextSelection;
    int32_t supportedTextSelection;
    int32_t hasGridRowCount;
    int32_t gridRowCount;
    int32_t hasGridColumnCount;
    int32_t gridColumnCount;
    int32_t hasGridItemRow;
    int32_t gridItemRow;
    int32_t hasGridItemColumn;
    int32_t gridItemColumn;
    int32_t hasGridItemRowSpan;
    int32_t gridItemRowSpan;
    int32_t hasGridItemColumnSpan;
    int32_t gridItemColumnSpan;
    int32_t hasSelectionCanSelectMultiple;
    int32_t selectionCanSelectMultiple;
    int32_t hasSelectionIsRequired;
    int32_t selectionIsRequired;
    int32_t hasSelectionSelectedItemCount;
    int32_t selectionSelectedItemCount;
    int32_t hasCanMove;
    int32_t canMove;
    int32_t hasCanResize;
    int32_t canResize;
    int32_t hasCanRotate;
    int32_t canRotate;
    int32_t hasLegacyChildId;
    int32_t legacyChildId;
    int32_t hasLegacyRole;
    int32_t legacyRole;
    int32_t hasLegacyState;
    int32_t legacyState;
    int32_t hasLegacyName;
    int32_t hasLegacyValue;
    int32_t hasLegacyDescription;
    int32_t hasLegacyHelp;
    int32_t hasLegacyKeyboardShortcut;
    int32_t hasLegacyDefaultAction;
    int32_t hasIsSelected;
    int32_t isSelected;
    int32_t childCount;
    char name[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char automationIdentifier[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char className[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char localizedControlType[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char value[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char text[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char legacyName[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char legacyValue[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char legacyDescription[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char legacyHelp[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char legacyKeyboardShortcut[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char legacyDefaultAction[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
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

typedef struct PeekabooWin11UIAutomationActionResult {
    int32_t action;
    int32_t scope;
    int32_t maxDepth;
    int32_t maxElements;
    int32_t elementIndex;
    int32_t elementCount;
    int32_t didTruncate;
    int32_t didInitializeCOM;
    int32_t initializeResult;
    int32_t createResult;
    int32_t rootResult;
    int32_t walkerResult;
    int32_t errorResult;
    int32_t foundElement;
    int32_t patternResult;
    int32_t queryResult;
    int32_t readOnlyResult;
    int32_t isReadOnly;
    int32_t actionResult;
} PeekabooWin11UIAutomationActionResult;

PeekabooWin11UIAutomationSnapshotResult PeekabooWin11CopyUIAutomationSnapshot(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements);

PeekabooWin11UIAutomationActionResult PeekabooWin11InvokeUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11FocusUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    const char *value);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementRangeValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double value);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementScrollPercent(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double horizontalPercent,
    double verticalPercent);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementWindowVisualState(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t visualState);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementDockPosition(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t dockPosition);

PeekabooWin11UIAutomationActionResult PeekabooWin11MoveUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double x,
    double y);

PeekabooWin11UIAutomationActionResult PeekabooWin11ResizeUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double width,
    double height);

PeekabooWin11UIAutomationActionResult PeekabooWin11RotateUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double degrees);

PeekabooWin11UIAutomationActionResult PeekabooWin11ToggleUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11ExpandUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11CollapseUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11SelectUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11AddUIAutomationElementToSelection(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11RemoveUIAutomationElementFromSelection(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11ScrollUIAutomationElementIntoView(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

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

const char *PeekabooWin11UIAutomationElementValue(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementText(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementLegacyName(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementLegacyValue(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementLegacyDescription(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementLegacyHelp(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementLegacyKeyboardShortcut(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementLegacyDefaultAction(
    const PeekabooWin11UIAutomationElementSnapshot *element);

#ifdef __cplusplus
}
#endif

#endif
