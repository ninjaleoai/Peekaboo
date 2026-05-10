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
            throw DesktopAdapterError.invalidArgument("Missing automation subcommand: status or snapshot")
        }

        switch subcommand {
        case "status":
            try stdout(self.success(adapter.uiAutomationStatus()))
        case "snapshot":
            try self.runAutomationSnapshot(args: args, adapter: adapter, stdout: stdout)
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
            throw DesktopAdapterError.invalidArgument("UI Automation scope must be root, foreground, or focused")
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
          automation snapshot [--scope root|foreground|focused] [--max-depth <n>] [--max-elements <n>]
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
