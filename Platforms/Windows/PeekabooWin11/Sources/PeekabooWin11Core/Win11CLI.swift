import Foundation

public enum Win11CLI {
    public static func run(
        arguments: [String] = CommandLine.arguments,
        adapter: any Win11DesktopAdapter = Win11DesktopAdapterFactory.makeDefault(),
        stdout: (String) -> Void = { print($0) },
        stderr: (String) -> Void = { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }) -> Int32
    {
        let args = Array(arguments.dropFirst())
        guard let command = args.first else {
            stdout(Self.helpText)
            return 0
        }

        do {
            switch command {
            case "platform-info":
                try stdout(Self.success(adapter.platformInfo()))
            case "list":
                try Self.runList(args: Array(args.dropFirst()), adapter: adapter, stdout: stdout)
            case "capture":
                try Self.runCapture(args: Array(args.dropFirst()), adapter: adapter, stdout: stdout)
            case "help", "--help", "-h":
                stdout(Self.helpText)
            default:
                throw Win11DesktopError.invalidArgument("Unknown command: \(command)")
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
        adapter: any Win11DesktopAdapter,
        stdout: (String) -> Void) throws
    {
        guard let subcommand = args.first else {
            throw Win11DesktopError.invalidArgument("Missing list subcommand: apps, windows, or displays")
        }

        switch subcommand {
        case "apps", "applications":
            try stdout(Self.success(adapter.listApplications()))
        case "windows":
            let includeInvisible = args.contains("--include-invisible")
            try stdout(Self.success(adapter.listWindows(includeInvisible: includeInvisible)))
        case "displays", "screens":
            try stdout(Self.success(adapter.listDisplays()))
        default:
            throw Win11DesktopError.invalidArgument("Unknown list subcommand: \(subcommand)")
        }
    }

    private static func runCapture(
        args: [String],
        adapter: any Win11DesktopAdapter,
        stdout: (String) -> Void) throws
    {
        guard args.first == "screen" else {
            throw Win11DesktopError.invalidArgument("Only `capture screen` is implemented in the Windows 11 slice")
        }

        let outputPath = try Self.value(after: "--path", in: args) ??
            Self.value(after: "-o", in: args)
        guard let outputPath, !outputPath.isEmpty else {
            throw Win11DesktopError.outputPathRequired
        }

        let displayIndex = try Self.value(after: "--display", in: args).map { value in
            guard let index = Int(value) else {
                throw Win11DesktopError.invalidArgument("Invalid display index: \(value)")
            }
            return index
        }

        let result = try adapter.captureScreen(displayIndex: displayIndex, outputPath: outputPath)
        try stdout(Self.success(result))
    }

    private static func value(after flag: String, in args: [String]) throws -> String? {
        guard let index = args.firstIndex(of: flag) else {
            return nil
        }
        let valueIndex = args.index(after: index)
        guard valueIndex < args.endIndex else {
            throw Win11DesktopError.invalidArgument("Missing value after \(flag)")
        }
        return args[valueIndex]
    }

    private static func success<T: Encodable>(_ data: T) throws -> String {
        try Win11JSON.encode(Win11CommandEnvelope(ok: true, data: data, error: nil))
    }

    private static let helpText = """
    peekaboo-win11

    Commands:
      platform-info
      list apps
      list windows [--include-invisible]
      list displays
      capture screen --path <file.bmp> [--display <index>]
    """
}
