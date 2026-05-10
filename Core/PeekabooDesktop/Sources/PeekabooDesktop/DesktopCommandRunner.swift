import Foundation

public enum DesktopCommandRunner {
    public typealias OutputHandler = (String) -> Void

    public static func run(
        arguments: [String] = CommandLine.arguments,
        adapter: any DesktopAdapter,
        commandName: String = "peekaboo-desktop",
        stdout: OutputHandler = { print($0) },
        stderr: OutputHandler = { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }) -> Int32
    {
        let args = Array(arguments.dropFirst())
        guard let command = args.first else {
            stdout(self.helpText(commandName: commandName, adapter: adapter))
            return 0
        }

        do {
            switch command {
            case "platform-info":
                try stdout(self.success(adapter.platformInfo()))
            case "list":
                try self.runList(args: Array(args.dropFirst()), adapter: adapter, stdout: stdout)
            case "capture":
                try self.runCapture(args: Array(args.dropFirst()), adapter: adapter, stdout: stdout)
            case "input":
                try self.runInput(args: Array(args.dropFirst()), adapter: adapter, stdout: stdout)
            case "automation", "uia":
                try self.runAutomation(args: Array(args.dropFirst()), adapter: adapter, stdout: stdout)
            case "help", "--help", "-h":
                stdout(self.helpText(commandName: commandName, adapter: adapter))
            default:
                throw DesktopAdapterError.invalidArgument("Unknown command: \(command)")
            }
            return 0
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            stderr(message)
            return 1
        }
    }

    private static func runInput(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        guard let subcommand = args.first else {
            throw DesktopAdapterError.invalidArgument(
                "Missing input subcommand: position, move, click, scroll, drag, hotkey, or type")
        }

        switch subcommand {
        case "position", "cursor-position":
            try stdout(self.success(adapter.cursorPosition()))
        case "move", "move-cursor":
            let pointValue = try self.value(after: "--point", in: args) ??
                self.value(after: "--to", in: args)
            guard let pointValue else {
                throw DesktopAdapterError.invalidArgument("Missing --point x,y for input move")
            }
            try stdout(self.success(adapter.moveCursor(to: self.parsePoint(pointValue))))
        case "click", "mouse-click":
            let pointValue = try self.value(after: "--point", in: args) ??
                self.value(after: "--at", in: args)
            guard let pointValue else {
                throw DesktopAdapterError.invalidArgument("Missing --point x,y for input click")
            }
            let button = try self.value(after: "--button", in: args)
                .map(self.parseMouseButton) ?? .left
            let clickCount = try self.value(after: "--count", in: args)
                .map(self.parseClickCount) ?? 1
            try stdout(self.success(adapter.click(
                at: self.parsePoint(pointValue),
                button: button,
                clickCount: clickCount)))
        case "scroll", "mouse-scroll":
            let pointValue = try self.value(after: "--point", in: args) ??
                self.value(after: "--at", in: args)
            guard let pointValue else {
                throw DesktopAdapterError.invalidArgument("Missing --point x,y for input scroll")
            }
            let directionValue = try self.value(after: "--direction", in: args) ??
                self.value(after: "--dir", in: args)
            guard let directionValue else {
                throw DesktopAdapterError.invalidArgument("Missing --direction up|down|left|right for input scroll")
            }
            let amount = try self.value(after: "--amount", in: args)
                .map(self.parsePositiveAmount) ?? 1
            try stdout(self.success(adapter.scroll(
                at: self.parsePoint(pointValue),
                direction: self.parseScrollDirection(directionValue),
                amount: amount)))
        case "drag", "mouse-drag":
            let startValue = try self.value(after: "--from", in: args) ??
                self.value(after: "--start", in: args)
            guard let startValue else {
                throw DesktopAdapterError.invalidArgument("Missing --from x,y for input drag")
            }
            let endValue = try self.value(after: "--to", in: args) ??
                self.value(after: "--end", in: args)
            guard let endValue else {
                throw DesktopAdapterError.invalidArgument("Missing --to x,y for input drag")
            }
            let button = try self.value(after: "--button", in: args)
                .map(self.parseMouseButton) ?? .left
            let steps = try self.value(after: "--steps", in: args)
                .map(self.parseDragSteps) ?? 10
            try stdout(self.success(adapter.drag(
                from: self.parsePoint(startValue),
                to: self.parsePoint(endValue),
                button: button,
                steps: steps)))
        case "hotkey", "press":
            let keysValue = try self.value(after: "--keys", in: args) ??
                self.value(after: "--key", in: args)
            guard let keysValue else {
                throw DesktopAdapterError.invalidArgument("Missing --keys key1,key2 for input hotkey")
            }
            let holdDuration = try self.value(after: "--hold-ms", in: args)
                .map(self.parseNonNegativeMilliseconds) ?? 0
            try stdout(self.success(adapter.hotkey(
                keys: self.parseKeys(keysValue),
                holdDurationMilliseconds: holdDuration)))
        case "type", "text":
            let textValue = try self.value(after: "--text", in: args) ??
                self.value(after: "--value", in: args)
            guard let textValue, !textValue.isEmpty else {
                throw DesktopAdapterError.invalidArgument("Missing --text <text> for input type")
            }
            let delayMilliseconds = try (self.value(after: "--delay-ms", in: args) ??
                self.value(after: "--delay", in: args))
                .map(self.parseTypingDelayMilliseconds) ?? 0
            try stdout(self.success(adapter.typeText(
                textValue,
                delayMilliseconds: delayMilliseconds)))
        default:
            throw DesktopAdapterError.invalidArgument("Unknown input subcommand: \(subcommand)")
        }
    }

    private static func runList(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        guard let subcommand = args.first else {
            throw DesktopAdapterError.invalidArgument("Missing list subcommand: apps, windows, or displays")
        }

        switch subcommand {
        case "apps", "applications":
            try stdout(self.success(adapter.listApplications()))
        case "windows":
            let includeInvisible = args.contains("--include-invisible")
            try stdout(self.success(adapter.listWindows(includeInvisible: includeInvisible)))
        case "displays", "screens":
            try stdout(self.success(adapter.listDisplays()))
        default:
            throw DesktopAdapterError.invalidArgument("Unknown list subcommand: \(subcommand)")
        }
    }

    private static func runAutomation(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        guard let subcommand = args.first else {
            throw DesktopAdapterError.invalidArgument(
                "Missing automation subcommand: status, snapshot, element, invoke, " +
                    "set-value, set-range-value, set-scroll-percent, set-window-state, " +
                    "move, resize, rotate, toggle, expand, collapse, or select")
        }

        switch subcommand {
        case "status":
            try stdout(self.success(adapter.uiAutomationStatus()))
        case "snapshot":
            try self.runAutomationSnapshot(args: args, adapter: adapter, stdout: stdout)
        case "element", "describe":
            try self.runAutomationElement(args: args, adapter: adapter, stdout: stdout)
        case "invoke":
            try self.runAutomationInvoke(args: args, adapter: adapter, stdout: stdout)
        case "set-value", "setValue":
            try self.runAutomationSetValue(args: args, adapter: adapter, stdout: stdout)
        case "set-range-value", "setRangeValue":
            try self.runAutomationSetRangeValue(args: args, adapter: adapter, stdout: stdout)
        case "set-scroll-percent", "setScrollPercent":
            try self.runAutomationSetScrollPercent(args: args, adapter: adapter, stdout: stdout)
        case "set-window-state", "setWindowState":
            try self.runAutomationSetWindowState(args: args, adapter: adapter, stdout: stdout)
        case "move":
            try self.runAutomationMove(args: args, adapter: adapter, stdout: stdout)
        case "resize":
            try self.runAutomationResize(args: args, adapter: adapter, stdout: stdout)
        case "rotate":
            try self.runAutomationRotate(args: args, adapter: adapter, stdout: stdout)
        case "toggle":
            try self.runAutomationToggle(args: args, adapter: adapter, stdout: stdout)
        case "expand":
            try self.runAutomationExpand(args: args, adapter: adapter, stdout: stdout)
        case "collapse":
            try self.runAutomationCollapse(args: args, adapter: adapter, stdout: stdout)
        case "select":
            try self.runAutomationSelect(args: args, adapter: adapter, stdout: stdout)
        default:
            throw DesktopAdapterError.invalidArgument("Unknown automation subcommand: \(subcommand)")
        }
    }

    private static func runAutomationSnapshot(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)))
    }

    private static func runAutomationElement(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation element")
        }

        let elementIndex = try self.parseUIAutomationElementIndex(indexValue)
        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        let snapshot = try adapter.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw DesktopAdapterError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }

        try stdout(self.success(DesktopUIAutomationElementLookup(
            nativeBackend: snapshot.nativeBackend,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementCount: snapshot.elementCount,
            didTruncate: snapshot.didTruncate,
            elementIndex: elementIndex,
            element: element)))
    }

    private static func runAutomationInvoke(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation invoke")
        }

        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.invokeUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue))))
    }

    private static func runAutomationSetValue(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation set-value")
        }

        let value = try self.value(after: "--value", in: args) ??
            self.value(after: "--text", in: args)
        guard let value else {
            throw DesktopAdapterError.invalidArgument("Missing --value <text> for automation set-value")
        }

        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.setUIAutomationElementValue(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue),
            value: value)))
    }

    private static func runAutomationSetRangeValue(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument(
                "Missing --index <element-index> for automation set-range-value")
        }

        let value = try self.value(after: "--value", in: args)
        guard let value else {
            throw DesktopAdapterError.invalidArgument("Missing --value <number> for automation set-range-value")
        }

        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.setUIAutomationElementRangeValue(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue),
            value: self.parseUIAutomationRangeValue(value))))
    }

    private static func runAutomationSetScrollPercent(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument(
                "Missing --index <element-index> for automation set-scroll-percent")
        }

        let horizontalValue = try self.value(after: "--horizontal", in: args) ??
            self.value(after: "--horizontal-percent", in: args)
        let verticalValue = try self.value(after: "--vertical", in: args) ??
            self.value(after: "--vertical-percent", in: args)
        guard horizontalValue != nil || verticalValue != nil else {
            throw DesktopAdapterError.invalidArgument(
                "Missing --horizontal <percent> or --vertical <percent> for automation set-scroll-percent")
        }

        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.setUIAutomationElementScrollPercent(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue),
            horizontalPercent: try horizontalValue.map(self.parseUIAutomationScrollPercent),
            verticalPercent: try verticalValue.map(self.parseUIAutomationScrollPercent))))
    }

    private static func runAutomationSetWindowState(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument(
                "Missing --index <element-index> for automation set-window-state")
        }

        let stateValue = try self.value(after: "--state", in: args)
        guard let stateValue else {
            throw DesktopAdapterError.invalidArgument(
                "Missing --state <normal|maximized|minimized> for automation set-window-state")
        }

        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.setUIAutomationElementWindowVisualState(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue),
            state: self.parseUIAutomationWindowVisualState(stateValue))))
    }

    private static func runAutomationMove(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation move")
        }

        let point = try self.parseUIAutomationMovePoint(args)
        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.moveUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue),
            x: point.0,
            y: point.1)))
    }

    private static func runAutomationResize(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation resize")
        }

        let size = try self.parseUIAutomationResizeSize(args)
        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.resizeUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue),
            width: size.0,
            height: size.1)))
    }

    private static func runAutomationRotate(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation rotate")
        }

        let degrees = try self.parseUIAutomationRotateDegrees(args)
        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.rotateUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue),
            degrees: degrees)))
    }

    private static func runAutomationToggle(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation toggle")
        }

        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.toggleUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue))))
    }

    private static func runAutomationExpand(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation expand")
        }

        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.expandUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue))))
    }

    private static func runAutomationCollapse(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation collapse")
        }

        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.collapseUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue))))
    }

    private static func runAutomationSelect(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let indexValue = try self.value(after: "--index", in: args) ??
            self.value(after: "--element-index", in: args)
        guard let indexValue else {
            throw DesktopAdapterError.invalidArgument("Missing --index <element-index> for automation select")
        }

        let scope = try self.value(after: "--scope", in: args)
            .map(self.parseUIAutomationSnapshotScope) ?? .foreground
        let maxDepth = try self.value(after: "--max-depth", in: args)
            .map(self.parseUIAutomationMaxDepth) ?? 2
        let maxElements = try self.value(after: "--max-elements", in: args)
            .map(self.parseUIAutomationMaxElements) ?? 64

        try stdout(self.success(adapter.selectUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: self.parseUIAutomationElementIndex(indexValue))))
    }

    private static func runCapture(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        guard let subcommand = args.first else {
            throw DesktopAdapterError.invalidArgument("Missing capture subcommand: screen, area, window, or frontmost")
        }

        switch subcommand {
        case "screen":
            try self.runCaptureScreen(args: args, adapter: adapter, stdout: stdout)
        case "area", "region":
            try self.runCaptureArea(args: args, adapter: adapter, stdout: stdout)
        case "window":
            try self.runCaptureWindow(args: args, adapter: adapter, stdout: stdout)
        case "frontmost", "foreground":
            try self.runCaptureFrontmost(args: args, adapter: adapter, stdout: stdout)
        default:
            throw DesktopAdapterError.invalidArgument("Unknown capture subcommand: \(subcommand)")
        }
    }

    private static func runCaptureScreen(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let outputPath = try self.value(after: "--path", in: args) ??
            self.value(after: "-o", in: args)
        guard let outputPath, !outputPath.isEmpty else {
            throw DesktopAdapterError.outputPathRequired
        }

        let displayIndex = try self.value(after: "--display", in: args).map { value in
            guard let index = Int(value) else {
                throw DesktopAdapterError.invalidArgument("Invalid display index: \(value)")
            }
            return index
        }

        let result = try adapter.captureScreen(displayIndex: displayIndex, outputPath: outputPath)
        try stdout(self.success(result))
    }

    private static func runCaptureArea(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let outputPath = try self.value(after: "--path", in: args) ??
            self.value(after: "-o", in: args)
        guard let outputPath, !outputPath.isEmpty else {
            throw DesktopAdapterError.outputPathRequired
        }

        let rectValue = try self.value(after: "--rect", in: args) ??
            self.value(after: "--region", in: args)
        guard let rectValue else {
            throw DesktopAdapterError.invalidArgument("Missing --rect x,y,width,height for capture area")
        }

        let result = try adapter.captureArea(
            self.parseRect(rectValue),
            outputPath: outputPath)
        try stdout(self.success(result))
    }

    private static func runCaptureWindow(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let outputPath = try self.value(after: "--path", in: args) ??
            self.value(after: "-o", in: args)
        guard let outputPath, !outputPath.isEmpty else {
            throw DesktopAdapterError.outputPathRequired
        }

        let windowValue = try self.value(after: "--id", in: args) ??
            self.value(after: "--window-id", in: args)
        guard let windowValue else {
            throw DesktopAdapterError.invalidArgument("Missing --id <window-id> for capture window")
        }
        guard let windowIdentifier = UInt64(windowValue) else {
            throw DesktopAdapterError.invalidArgument("Invalid window id: \(windowValue)")
        }

        let result = try adapter.captureWindow(
            windowIdentifier: windowIdentifier,
            outputPath: outputPath)
        try stdout(self.success(result))
    }

    private static func runCaptureFrontmost(
        args: [String],
        adapter: any DesktopAdapter,
        stdout: OutputHandler) throws
    {
        let outputPath = try self.value(after: "--path", in: args) ??
            self.value(after: "-o", in: args)
        guard let outputPath, !outputPath.isEmpty else {
            throw DesktopAdapterError.outputPathRequired
        }

        let result = try adapter.captureFrontmost(outputPath: outputPath)
        try stdout(self.success(result))
    }

    private static func value(after flag: String, in args: [String]) throws -> String? {
        guard let index = args.firstIndex(of: flag) else {
            return nil
        }
        let valueIndex = args.index(after: index)
        guard valueIndex < args.endIndex else {
            throw DesktopAdapterError.invalidArgument("Missing value after \(flag)")
        }
        return args[valueIndex]
    }

    private static func parseRect(_ value: String) throws -> DesktopRect {
        let parts = value
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 4,
              let x = Int(parts[0]),
              let y = Int(parts[1]),
              let width = Int(parts[2]),
              let height = Int(parts[3])
        else {
            throw DesktopAdapterError.invalidArgument("Rect must be x,y,width,height")
        }

        let rect = DesktopRect(x: x, y: y, width: width, height: height)
        guard !rect.isEmpty else {
            throw DesktopAdapterError.emptyCaptureRegion(rect)
        }
        return rect
    }

    private static func parsePoint(_ value: String) throws -> DesktopPoint {
        let parts = value
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 2,
              let x = Int(parts[0]),
              let y = Int(parts[1])
        else {
            throw DesktopAdapterError.invalidArgument("Point must be x,y")
        }

        return DesktopPoint(x: x, y: y)
    }

    private static func parseMouseButton(_ value: String) throws -> DesktopMouseButton {
        switch value.lowercased() {
        case "left", "primary":
            return .left
        case "right", "secondary":
            return .right
        case "middle":
            return .middle
        default:
            throw DesktopAdapterError.invalidArgument("Mouse button must be left, right, or middle")
        }
    }

    private static func parseClickCount(_ value: String) throws -> Int {
        do {
            return try self.parsePositiveAmount(value)
        } catch {
            throw DesktopAdapterError.invalidArgument("Click count must be a positive integer")
        }
    }

    private static func parseScrollDirection(_ value: String) throws -> DesktopScrollDirection {
        switch value.lowercased() {
        case "up":
            return .up
        case "down":
            return .down
        case "left":
            return .left
        case "right":
            return .right
        default:
            throw DesktopAdapterError.invalidArgument("Scroll direction must be up, down, left, or right")
        }
    }

    private static func parsePositiveAmount(_ value: String) throws -> Int {
        guard let amount = Int(value), amount > 0 else {
            throw DesktopAdapterError.invalidArgument("Amount must be a positive integer")
        }
        return amount
    }

    private static func parseDragSteps(_ value: String) throws -> Int {
        do {
            return try self.parsePositiveAmount(value)
        } catch {
            throw DesktopAdapterError.invalidArgument("Steps must be a positive integer")
        }
    }

    private static func parseKeys(_ value: String) throws -> [String] {
        let keys = value
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        guard !keys.isEmpty, keys.allSatisfy({ !$0.isEmpty }) else {
            throw DesktopAdapterError.invalidArgument("Keys must be a comma-separated list")
        }

        return keys
    }

    private static func parseNonNegativeMilliseconds(_ value: String) throws -> Int {
        guard let milliseconds = Int(value), milliseconds >= 0 else {
            throw DesktopAdapterError.invalidArgument("Hold duration must be a non-negative integer")
        }
        return milliseconds
    }

    private static func parseTypingDelayMilliseconds(_ value: String) throws -> Int {
        guard let milliseconds = Int(value), milliseconds >= 0 else {
            throw DesktopAdapterError.invalidArgument("Typing delay must be a non-negative integer")
        }
        return milliseconds
    }

    private static func parseUIAutomationSnapshotScope(
        _ value: String) throws -> DesktopUIAutomationSnapshotScope
    {
        guard let scope = DesktopUIAutomationSnapshotScope(rawValue: value.lowercased()) else {
            throw DesktopAdapterError.invalidArgument(
                "UI Automation scope must be root, foreground, focused, or cursor")
        }
        return scope
    }

    private static func parseUIAutomationMaxDepth(_ value: String) throws -> Int {
        guard let depth = Int(value), (0...8).contains(depth) else {
            throw DesktopAdapterError.invalidArgument("UI Automation max depth must be between 0 and 8")
        }
        return depth
    }

    private static func parseUIAutomationMaxElements(_ value: String) throws -> Int {
        guard let elementCount = Int(value), (1...512).contains(elementCount) else {
            throw DesktopAdapterError.invalidArgument("UI Automation max elements must be between 1 and 512")
        }
        return elementCount
    }

    private static func parseUIAutomationElementIndex(_ value: String) throws -> Int {
        guard let elementIndex = Int(value), elementIndex >= 0 else {
            throw DesktopAdapterError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }
        return elementIndex
    }

    private static func parseUIAutomationRangeValue(_ value: String) throws -> Double {
        guard let rangeValue = Double(value), rangeValue.isFinite else {
            throw DesktopAdapterError.invalidArgument("UI Automation range value must be a finite number")
        }
        return rangeValue
    }

    private static func parseUIAutomationScrollPercent(_ value: String) throws -> Double {
        guard let percent = Double(value), percent.isFinite, (0.0...100.0).contains(percent) else {
            throw DesktopAdapterError.invalidArgument(
                "UI Automation scroll percent must be a finite number between 0 and 100")
        }
        return percent
    }

    private static func parseUIAutomationWindowVisualState(
        _ value: String) throws -> DesktopUIAutomationWindowVisualState
    {
        guard let state = DesktopUIAutomationWindowVisualState(rawValue: value) else {
            throw DesktopAdapterError.invalidArgument(
                "UI Automation window state must be normal, maximized, or minimized")
        }
        return state
    }

    private static func parseUIAutomationMovePoint(_ args: [String]) throws -> (Double, Double) {
        if let pointValue = try self.value(after: "--point", in: args) ??
            self.value(after: "--position", in: args)
        {
            return try self.parseDoublePair(pointValue, label: "Point", requirePositive: false)
        }

        guard let xValue = try self.value(after: "--x", in: args),
              let yValue = try self.value(after: "--y", in: args)
        else {
            throw DesktopAdapterError.invalidArgument("Missing --point <x,y> for automation move")
        }
        return (
            try self.parseFiniteDouble(xValue, label: "UI Automation move x"),
            try self.parseFiniteDouble(yValue, label: "UI Automation move y"))
    }

    private static func parseUIAutomationResizeSize(_ args: [String]) throws -> (Double, Double) {
        if let sizeValue = try self.value(after: "--size", in: args) {
            return try self.parseDoublePair(sizeValue, label: "Size", requirePositive: true)
        }

        guard let widthValue = try self.value(after: "--width", in: args),
              let heightValue = try self.value(after: "--height", in: args)
        else {
            throw DesktopAdapterError.invalidArgument("Missing --size <width,height> for automation resize")
        }
        return (
            try self.parsePositiveFiniteDouble(widthValue, label: "UI Automation resize width"),
            try self.parsePositiveFiniteDouble(heightValue, label: "UI Automation resize height"))
    }

    private static func parseUIAutomationRotateDegrees(_ args: [String]) throws -> Double {
        let degreesValue = try self.value(after: "--degrees", in: args) ??
            self.value(after: "--angle", in: args)
        guard let degreesValue else {
            throw DesktopAdapterError.invalidArgument("Missing --degrees <number> for automation rotate")
        }
        return try self.parseFiniteDouble(degreesValue, label: "UI Automation rotate degrees")
    }

    private static func parseDoublePair(
        _ value: String,
        label: String,
        requirePositive: Bool) throws -> (Double, Double)
    {
        let parts = value
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 2 else {
            let expected = requirePositive ? "width,height" : "x,y"
            throw DesktopAdapterError.invalidArgument("\(label) must be \(expected)")
        }

        if requirePositive {
            return (
                try self.parsePositiveFiniteDouble(parts[0], label: "\(label) width"),
                try self.parsePositiveFiniteDouble(parts[1], label: "\(label) height"))
        }
        return (
            try self.parseFiniteDouble(parts[0], label: "\(label) x"),
            try self.parseFiniteDouble(parts[1], label: "\(label) y"))
    }

    private static func parseFiniteDouble(_ value: String, label: String) throws -> Double {
        guard let number = Double(value), number.isFinite else {
            throw DesktopAdapterError.invalidArgument("\(label) must be a finite number")
        }
        return number
    }

    private static func parsePositiveFiniteDouble(_ value: String, label: String) throws -> Double {
        let number = try self.parseFiniteDouble(value, label: label)
        guard number > 0 else {
            throw DesktopAdapterError.invalidArgument("\(label) must be greater than 0")
        }
        return number
    }

    private static func success<T: Encodable>(_ data: T) throws -> String {
        try DesktopJSON.encode(DesktopCommandEnvelope(ok: true, data: data, error: nil))
    }

    private static func helpText(commandName: String, adapter: any DesktopAdapter) -> String {
        let capturePath = self.capturePathExample(for: adapter.platformInfo())
        return """
        \(commandName)

        Commands:
          platform-info
          list apps
          list windows [--include-invisible]
          list displays
          capture screen --path <\(capturePath)> [--display <index>]
          capture area --rect <x,y,width,height> --path <\(capturePath)>
          capture window --id <window-id> --path <\(capturePath)>
          capture frontmost --path <\(capturePath)>
          input position
          input move --point <x,y>
          input click --point <x,y> [--button left|right|middle] [--count <n>]
          input scroll --point <x,y> --direction <up|down|left|right> [--amount <n>]
          input drag --from <x,y> --to <x,y> [--button left|right|middle] [--steps <n>]
          input hotkey --keys <key1,key2> [--hold-ms <n>]
          input type --text <text> [--delay-ms <n>]
          automation status
          automation snapshot [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation element --index <n> [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation invoke --index <n> [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation set-value --index <n> --value <text>
            [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation set-range-value --index <n> --value <number>
            [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation set-scroll-percent --index <n> [--horizontal <percent>] [--vertical <percent>]
            [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation set-window-state --index <n> --state <normal|maximized|minimized>
            [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation move --index <n> --point <x,y>
            [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation resize --index <n> --size <width,height>
            [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation rotate --index <n> --degrees <number>
            [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation toggle --index <n> [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation expand --index <n> [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation collapse --index <n>
            [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
          automation select --index <n> [--scope root|foreground|focused|cursor] [--max-depth <n>] [--max-elements <n>]
        """
    }

    private static func capturePathExample(for info: DesktopPlatformInfo) -> String {
        if info.capabilities.contains(.captureScreenBMP) ||
            info.capabilities.contains(.captureAreaBMP) ||
            info.capabilities.contains(.captureWindowBMP) ||
            info.capabilities.contains(.captureFrontmostBMP)
        {
            return "file.bmp"
        }
        if info.capabilities.contains(.captureScreenPNG) ||
            info.capabilities.contains(.captureAreaPNG) ||
            info.capabilities.contains(.captureWindowPNG) ||
            info.capabilities.contains(.captureFrontmostPNG)
        {
            return "file.png"
        }
        return "file"
    }
}
