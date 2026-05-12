import Foundation
import PeekabooDesktop

public enum Win11CLI {
    public static func run(
        arguments: [String] = CommandLine.arguments,
        adapter: any Win11DesktopAdapter = Win11DesktopAdapterFactory.makeDefault(),
        stdin: () -> String? = { readLine(strippingNewline: true) },
        stdout: (String) -> Void = { print($0) },
        stderr: (String) -> Void = { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }) -> Int32
    {
        let args = Array(arguments.dropFirst())
        if args.first == "mcp" {
            return Win11MCPCommandRunner.run(
                arguments: Array(args.dropFirst()),
                adapter: adapter,
                stdin: stdin,
                stdout: stdout,
                stderr: stderr)
        }

        DesktopCommandRunner.run(
            arguments: arguments,
            adapter: adapter,
            commandName: "peekaboo-win11",
            additionalCommands: ["mcp serve"],
            stdout: stdout,
            stderr: stderr)
    }
}

public enum Win11MCPCommandRunner {
    public static func run(
        arguments: [String],
        adapter: any Win11DesktopAdapter,
        stdin: () -> String?,
        stdout: (String) -> Void,
        stderr: (String) -> Void) -> Int32
    {
        let subcommand = arguments.first
        guard subcommand == nil || subcommand == "serve" || subcommand == "--help" || subcommand == "-h" else {
            stderr("Unknown mcp subcommand: \(subcommand ?? "")")
            return 1
        }

        if subcommand == "--help" || subcommand == "-h" {
            stdout("""
            peekaboo-win11 mcp serve

            Starts a line-delimited JSON-RPC MCP server over stdio.
            Logs must go to stderr; stdout is reserved for MCP protocol messages.
            """)
            return 0
        }

        let server = Win11MCPServer(desktop: Win11MCPDesktopAdapterBridge(adapter: adapter))
        while let line = stdin() {
            if let response = server.handleLine(line) {
                stdout(response)
            }
        }
        return 0
    }
}
