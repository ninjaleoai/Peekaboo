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
        guard args.first == "screen" else {
            throw DesktopAdapterError.invalidArgument("Only `capture screen` is implemented")
        }

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
        """
    }

    private static func capturePathExample(for info: DesktopPlatformInfo) -> String {
        if info.capabilities.contains(.captureScreenBMP) {
            return "file.bmp"
        }
        if info.capabilities.contains(.captureScreenPNG) {
            return "file.png"
        }
        return "file"
    }
}
