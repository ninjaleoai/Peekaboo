#include "PeekabooWin11Interop.h"

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
#else
PeekabooWin11UIAutomationProbeResult PeekabooWin11ProbeUIAutomation(void) {
    PeekabooWin11UIAutomationProbeResult result = {0, 0, 0, -2147467263, 0, 0};
    return result;
}
#endif
