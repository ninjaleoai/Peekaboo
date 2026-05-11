#ifndef PEEKABOO_WIN11_INTEROP_H
#define PEEKABOO_WIN11_INTEROP_H

#include <stdint.h>

#define PEEKABOO_WIN11_UIA_TEXT_CAPACITY 256
#define PEEKABOO_WIN11_UIA_ACTION_TEXT_CAPACITY 4097

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
    int32_t hasClickablePointResult;
    int32_t hasClickablePoint;
    int32_t clickablePointX;
    int32_t clickablePointY;
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
    int32_t hasSelectedText;
    int32_t hasSelectedTextRangeCount;
    int32_t selectedTextRangeCount;
    int32_t hasVisibleText;
    int32_t hasVisibleTextRangeCount;
    int32_t visibleTextRangeCount;
    int32_t hasSupportedTextSelection;
    int32_t supportedTextSelection;
    int32_t hasTextCaretIsActive;
    int32_t textCaretIsActive;
    int32_t hasTextCaretBoundingRectangleCount;
    int32_t textCaretBoundingRectangleCount;
    int32_t hasTextEditActiveComposition;
    int32_t textEditHasActiveComposition;
    int32_t hasTextEditActiveCompositionBoundingRectangleCount;
    int32_t textEditActiveCompositionBoundingRectangleCount;
    int32_t hasTextEditConversionTarget;
    int32_t textEditHasConversionTarget;
    int32_t hasTextEditConversionTargetBoundingRectangleCount;
    int32_t textEditConversionTargetBoundingRectangleCount;
    int32_t hasTextChildContainerName;
    int32_t hasTextChildTextRange;
    int32_t textChildHasTextRange;
    int32_t hasTextChildRangeBoundingRectangleCount;
    int32_t textChildRangeBoundingRectangleCount;
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
    int32_t hasSpreadsheetItemFormula;
    int32_t hasSpreadsheetItemAnnotationObjectCount;
    int32_t spreadsheetItemAnnotationObjectCount;
    int32_t hasSpreadsheetItemAnnotationTypeCount;
    int32_t spreadsheetItemAnnotationTypeCount;
    int32_t hasTableRowOrColumnMajor;
    int32_t tableRowOrColumnMajor;
    int32_t hasTableRowHeaderCount;
    int32_t tableRowHeaderCount;
    int32_t hasTableColumnHeaderCount;
    int32_t tableColumnHeaderCount;
    int32_t hasTableItemRowHeaderCount;
    int32_t tableItemRowHeaderCount;
    int32_t hasTableItemColumnHeaderCount;
    int32_t tableItemColumnHeaderCount;
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
    int32_t hasCanZoom;
    int32_t canZoom;
    int32_t hasZoomLevel;
    double zoomLevel;
    int32_t hasZoomMinimum;
    double zoomMinimum;
    int32_t hasZoomMaximum;
    double zoomMaximum;
    int32_t hasMultipleViewCurrentView;
    int32_t multipleViewCurrentView;
    int32_t hasMultipleViewSupportedViewCount;
    int32_t multipleViewSupportedViewCount;
    int32_t hasMultipleViewCurrentViewName;
    int32_t hasAnnotationTypeId;
    int32_t annotationTypeId;
    int32_t hasAnnotationTypeName;
    int32_t hasAnnotationAuthor;
    int32_t hasAnnotationDateTime;
    int32_t hasAnnotationTargetName;
    int32_t hasStyleId;
    int32_t styleId;
    int32_t hasStyleFillColor;
    int32_t styleFillColor;
    int32_t hasStyleFillPatternColor;
    int32_t styleFillPatternColor;
    int32_t hasStyleName;
    int32_t hasStyleShape;
    int32_t hasStyleExtendedProperties;
    int32_t hasDragDropEffect;
    int32_t hasDragDropEffectCount;
    int32_t dragDropEffectCount;
    int32_t hasDragIsGrabbed;
    int32_t dragIsGrabbed;
    int32_t hasDragGrabbedItemCount;
    int32_t dragGrabbedItemCount;
    int32_t hasDropTargetEffect;
    int32_t hasDropTargetEffectCount;
    int32_t dropTargetEffectCount;
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
    char accessKey[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char acceleratorKey[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char frameworkId[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char helpText[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char itemStatus[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char itemType[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char value[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char text[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char selectedText[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char visibleText[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char textChildContainerName[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char spreadsheetItemFormula[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char multipleViewCurrentViewName[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char annotationTypeName[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char annotationAuthor[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char annotationDateTime[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char annotationTargetName[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char styleName[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char styleShape[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char styleExtendedProperties[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char dragDropEffect[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
    char dropTargetEffect[PEEKABOO_WIN11_UIA_TEXT_CAPACITY];
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
    int32_t hasBoolResult;
    int32_t boolResult;
    int32_t hasTextResult;
    char textResult[PEEKABOO_WIN11_UIA_ACTION_TEXT_CAPACITY];
    int32_t hasResultElement;
    PeekabooWin11UIAutomationElementSnapshot resultElement;
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

PeekabooWin11UIAutomationActionResult PeekabooWin11PerformUIAutomationElementLegacyDefaultAction(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementLegacyValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    const char *value);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementValue(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    const char *value);

PeekabooWin11UIAutomationActionResult PeekabooWin11GetUIAutomationText(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t source,
    int32_t maxLength);

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

PeekabooWin11UIAutomationActionResult PeekabooWin11ScrollUIAutomationElement(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t horizontalAmount,
    int32_t verticalAmount);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementWindowVisualState(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t visualState);

PeekabooWin11UIAutomationActionResult PeekabooWin11CloseUIAutomationWindow(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11WaitForUIAutomationWindowInputIdle(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t timeoutMilliseconds);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementDockPosition(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t dockPosition);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementCurrentView(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t viewId);

PeekabooWin11UIAutomationActionResult PeekabooWin11SetUIAutomationElementZoomLevel(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    double zoomLevel);

PeekabooWin11UIAutomationActionResult PeekabooWin11ZoomUIAutomationElementByUnit(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t zoomUnit);

PeekabooWin11UIAutomationActionResult PeekabooWin11StartUIAutomationSynchronizedInput(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t inputType);

PeekabooWin11UIAutomationActionResult PeekabooWin11CancelUIAutomationSynchronizedInput(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

PeekabooWin11UIAutomationActionResult PeekabooWin11NavigateUIAutomationCustom(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t direction);

PeekabooWin11UIAutomationActionResult PeekabooWin11GetUIAutomationSpreadsheetItemByName(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    const char *name);

PeekabooWin11UIAutomationActionResult PeekabooWin11FindUIAutomationItemByProperty(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t property,
    const char *value);

PeekabooWin11UIAutomationActionResult PeekabooWin11GetUIAutomationGridItem(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex,
    int32_t row,
    int32_t column);

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

PeekabooWin11UIAutomationActionResult PeekabooWin11RealizeUIAutomationVirtualizedItem(
    int32_t scope,
    int32_t maxDepth,
    int32_t maxElements,
    int32_t elementIndex);

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

const char *PeekabooWin11UIAutomationElementAccessKey(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementAcceleratorKey(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementFrameworkId(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementHelpText(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementItemStatus(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementItemType(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementValue(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementText(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementSelectedText(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementVisibleText(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementTextChildContainerName(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementSpreadsheetItemFormula(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementMultipleViewCurrentViewName(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementAnnotationTypeName(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementAnnotationAuthor(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementAnnotationDateTime(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementAnnotationTargetName(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementStyleName(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementStyleShape(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementStyleExtendedProperties(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementDragDropEffect(
    const PeekabooWin11UIAutomationElementSnapshot *element);

const char *PeekabooWin11UIAutomationElementDropTargetEffect(
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

const char *PeekabooWin11UIAutomationActionTextResult(
    const PeekabooWin11UIAutomationActionResult *action);

#ifdef __cplusplus
}
#endif

#endif
