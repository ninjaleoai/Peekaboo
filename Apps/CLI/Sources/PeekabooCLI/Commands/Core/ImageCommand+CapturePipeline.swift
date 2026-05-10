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
        let desktop = self.services.desktop
        if await self.canUseDesktopWindowCapture(adapter: desktop, windowId: windowId) {
            return try await self.captureDesktopWindowById(windowId, adapter: desktop)
        }

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

    private func desktopSnapshot(adapter: any DesktopAsyncAdapter) async -> DesktopStateSnapshotSummary? {
        guard let displays = try? await adapter.listDisplays() else {
            return nil
        }

        return await self.desktopSnapshot(adapter: adapter, displays: displays)
    }

    private static func desktopCaptureSpan(
        name: String = "capture.screen",
        start: ContinuousClock.Instant,
        result: DesktopCaptureResult
    ) -> ObservationSpan {
        let duration = start.duration(to: ContinuousClock.now)
        let milliseconds = Double(duration.components.seconds * 1000)
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        return ObservationSpan(
            name: name,
            durationMS: milliseconds,
            metadata: [
                "byte_count": "\(result.byteCount)",
                "format": result.format.rawValue,
                "source": "desktop-adapter",
            ])
    }

    private func canUseDesktopWindowCapture(adapter: any DesktopAsyncAdapter, windowId: Int) async -> Bool {
        guard windowId >= 0,
              self.format == .png,
              !self.retina,
              self.captureEngine == nil,
              self.configuredCaptureEnginePreference == nil
        else {
            return false
        }

        let platformInfo = await adapter.platformInfo()
        return platformInfo.capabilities.contains(.captureWindowPNG)
    }

    private func captureDesktopWindowById(
        _ windowId: Int,
        adapter: any DesktopAsyncAdapter
    ) async throws -> [ImageCapturedFile] {
        let windowIdentifier = UInt64(windowId)
        let window = await self.desktopWindow(adapter: adapter, windowIdentifier: windowIdentifier)
        let preferredName = Self.preferredDesktopWindowCaptureName(window: window, windowId: windowId)
        let outputURL = self.makeOutputURL(preferredName: "window-\(windowId)", index: nil)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        let snapshot = await self.desktopSnapshot(adapter: adapter)
        let start = ContinuousClock.now
        let result = try await adapter.captureWindow(
            windowIdentifier: windowIdentifier,
            outputPath: outputURL.path)
        let span = Self.desktopCaptureSpan(name: "capture.window", start: start, result: result)
        let windowTitle = window?.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return [
            ImageCapturedFile(
                file: SavedFile(
                    path: result.path,
                    item_label: preferredName,
                    window_title: windowTitle?.isEmpty == false ? windowTitle : nil,
                    window_id: UInt32(clamping: windowIdentifier),
                    window_index: window?.index,
                    mime_type: result.format.mimeType),
                observation: ImageObservationDiagnostics(
                    spans: [span],
                    stateSnapshot: snapshot,
                    target: DesktopObservationTargetDiagnostics(
                        requestedKind: "window",
                        resolvedKind: "window",
                        source: "desktop-adapter",
                        bounds: result.bounds.cgRect))),
        ]
    }

    private func desktopWindow(
        adapter: any DesktopAsyncAdapter,
        windowIdentifier: UInt64
    ) async -> DesktopWindow? {
        let windows = (try? await adapter.listWindows(includeInvisible: true)) ?? []
        return windows.first { $0.windowIdentifier == windowIdentifier }
    }

    private static func preferredDesktopWindowCaptureName(window: DesktopWindow?, windowId: Int) -> String {
        let title = window?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let title, !title.isEmpty {
            return title
        }

        return "window-\(windowId)"
    }

    private func captureApplicationWindow(_ target: ImageWindowObservationTarget) async throws -> [ImageCapturedFile] {
        try await self.focusIfNeeded(appIdentifier: target.focusIdentifier)
        let desktop = self.services.desktop
        if await self.canUseDesktopApplicationWindowCapture(adapter: desktop) {
            return try await self.captureDesktopApplicationWindow(target, adapter: desktop)
        }

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

    private func canUseDesktopApplicationWindowCapture(adapter: any DesktopAsyncAdapter) async -> Bool {
        guard self.format == .png,
              !self.retina,
              self.captureEngine == nil,
              self.configuredCaptureEnginePreference == nil
        else {
            return false
        }

        let platformInfo = await adapter.platformInfo()
        return platformInfo.capabilities.contains(.captureWindowPNG)
    }

    private func captureDesktopApplicationWindow(
        _ target: ImageWindowObservationTarget,
        adapter: any DesktopAsyncAdapter
    ) async throws -> [ImageCapturedFile] {
        let resolved = try await self.resolveDesktopApplicationWindow(target, adapter: adapter)
        let resolvedTitle = resolved.window.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredName = self.windowTitle ??
            (resolvedTitle.isEmpty ? nil : resolvedTitle) ??
            target.preferredName
        let outputURL = self.makeOutputURL(preferredName: target.preferredName, index: nil)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        let snapshot = await self.desktopSnapshot(adapter: adapter)
        let start = ContinuousClock.now
        let result = try await adapter.captureWindow(
            windowIdentifier: resolved.window.windowIdentifier,
            outputPath: outputURL.path)
        let span = Self.desktopCaptureSpan(name: "capture.window", start: start, result: result)

        return [
            ImageCapturedFile(
                file: SavedFile(
                    path: result.path,
                    item_label: preferredName,
                    window_title: resolvedTitle.isEmpty ? nil : resolvedTitle,
                    window_id: UInt32(clamping: resolved.window.windowIdentifier),
                    window_index: resolved.window.index,
                    mime_type: result.format.mimeType),
                observation: ImageObservationDiagnostics(
                    spans: [span],
                    stateSnapshot: snapshot,
                    target: DesktopObservationTargetDiagnostics(
                        requestedKind: "window",
                        resolvedKind: "window",
                        source: "desktop-adapter",
                        bounds: result.bounds.cgRect))),
        ]
    }

    private func resolveDesktopApplicationWindow(
        _ target: ImageWindowObservationTarget,
        adapter: any DesktopAsyncAdapter
    ) async throws -> (application: DesktopApplication, window: DesktopWindow) {
        let applications = try await adapter.listApplications()
        let windows = try await adapter.listWindows(includeInvisible: true)

        let application: DesktopApplication
        let selection: WindowSelection
        switch target.target {
        case let .pid(pid, windowSelection):
            guard let match = applications.first(where: { $0.processIdentifier == UInt32(clamping: pid) }) else {
                throw DesktopObservationError.targetNotFound("pid \(pid)")
            }
            application = match
            selection = windowSelection ?? .automatic
        case let .app(identifier, windowSelection):
            guard let match = Self.desktopApplication(matching: identifier, in: applications) else {
                throw DesktopObservationError.targetNotFound(identifier)
            }
            application = match
            selection = windowSelection ?? .automatic
        default:
            throw DesktopObservationError.targetNotFound("application window")
        }

        let applicationWindows = windows.filter { $0.processIdentifier == application.processIdentifier }
        let selectedWindow = try Self.selectDesktopWindow(
            from: applicationWindows,
            selection: selection,
            applicationName: application.executableName)
        return (application, selectedWindow)
    }

    private static func desktopApplication(
        matching identifier: String,
        in applications: [DesktopApplication]
    ) -> DesktopApplication? {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercasedIdentifier = trimmedIdentifier.uppercased()
        if uppercasedIdentifier.hasPrefix("PID:"),
           let pid = UInt32(String(trimmedIdentifier.dropFirst("PID:".count)))
        {
            return applications.first(where: { $0.processIdentifier == pid })
        }

        if let bundleMatch = applications.first(where: { $0.bundleIdentifier == trimmedIdentifier }) {
            return bundleMatch
        }

        if let exactName = applications.first(where: {
            $0.executableName.compare(trimmedIdentifier, options: .caseInsensitive) == .orderedSame
        }) {
            return exactName
        }

        return applications.first(where: {
            $0.executableName.localizedCaseInsensitiveContains(trimmedIdentifier)
        })
    }

    private static func selectDesktopWindow(
        from windows: [DesktopWindow],
        selection: WindowSelection,
        applicationName: String
    ) throws -> DesktopWindow {
        switch selection {
        case .automatic:
            guard let window = self.bestDesktopWindow(from: windows) else {
                let criteria = windows.isEmpty ? "application window" : "shareable window for \(applicationName)"
                throw DesktopObservationError.targetNotFound(criteria)
            }
            return window
        case let .index(index):
            guard let window = windows.first(where: { $0.index == index }) ?? windows[desktopSafe: index] else {
                throw DesktopObservationError.targetNotFound("window index \(index)")
            }
            return window
        case let .title(title):
            guard let window = windows.first(where: { $0.title.localizedCaseInsensitiveContains(title) }) else {
                throw DesktopObservationError.targetNotFound("window title \(title)")
            }
            return window
        case let .id(windowID):
            let identifier = UInt64(windowID)
            guard let window = windows.first(where: { $0.windowIdentifier == identifier }) else {
                throw DesktopObservationError.targetNotFound("window id \(windowID)")
            }
            return window
        }
    }

    private static func bestDesktopWindow(from windows: [DesktopWindow]) -> DesktopWindow? {
        self.desktopCaptureCandidates(from: windows).max { lhs, rhs in
            let lhsScore = self.desktopWindowScore(lhs)
            let rhsScore = self.desktopWindowScore(rhs)
            if lhsScore == rhsScore {
                return lhs.index > rhs.index
            }
            return lhsScore < rhsScore
        }
    }

    private static func desktopCaptureCandidates(from windows: [DesktopWindow]) -> [DesktopWindow] {
        var seenWindowIdentifiers = Set<UInt64>()
        var candidates: [DesktopWindow] = []
        candidates.reserveCapacity(windows.count)

        for window in windows where seenWindowIdentifiers.insert(window.windowIdentifier).inserted {
            guard window.isVisible,
                  !window.isMinimized,
                  !window.isOffScreen,
                  window.isOnScreen,
                  window.layer == 0,
                  window.alpha > 0.01,
                  window.bounds.width >= 120,
                  window.bounds.height >= 90
            else {
                continue
            }
            candidates.append(window)
        }

        return candidates
    }

    private static func desktopWindowScore(_ window: DesktopWindow) -> Double {
        var score = 0.0

        if window.isForeground {
            score += 2000
        }
        if window.layer == 0 {
            score += 500
        }
        if window.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score -= 500
        } else {
            score += 2500
        }
        if !window.isMinimized {
            score += 300
        }

        let area = window.bounds.width * window.bounds.height
        if area > 0 {
            score += min(Double(area) / 150.0, 4000)
        }

        score += max(0, 600 - Double(window.index) * 40)
        return score
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
        let desktop = self.services.desktop
        if await self.canUseDesktopFrontmostCapture(adapter: desktop) {
            return try await self.captureDesktopFrontmost(adapter: desktop)
        }

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

    private func canUseDesktopFrontmostCapture(adapter: any DesktopAsyncAdapter) async -> Bool {
        guard self.format == .png,
              !self.retina,
              self.captureEngine == nil,
              self.configuredCaptureEnginePreference == nil
        else {
            return false
        }

        let platformInfo = await adapter.platformInfo()
        return platformInfo.capabilities.contains(.captureFrontmostPNG)
    }

    private func captureDesktopFrontmost(adapter: any DesktopAsyncAdapter) async throws -> [ImageCapturedFile] {
        let window = await self.desktopFrontmostWindow(adapter: adapter)
        let outputURL = self.makeOutputURL(preferredName: "frontmost", index: nil)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        let snapshot = await self.desktopSnapshot(adapter: adapter)
        let start = ContinuousClock.now
        let result = try await adapter.captureFrontmost(outputPath: outputURL.path)
        let span = Self.desktopCaptureSpan(name: "capture.frontmost", start: start, result: result)
        let windowTitle = window?.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return [
            ImageCapturedFile(
                file: SavedFile(
                    path: result.path,
                    item_label: "frontmost",
                    window_title: windowTitle?.isEmpty == false ? windowTitle : nil,
                    window_id: window.map { UInt32(clamping: $0.windowIdentifier) },
                    window_index: window?.index,
                    mime_type: result.format.mimeType),
                observation: ImageObservationDiagnostics(
                    spans: [span],
                    stateSnapshot: snapshot,
                    target: DesktopObservationTargetDiagnostics(
                        requestedKind: "frontmost",
                        resolvedKind: "window",
                        source: "desktop-adapter",
                        bounds: result.bounds.cgRect))),
        ]
    }

    private func desktopFrontmostWindow(adapter: any DesktopAsyncAdapter) async -> DesktopWindow? {
        let windows = (try? await adapter.listWindows(includeInvisible: true)) ?? []
        return windows.first(where: \.isForeground)
    }

    private func captureArea() async throws -> [ImageCapturedFile] {
        let rect = try self.areaCaptureRect()
        let desktop = self.services.desktop
        if await self.canUseDesktopAreaCapture(adapter: desktop) {
            let snapshot = await self.desktopSnapshot(adapter: desktop)
            let capture = try await self.captureDesktopArea(
                rect: rect,
                adapter: desktop,
                stateSnapshot: snapshot)
            return [capture]
        }

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

    private func canUseDesktopAreaCapture(adapter: any DesktopAsyncAdapter) async -> Bool {
        guard self.format == .png,
              !self.retina,
              self.captureEngine == nil,
              self.configuredCaptureEnginePreference == nil
        else {
            return false
        }

        let platformInfo = await adapter.platformInfo()
        return platformInfo.capabilities.contains(.captureAreaPNG)
    }

    private func captureDesktopArea(
        rect: CGRect,
        adapter: any DesktopAsyncAdapter,
        stateSnapshot: DesktopStateSnapshotSummary?
    ) async throws -> ImageCapturedFile {
        let outputURL = self.makeOutputURL(preferredName: "area", index: nil)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        let start = ContinuousClock.now
        let result = try await adapter.captureArea(rect.desktopRect, outputPath: outputURL.path)
        let span = Self.desktopCaptureSpan(name: "capture.area", start: start, result: result)

        return ImageCapturedFile(
            file: SavedFile(
                path: result.path,
                item_label: "area",
                mime_type: result.format.mimeType),
            observation: ImageObservationDiagnostics(
                spans: [span],
                stateSnapshot: stateSnapshot,
                target: DesktopObservationTargetDiagnostics(
                    requestedKind: "area",
                    resolvedKind: "area",
                    source: "desktop-adapter",
                    bounds: result.bounds.cgRect)))
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

private extension CGRect {
    var desktopRect: DesktopRect {
        DesktopRect(
            x: Self.desktopCoordinate(self.origin.x),
            y: Self.desktopCoordinate(self.origin.y),
            width: Self.desktopCoordinate(self.width),
            height: Self.desktopCoordinate(self.height))
    }

    private static func desktopCoordinate(_ value: CGFloat) -> Int {
        Int(value.rounded(.toNearestOrAwayFromZero))
    }
}

private extension Array {
    subscript(desktopSafe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
