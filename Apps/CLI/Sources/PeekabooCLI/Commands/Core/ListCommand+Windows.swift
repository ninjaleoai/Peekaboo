import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooDesktop
import PeekabooFoundation

extension ListCommand {
    @MainActor
    struct WindowsSubcommand: ErrorHandlingCommand, OutputFormattable, ApplicationResolvable,
    RuntimeOptionsConfigurable {
        @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
        var app: String?

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Option(name: .long, help: "Additional details (comma-separated: off_screen,bounds,ids)")
        var includeDetails: String?
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
            // PIDWindowsSubcommandTests read jsonOutput immediately after parsing.
            self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
        }

        enum WindowDetailOption: String, ExpressibleFromArgument {
            case ids
            case bounds
            case off_screen

            init?(argument: String) {
                self.init(rawValue: argument.lowercased())
            }
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await requireScreenRecordingPermission(services: self.services)
                let appIdentifier = try self.resolveApplicationIdentifier()
                let applications = try await self.services.desktop.listApplications()
                let targetApplication = try Self.resolveTargetApplication(
                    identifier: appIdentifier,
                    in: applications)
                let desktopWindows = try await self.services.desktop.listWindows(includeInvisible: true)
                let windows = desktopWindows
                    .filter { $0.processIdentifier == targetApplication.processIdentifier }
                    .sorted { $0.index < $1.index }
                let output = self.buildWindowOutput(
                    windows: windows,
                    targetApplication: targetApplication)

                if self.jsonOutput {
                    let detailOptions = self.parseIncludeDetails()
                    self.renderJSON(from: output, detailOptions: detailOptions)
                } else {
                    print(CLIFormatter.format(output))
                }
            } catch {
                self.handleError(error)
                throw ExitCode(1)
            }
        }

        private func parseIncludeDetails() -> Set<WindowDetailOption> {
            guard let detailsString = includeDetails else { return [] }
            let normalizedTokens = detailsString
                .split(separator: ",")
                .map { token -> String in
                    token
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "-", with: "_")
                        .lowercased()
                }

            let options = normalizedTokens.compactMap { token -> WindowDetailOption? in
                switch token {
                case "offscreen", "off_screen":
                    return .off_screen
                case "bounds":
                    return .bounds
                case "ids":
                    return .ids
                default:
                    return nil
                }
            }

            return Set(options)
        }

        private func buildWindowOutput(
            windows: [DesktopWindow],
            targetApplication: DesktopApplication
        ) -> UnifiedToolOutput<ServiceWindowListData> {
            let serviceWindows = windows.map(\.serviceWindowInfo)
            return UnifiedToolOutput(
                data: ServiceWindowListData(
                    windows: serviceWindows,
                    targetApplication: targetApplication.serviceApplicationInfo),
                summary: UnifiedToolOutput<ServiceWindowListData>.Summary(
                    brief: "Found \(serviceWindows.count) window"
                        + (serviceWindows.count == 1 ? "" : "s")
                        + " for \(targetApplication.executableName)",
                    status: .success,
                    counts: ["windows": serviceWindows.count]
                ),
                metadata: .init(duration: 0)
            )
        }

        private static func resolveTargetApplication(
            identifier: String,
            in applications: [DesktopApplication]
        ) throws -> DesktopApplication {
            let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)

            if let pid = Self.parsePID(trimmedIdentifier),
               let application = applications.first(where: { $0.processIdentifier == pid })
            {
                return application
            }

            if let bundleMatch = applications.first(where: { $0.bundleIdentifier == trimmedIdentifier }) {
                return bundleMatch
            }

            if let exactName = applications.first(where: {
                $0.executableName.compare(trimmedIdentifier, options: .caseInsensitive) == .orderedSame
            }) {
                return exactName
            }

            let lowercaseIdentifier = trimmedIdentifier.lowercased()
            let fuzzyMatches = applications.compactMap {
                (application: DesktopApplication) -> (application: DesktopApplication, score: Int)? in
                let lowercaseName = application.executableName.lowercased()
                guard lowercaseName.contains(lowercaseIdentifier) else { return nil }

                var score = 0
                if lowercaseName.hasPrefix(lowercaseIdentifier) {
                    score += 100
                }
                if application.visibleWindowCount > 0 {
                    score += 25
                }
                score -= application.executableName.count

                return (application: application, score: score)
            }

            if let bestMatch = fuzzyMatches.max(by: { $0.score < $1.score }) {
                return bestMatch.application
            }

            throw PeekabooError.appNotFound(identifier)
        }

        private static func parsePID(_ identifier: String) -> UInt32? {
            let pidString: String
            if identifier.uppercased().hasPrefix("PID:") {
                pidString = String(identifier.dropFirst(4))
            } else {
                pidString = identifier
            }

            guard let pid = Int32(pidString), pid > 0 else { return nil }
            return UInt32(pid)
        }

        @MainActor
        private func renderJSON(
            from output: UnifiedToolOutput<ServiceWindowListData>,
            detailOptions: Set<WindowDetailOption>
        ) {
            guard !detailOptions.isEmpty else {
                outputSuccessCodable(data: output.data, logger: self.outputLogger)
                return
            }

            struct FilteredWindowListData: Codable {
                struct Window: Codable {
                    let index: Int
                    let title: String
                    let isMinimized: Bool
                    let isMainWindow: Bool
                    let windowID: Int?
                    let bounds: CGRect?
                    let offScreen: Bool?
                    let spaceID: UInt64?
                    let spaceName: String?
                }

                let windows: [Window]
                let targetApplication: ServiceApplicationInfo?
            }

            let windows = output.data.windows.map { window in
                FilteredWindowListData.Window(
                    index: window.index,
                    title: window.title,
                    isMinimized: window.isMinimized,
                    isMainWindow: window.isMainWindow,
                    windowID: detailOptions.contains(.ids) ? window.windowID : nil,
                    bounds: detailOptions.contains(.bounds) ? window.bounds : nil,
                    offScreen: detailOptions.contains(.off_screen) ? window.isOffScreen : nil,
                    spaceID: window.spaceID,
                    spaceName: window.spaceName
                )
            }

            let filteredOutput = FilteredWindowListData(
                windows: windows,
                targetApplication: output.data.targetApplication
            )

            outputSuccessCodable(data: filteredOutput, logger: self.outputLogger)
        }
    }
}

@MainActor
extension ListCommand.WindowsSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "windows",
                abstract: "List all windows for a specific application",
                discussion: """
                Lists all windows for the specified application using PeekabooServices.
                Windows are listed in z-order (frontmost first) with optional details.
                """
            )
        }
    }
}

extension ListCommand.WindowsSubcommand: AsyncRuntimeCommand {}

@MainActor
extension ListCommand.WindowsSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        let resolvedApp = values.singleOption("app")
        let resolvedPID = try values.decodeOption("pid", as: Int32.self)
        guard resolvedApp != nil || resolvedPID != nil else {
            throw CommanderBindingError.missingArgument(label: "app")
        }
        self.app = resolvedApp
        self.pid = resolvedPID
        self.includeDetails = values.singleOption("includeDetails")
    }
}

private extension DesktopApplication {
    var serviceApplicationInfo: ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: Int32(clamping: self.processIdentifier),
            bundleIdentifier: self.bundleIdentifier,
            name: self.executableName,
            bundlePath: self.executablePath,
            isActive: self.isActive,
            isHidden: self.isHidden,
            windowCount: self.visibleWindowCount)
    }
}

private extension DesktopWindow {
    var serviceWindowInfo: ServiceWindowInfo {
        ServiceWindowInfo(
            windowID: Int(clamping: self.windowIdentifier),
            title: self.title,
            bounds: self.bounds.cgRect,
            isMinimized: self.isMinimized,
            isMainWindow: self.isForeground,
            alpha: CGFloat(self.alpha),
            index: self.index,
            spaceID: self.spaceID,
            spaceName: self.spaceName,
            screenIndex: self.screenIndex,
            screenName: self.screenName,
            isOffScreen: self.isOffScreen,
            layer: self.layer,
            isOnScreen: self.isOnScreen)
    }
}

private extension DesktopRect {
    var cgRect: CGRect {
        CGRect(x: self.x, y: self.y, width: self.width, height: self.height)
    }
}
