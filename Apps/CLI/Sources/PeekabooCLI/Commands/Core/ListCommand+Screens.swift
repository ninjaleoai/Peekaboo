import Commander
import Foundation
import PeekabooCore
import PeekabooDesktop

private typealias ScreenOutput = UnifiedToolOutput<ScreenListData>

extension ListCommand {
    // MARK: - Screens

    @MainActor
    struct ScreensSubcommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let displays = try await self.services.desktop.listDisplays()
            let screenListData = self.buildScreenListData(from: displays)
            let output = UnifiedToolOutput(
                data: screenListData,
                summary: self.buildScreenSummary(for: displays),
                metadata: self.buildScreenMetadata()
            )

            if self.jsonOutput {
                outputSuccessCodable(data: output.data, logger: self.outputLogger)
            } else {
                self.displayScreenDetails(displays)
            }
        }

        @MainActor
        private func displayScreenDetails(_ displays: [DesktopDisplay]) {
            Swift.print("Screens (\(displays.count) total):")
            for display in displays {
                let primaryBadge = display.isPrimary ? " (Primary)" : ""
                Swift.print("\n\(display.index). \(self.displayName(display))\(primaryBadge)")
                Swift.print("   Resolution: \(display.bounds.width)×\(display.bounds.height)")
                Swift.print("   Position: \(display.bounds.x),\(display.bounds.y)")
                let retinaBadge = display.scaleFactor > 1 ? " (Retina)" : ""
                Swift.print("   Scale: \(display.scaleFactor)x\(retinaBadge)")
                if display.workArea.size != display.bounds.size {
                    Swift.print("   Visible Area: \(display.workArea.width)×\(display.workArea.height)")
                }
            }
            Swift.print("\n💡 Use 'peekaboo see --screen-index N' to capture a specific screen")
        }

        @MainActor
        private func buildScreenListData(from displays: [DesktopDisplay]) -> ScreenListData {
            let details = displays.map { display in
                ScreenListData.ScreenDetails(
                    index: display.index,
                    name: self.displayName(display),
                    resolution: ScreenListData.Resolution(
                        width: display.bounds.width,
                        height: display.bounds.height
                    ),
                    position: ScreenListData.Position(
                        x: display.bounds.x,
                        y: display.bounds.y
                    ),
                    visibleArea: ScreenListData.Resolution(
                        width: display.workArea.width,
                        height: display.workArea.height
                    ),
                    isPrimary: display.isPrimary,
                    scaleFactor: display.scaleFactor,
                    displayID: Int(clamping: display.id)
                )
            }

            return ScreenListData(
                screens: details,
                primaryIndex: displays.firstIndex { $0.isPrimary }
            )
        }

        private func buildScreenSummary(for displays: [DesktopDisplay]) -> ScreenOutput.Summary {
            let count = displays.count
            let highlights = displays.enumerated().compactMap { index, display in
                display.isPrimary ? ScreenOutput.Summary.Highlight(
                    label: "Primary",
                    value: "\(self.displayName(display)) (Index \(index))",
                    kind: .primary
                ) : nil
            }
            return ScreenOutput.Summary(
                brief: "Found \(count) screen\(count == 1 ? "" : "s")",
                detail: nil,
                status: ScreenOutput.Summary.Status.success,
                counts: ["screens": count],
                highlights: highlights
            )
        }

        private func buildScreenMetadata() -> ScreenOutput.Metadata {
            ScreenOutput.Metadata(
                duration: 0.0,
                warnings: [],
                hints: ["Use 'peekaboo see --screen-index N' to capture a specific screen"]
            )
        }

        private func displayName(_ display: DesktopDisplay) -> String {
            display.name ?? "Display \(display.index)"
        }
    }
}

// MARK: - Screen List Data Model

struct ScreenListData {
    let screens: [ScreenDetails]
    let primaryIndex: Int?

    struct ScreenDetails {
        let index: Int
        let name: String
        let resolution: Resolution
        let position: Position
        let visibleArea: Resolution
        let isPrimary: Bool
        let scaleFactor: Double
        let displayID: Int
    }

    struct Resolution {
        let width: Int
        let height: Int
    }

    struct Position {
        let x: Int
        let y: Int
    }
}

nonisolated extension ScreenListData: Sendable, Codable {}
nonisolated extension ScreenListData.ScreenDetails: Sendable, Codable {}
nonisolated extension ScreenListData.Resolution: Sendable, Codable {}
nonisolated extension ScreenListData.Position: Sendable, Codable {}

@MainActor
extension ListCommand.ScreensSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}
