import Foundation
import PeekabooDesktop

public enum Win11CLI {
    public static func run(
        arguments: [String] = CommandLine.arguments,
        adapter: any Win11DesktopAdapter = Win11DesktopAdapterFactory.makeDefault(),
        stdout: (String) -> Void = { print($0) },
        stderr: (String) -> Void = { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }) -> Int32
    {
        DesktopCommandRunner.run(
            arguments: arguments,
            adapter: adapter,
            commandName: "peekaboo-win11",
            stdout: stdout,
            stderr: stderr)
    }
}
