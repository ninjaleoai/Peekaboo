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
