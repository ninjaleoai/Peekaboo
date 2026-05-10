#if os(Windows)
import ucrt
#elseif os(Linux)
import Glibc
#else
import Darwin
#endif

import PeekabooWin11Core

@main
struct Main {
    static func main() {
        exit(Win11CLI.run())
    }
}
