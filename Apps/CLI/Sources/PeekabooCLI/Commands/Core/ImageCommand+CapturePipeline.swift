import Algorithms
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooDesktop
import PeekabooFoundation

@MainActor
extension ImageCommand {
    func performCapture() async throws -> [ImageCapturedFile] {
        if let appName = self.app?.lowercased() {
            switch appName {
            case "menubar":
                return try await self.captureMenuBar()
            case "frontmost":
                return try await self.captureFrontmost()
            default:
                break
            }
        }

        let captureMode = self.determineMode()
        var results: [ImageCapturedFile] = []

        switch captureMode {
        case .screen:
            results = try await self.captureScreens()
        case .window:
            if let windowId = self.windowId {
                results = try await self.captureWindowById(windowId)
            } else {
                let target = try self.observationApplicationTargetForWindowCapture()
                results = try await self.captureApplicationWindow(target)
            }
        case .multi:
            if self.app != nil || self.pid != nil {
                let identifier = try self.resolveApplicationIdentifier()
                results = try await self.captureAllApplicationWindows(identifier)
            } else {
                results = try await self.captureScreens()
            }
        case .frontmost:
            results = try await self.captureFrontmost()
        case .area:
            results = try await self.captureArea()
        }

        return results
    }

    private func determineMode() -> PeekabooCore.CaptureMode {
        if let mode {
            return mode
        }

        if self.region != nil {
            return .area
        }

        if self.app != nil || self.pid != nil || self.windowTitle != nil || self.windowIndex != nil || self
            .windowId != nil {
            return .window
        }

        return .frontmost
    }

    private func captureWindowById(_ windowId: Int) async throws -> [ImageCapturedFile] {
        let observation = try await self.captureObservation(
            target: .windowID(CGWindowID(windowId)),
            preferredName: "window-\(windowId)",
            index: nil
        )

        let title = observation.capture.metadata.windowInfo?.title
        let preferredName = if let title, !title.isEmpty {
            title
        } else {
            "window-\(windowId)"
        }

        return try [
            self.capturedFile(
                from: observation,
                preferredName: preferredName,
                windowIndex: nil
            ),
        ]
    }

    private func captureScreens() async throws -> [ImageCapturedFile] {
        let desktop = self.services.desktop
        if await self.canUseDesktopScreenCapture(adapter: desktop) {
            return try await self.captureDesktopScreens(adapter: desktop)
        }

        if let index = self.screenIndex {
            let observation = try await self.captureObservation(
                target: .screen(index: index),
                preferredName: "screen\(index)",
                index: nil
            )
            return try [
                self.capturedFile(
                    from: observation,
                    preferredName: "screen\(index)",
                    windowIndex: nil
                ),
            ]
        }

        let screens = self.services.screens.listScreens()
        let indexes = screens.isEmpty ? [0] : Array(screens.indices)

        var savedFiles: [ImageCapturedFile] = []
        for (ordinal, displayIndex) in indexes.indexed() {
            let observation = try await self.captureObservation(
                target: .screen(index: displayIndex),
                preferredName: "screen\(displayIndex)",
                index: ordinal
            )
            try savedFiles.append(self.capturedFile(
                from: observation,
                preferredName: "screen\(displayIndex)",
                windowIndex: nil
            ))
        }

        return savedFiles
    }

    private func canUseDesktopScreenCapture(adapter: any DesktopAsyncAdapter) async -> Bool {
        guard self.format == .png,
              !self.retina,
              self.captureEngine == nil,
              self.configuredCaptureEnginePreference == nil
        else {
            return false
        }

        let platformInfo = await adapter.platformInfo()
        return platformInfo.capabilities.contains(.captureScreenPNG)
    }

    private func captureDesktopScreens(adapter: any DesktopAsyncAdapter) async throws -> [ImageCapturedFile] {
        let displays = try await adapter.listDisplays()
        let snapshot = await self.desktopSnapshot(adapter: adapter, displays: displays)

        if let index = self.screenIndex {
            let capture = try await self.captureDesktopScreen(
                adapter: adapter,
                displayIndex: index,
                preferredName: "screen\(index)",
                index: nil,
                stateSnapshot: snapshot)
            return [capture]
        }

        let indexes = displays.isEmpty
            ? [0]
            : displays.sorted { $0.index < $1.index }.map(\.index)

        var savedFiles: [ImageCapturedFile] = []
        for (ordinal, displayIndex) in indexes.indexed() {
            let capture = try await self.captureDesktopScreen(
                adapter: adapter,
                displayIndex: displayIndex,
                preferredName: "screen\(displayIndex)",
                index: ordinal,
                stateSnapshot: snapshot)
            savedFiles.append(capture)
        }

        return savedFiles
    }

    private func captureDesktopScreen(
        adapter: any DesktopAsyncAdapter,
        displayIndex: Int,
        preferredName: String,
        index: Int?,
        stateSnapshot: DesktopStateSnapshotSummary?
    ) async throws -> ImageCapturedFile {
        let outputURL = self.makeOutputURL(preferredName: preferredName, index: index)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        let start = ContinuousClock.now
        let result = try await adapter.captureScreen(
            displayIndex: displayIndex,
            outputPath: outputURL.path)
        let span = Self.desktopCaptureSpan(start: start, result: result)

        return ImageCapturedFile(
            file: SavedFile(
                path: result.path,
                item_label: preferredName,
                mime_type: result.format.mimeType),
            observation: ImageObservationDiagnostics(
                spans: [span],
                stateSnapshot: stateSnapshot,
                target: DesktopObservationTargetDiagnostics(
                    requestedKind: "screen",
                    resolvedKind: "screen",
                    source: "desktop-adapter",
                    bounds: result.bounds.cgRect)))
    }

    private func desktopSnapshot(
        adapter: any DesktopAsyncAdapter,
        displays: [DesktopDisplay]
    ) async -> DesktopStateSnapshotSummary {
        let applications = (try? await adapter.listApplications()) ?? []
        let windows = (try? await adapter.listWindows(includeInvisible: true)) ?? []
        let frontmostApplication = applications.first(where: \.isActive)?.applicationIdentity
        let frontmostWindow = windows.first(where: \.isForeground)?.windowIdentity
        let snapshot = DesktopStateSnapshot(
            displays: displays.map(\.displayIdentity),
            runningApplications: applications.map(\.applicationIdentity),
            windows: windows.map(\.windowIdentity),
            frontmostApplication: frontmostApplication,
            frontmostWindow: frontmostWindow)

        return DesktopStateSnapshotSummary(snapshot)
    }

    private static func desktopCaptureSpan(
        start: ContinuousClock.Instant,
        result: DesktopCaptureResult
    ) -> ObservationSpan {
        let duration = start.duration(to: ContinuousClock.now)
        let milliseconds = Double(duration.components.seconds * 1000)
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        return ObservationSpan(
            name: "capture.screen",
            durationMS: milliseconds,
            metadata: [
                "byte_count": "\(result.byteCount)",
                "format": result.format.rawValue,
                "source": "desktop-adapter",
            ])
    }

    private func captureApplicationWindow(_ target: ImageWindowObservationTarget) async throws -> [ImageCapturedFile] {
        try await self.focusIfNeeded(appIdentifier: target.focusIdentifier)
        let observation = try await self.captureObservation(
            target: target.target,
            preferredName: target.preferredName,
            index: nil
        )
        let resolvedWindow = observation.target.window
        let resolvedTitle = resolvedWindow?.title.trimmingCharacters(in: .whitespacesAndNewlines)

        let saved = try self.capturedFile(
            from: observation,
            preferredName: self.windowTitle ?? (resolvedTitle?.isEmpty == false ? resolvedTitle : nil) ?? target
                .preferredName,
            windowIndex: resolvedWindow?.index
        )

        return [saved]
    }

    private func captureAllApplicationWindows(_ identifier: String) async throws -> [ImageCapturedFile] {
        try await self.focusIfNeeded(appIdentifier: identifier)

        let windows = try await WindowServiceBridge.listWindows(
            windows: self.services.windows,
            target: .application(identifier)
        )

        let filtered = ObservationTargetResolver.captureCandidates(from: windows)

        guard !filtered.isEmpty else {
            throw PeekabooError.windowNotFound(criteria: "No shareable windows for \(identifier)")
        }

        var savedFiles: [ImageCapturedFile] = []
        for (ordinal, window) in filtered.indexed() {
            let observation = try await self.captureObservation(
                target: .windowID(CGWindowID(window.windowID)),
                preferredName: window.title,
                index: ordinal
            )

            let saved = try self.capturedFile(
                from: observation,
                preferredName: window.title,
                windowIndex: window.index
            )
            savedFiles.append(saved)
        }

        return savedFiles
    }

    private func captureFrontmost() async throws -> [ImageCapturedFile] {
        let observation = try await self.captureObservation(
            target: .frontmost,
            preferredName: "frontmost",
            index: nil
        )
        return try [
            self.capturedFile(
                from: observation,
                preferredName: "frontmost",
                windowIndex: nil
            ),
        ]
    }

    private func captureArea() async throws -> [ImageCapturedFile] {
        let rect = try self.areaCaptureRect()
        let observation = try await self.captureObservation(
            target: .area(rect),
            preferredName: "area",
            index: nil
        )
        return try [
            self.capturedFile(
                from: observation,
                preferredName: "area",
                windowIndex: nil
            ),
        ]
    }

    func areaCaptureRect() throws -> CGRect {
        guard let region = self.region?.trimmingCharacters(in: .whitespacesAndNewlines),
              !region.isEmpty
        else {
            throw ValidationError("Region must be provided when using --mode area")
        }

        let values = region
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard values.count == 4,
              let x = Double(values[0]),
              let y = Double(values[1]),
              let width = Double(values[2]),
              let height = Double(values[3])
        else {
            throw ValidationError("Region must be x,y,width,height")
        }

        guard width > 0, height > 0 else {
            throw ValidationError("Region width and height must be greater than zero")
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func captureMenuBar() async throws -> [ImageCapturedFile] {
        let observation = try await self.captureObservation(
            target: .menubar,
            preferredName: "menubar",
            index: nil
        )
        return try [
            self.capturedFile(
                from: observation,
                preferredName: "menubar",
                windowIndex: nil
            ),
        ]
    }

    private func captureObservation(
        target: DesktopObservationTargetRequest,
        preferredName: String?,
        index: Int?
    ) async throws -> DesktopObservationResult {
        let url = self.makeOutputURL(preferredName: preferredName, index: index)

        return try await self.services.desktopObservation.observe(self.makeObservationRequest(
            target: target,
            outputURL: url
        ))
    }
}

private extension DesktopCaptureFormat {
    var mimeType: String {
        switch self {
        case .bmp:
            "image/bmp"
        case .png:
            "image/png"
        }
    }
}

private extension DesktopDisplay {
    var displayIdentity: DisplayIdentity {
        DisplayIdentity(
            index: self.index,
            name: self.name,
            bounds: self.bounds.cgRect,
            scaleFactor: CGFloat(self.scaleFactor))
    }
}

private extension DesktopApplication {
    var applicationIdentity: ApplicationIdentity {
        ApplicationIdentity(
            processIdentifier: Int32(clamping: self.processIdentifier),
            bundleIdentifier: self.bundleIdentifier,
            name: self.executableName)
    }
}

private extension DesktopWindow {
    var windowIdentity: WindowIdentity {
        WindowIdentity(
            windowID: Int(clamping: self.windowIdentifier),
            title: self.title,
            bounds: self.bounds.cgRect,
            index: self.index)
    }
}

private extension DesktopRect {
    var cgRect: CGRect {
        CGRect(x: self.x, y: self.y, width: self.width, height: self.height)
    }
}
