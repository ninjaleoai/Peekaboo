import CoreGraphics
import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@MainActor
extension ImageCommandTests {
    @Test(.tags(.imageCapture))
    func `JSON output includes observation diagnostics`() async throws {
        let captureResult = Self.makeScreenCaptureResult(size: CGSize(width: 1200, height: 800), scale: 1.0)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        captureService.captureScreenHandler = { _, _ in
            captureResult
        }

        let services = TestServicesFactory.makePeekabooServices(
            screenCapture: captureService
        )
        let path = Self.makeTempCapturePath("diagnostics.png")

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--mode", "screen",
                "--path", path,
                "--json",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        let response = try JSONDecoder().decode(
            CodableJSONResponse<ImageCaptureResult>.self,
            from: Data(result.combinedOutput.utf8)
        )
        #expect(response.data.files.count == 1)
        #expect(response.data.observations.count == 1)
        #expect(response.data.observations[0].spans.contains { $0.name == "capture.screen" })
        #expect(response.data.observations[0].state_snapshot != nil)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test(.tags(.imageCapture))
    func `Compatible screen captures route through desktop adapter`() async throws {
        let captureResult = Self.makeScreenCaptureResult(size: CGSize(width: 1200, height: 800), scale: 1.0)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        var requestedDisplayIndex: Int?
        var requestedScale: CaptureScalePreference?
        captureService.captureScreenHandler = { displayIndex, scale in
            requestedDisplayIndex = displayIndex
            requestedScale = scale
            return captureResult
        }

        let services = TestServicesFactory.makePeekabooServices(
            screens: [Self.makeScreenInfo(scale: 2.0)],
            screenCapture: captureService
        )
        let path = Self.makeTempCapturePath("desktop-adapter.png")

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--mode", "screen",
                "--path", path,
                "--json",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        #expect(requestedDisplayIndex == 0)
        #expect(requestedScale == .logical1x)

        let response = try JSONDecoder().decode(
            CodableJSONResponse<ImageCaptureResult>.self,
            from: Data(result.combinedOutput.utf8)
        )
        let captureSpan = try #require(
            response.data.observations[0].spans.first { $0.name == "capture.screen" }
        )
        #expect(captureSpan.metadata["source"] == "desktop-adapter")
        #expect(response.data.files[0].path == path)
        #expect(response.data.files[0].mime_type == "image/png")
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == captureResult.imageData)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test(.tags(.imageCapture))
    func `Compatible area captures route through desktop adapter`() async throws {
        let captureResult = Self.makeScreenCaptureResult(size: CGSize(width: 300, height: 200), scale: 1.0)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        var requestedRect: CGRect?
        var requestedScale: CaptureScalePreference?
        captureService.captureAreaHandler = { rect, scale in
            requestedRect = rect
            requestedScale = scale
            return captureResult
        }

        let services = TestServicesFactory.makePeekabooServices(
            screens: [Self.makeScreenInfo(scale: 2.0)],
            screenCapture: captureService
        )
        let path = Self.makeTempCapturePath("desktop-adapter-area.png")

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--mode", "area",
                "--region", "10,20,300,200",
                "--path", path,
                "--json",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        #expect(requestedRect == CGRect(x: 10, y: 20, width: 300, height: 200))
        #expect(requestedScale == .logical1x)

        let response = try JSONDecoder().decode(
            CodableJSONResponse<ImageCaptureResult>.self,
            from: Data(result.combinedOutput.utf8)
        )
        let captureSpan = try #require(
            response.data.observations[0].spans.first { $0.name == "capture.area" }
        )
        #expect(captureSpan.metadata["source"] == "desktop-adapter")
        #expect(response.data.observations[0].target?.source == "desktop-adapter")
        #expect(response.data.files[0].path == path)
        #expect(response.data.files[0].mime_type == "image/png")
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == captureResult.imageData)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test(.tags(.imageCapture))
    func `Compatible window ID captures route through desktop adapter`() async throws {
        let window = ServiceWindowInfo(
            windowID: 42,
            title: "Adapter Window",
            bounds: CGRect(x: 10, y: 20, width: 640, height: 480),
            index: 7
        )
        let app = ServiceApplicationInfo(
            processIdentifier: 4242,
            bundleIdentifier: "dev.peekaboo.adapter",
            name: "AdapterApp",
            windowCount: 1
        )
        let captureResult = Self.makeCaptureResult(app: app, window: window)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        var requestedWindowID: CGWindowID?
        var requestedScale: CaptureScalePreference?
        captureService.captureWindowByIdHandler = { windowID, scale in
            requestedWindowID = windowID
            requestedScale = scale
            return captureResult
        }

        let applications = StubApplicationService(
            applications: [app],
            windowsByApp: [app.name: [window]]
        )
        let services = TestServicesFactory.makePeekabooServices(
            applications: applications,
            screenCapture: captureService
        )
        let path = Self.makeTempCapturePath("desktop-adapter-window.png")

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--window-id", "\(window.windowID)",
                "--path", path,
                "--json",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        #expect(requestedWindowID == CGWindowID(window.windowID))
        #expect(requestedScale == .logical1x)

        let response = try JSONDecoder().decode(
            CodableJSONResponse<ImageCaptureResult>.self,
            from: Data(result.combinedOutput.utf8)
        )
        let captureSpan = try #require(
            response.data.observations[0].spans.first { $0.name == "capture.window" }
        )
        #expect(captureSpan.metadata["source"] == "desktop-adapter")
        #expect(response.data.observations[0].target?.source == "desktop-adapter")
        #expect(response.data.files[0].path == path)
        #expect(response.data.files[0].item_label == "Adapter Window")
        #expect(response.data.files[0].window_title == "Adapter Window")
        #expect(response.data.files[0].window_id == UInt32(window.windowID))
        #expect(response.data.files[0].window_index == 7)
        #expect(response.data.files[0].mime_type == "image/png")
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == captureResult.imageData)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test(.tags(.imageCapture))
    func `Compatible app window captures route through desktop adapter`() async throws {
        let helper = ServiceWindowInfo(
            windowID: 41,
            title: "",
            bounds: CGRect(x: 0, y: 0, width: 200, height: 100),
            index: 0
        )
        let window = ServiceWindowInfo(
            windowID: 42,
            title: "Adapter App Window",
            bounds: CGRect(x: 10, y: 20, width: 640, height: 480),
            isMainWindow: true,
            index: 1
        )
        let app = ServiceApplicationInfo(
            processIdentifier: 4242,
            bundleIdentifier: "dev.peekaboo.adapter",
            name: "AdapterApp",
            windowCount: 2
        )
        let captureResult = Self.makeCaptureResult(app: app, window: window)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        var requestedWindowID: CGWindowID?
        var requestedScale: CaptureScalePreference?
        captureService.captureWindowByIdHandler = { windowID, scale in
            requestedWindowID = windowID
            requestedScale = scale
            return captureResult
        }

        let applications = StubApplicationService(
            applications: [app],
            windowsByApp: [app.name: [helper, window]]
        )
        let services = TestServicesFactory.makePeekabooServices(
            applications: applications,
            screenCapture: captureService
        )
        let path = Self.makeTempCapturePath("desktop-adapter-app-window.png")

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--app", app.name,
                "--path", path,
                "--json",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        #expect(requestedWindowID == CGWindowID(window.windowID))
        #expect(requestedScale == .logical1x)

        let response = try JSONDecoder().decode(
            CodableJSONResponse<ImageCaptureResult>.self,
            from: Data(result.combinedOutput.utf8)
        )
        let captureSpan = try #require(
            response.data.observations[0].spans.first { $0.name == "capture.window" }
        )
        #expect(captureSpan.metadata["source"] == "desktop-adapter")
        #expect(response.data.observations[0].target?.source == "desktop-adapter")
        #expect(response.data.files[0].path == path)
        #expect(response.data.files[0].item_label == "Adapter App Window")
        #expect(response.data.files[0].window_title == "Adapter App Window")
        #expect(response.data.files[0].window_id == UInt32(window.windowID))
        #expect(response.data.files[0].window_index == 1)
        #expect(response.data.files[0].mime_type == "image/png")
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == captureResult.imageData)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test(.tags(.imageCapture))
    func `Compatible app multi-window captures route through desktop adapter`() async throws {
        let helper = ServiceWindowInfo(
            windowID: 40,
            title: "",
            bounds: CGRect(x: -10000, y: -10000, width: 80, height: 80),
            index: 0,
            isOffScreen: true,
            isOnScreen: false
        )
        let firstWindow = ServiceWindowInfo(
            windowID: 42,
            title: "Adapter Primary",
            bounds: CGRect(x: 10, y: 20, width: 640, height: 480),
            isMainWindow: true,
            index: 1
        )
        let secondWindow = ServiceWindowInfo(
            windowID: 43,
            title: "Adapter Secondary",
            bounds: CGRect(x: 700, y: 80, width: 500, height: 360),
            index: 2
        )
        let app = ServiceApplicationInfo(
            processIdentifier: 4242,
            bundleIdentifier: "dev.peekaboo.adapter",
            name: "AdapterApp",
            windowCount: 3
        )
        let captureService = StubScreenCaptureService(permissionGranted: true)
        var requestedWindowIDs: [CGWindowID] = []
        var requestedScales: [CaptureScalePreference] = []
        captureService.captureWindowByIdHandler = { windowID, scale in
            requestedWindowIDs.append(windowID)
            requestedScales.append(scale)
            let capturedWindow = windowID == CGWindowID(firstWindow.windowID) ? firstWindow : secondWindow
            return Self.makeCaptureResult(app: app, window: capturedWindow)
        }

        let applications = StubApplicationService(
            applications: [app],
            windowsByApp: [app.name: [helper, firstWindow, secondWindow]]
        )
        let services = TestServicesFactory.makePeekabooServices(
            applications: applications,
            screenCapture: captureService
        )
        let path = Self.makeTempCapturePath("desktop-adapter-multi.png")
        let outputURL = URL(fileURLWithPath: path)
        let secondPath = outputURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(outputURL.deletingPathExtension().lastPathComponent)_1")
            .appendingPathExtension(outputURL.pathExtension)
            .path

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--mode", "multi",
                "--app", app.name,
                "--path", path,
                "--json",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        #expect(requestedWindowIDs == [
            CGWindowID(firstWindow.windowID),
            CGWindowID(secondWindow.windowID),
        ])
        #expect(requestedScales.allSatisfy { $0 == .logical1x })

        let response = try JSONDecoder().decode(
            CodableJSONResponse<ImageCaptureResult>.self,
            from: Data(result.combinedOutput.utf8)
        )
        #expect(response.data.files.count == 2)
        #expect(response.data.observations.count == 2)
        #expect(response.data.files[0].path == path)
        #expect(response.data.files[0].item_label == "Adapter Primary")
        #expect(response.data.files[0].window_title == "Adapter Primary")
        #expect(response.data.files[0].window_id == UInt32(firstWindow.windowID))
        #expect(response.data.files[0].window_index == 1)
        #expect(response.data.files[0].mime_type == "image/png")
        #expect(response.data.files[1].path == secondPath)
        #expect(response.data.files[1].item_label == "Adapter Secondary")
        #expect(response.data.files[1].window_title == "Adapter Secondary")
        #expect(response.data.files[1].window_id == UInt32(secondWindow.windowID))
        #expect(response.data.files[1].window_index == 2)
        #expect(response.data.files[1].mime_type == "image/png")
        #expect(response.data.observations.allSatisfy { observation in
            observation.spans.contains { span in
                span.name == "capture.window" && span.metadata["source"] == "desktop-adapter"
            }
        })
        #expect(response.data.observations.allSatisfy { $0.target?.source == "desktop-adapter" })
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == Data(repeating: 0xAB, count: 32))
        #expect(try Data(contentsOf: URL(fileURLWithPath: secondPath)) == Data(repeating: 0xAB, count: 32))
        try? FileManager.default.removeItem(atPath: path)
        try? FileManager.default.removeItem(atPath: secondPath)
    }

    @Test(.tags(.imageCapture))
    func `Compatible frontmost captures route through desktop adapter`() async throws {
        let window = ServiceWindowInfo(
            windowID: 84,
            title: "Frontmost Adapter Window",
            bounds: CGRect(x: 30, y: 40, width: 800, height: 600),
            isMainWindow: true,
            index: 2
        )
        let app = ServiceApplicationInfo(
            processIdentifier: 8484,
            bundleIdentifier: "dev.peekaboo.frontmost",
            name: "FrontmostApp",
            windowCount: 1
        )
        let captureResult = Self.makeCaptureResult(app: app, window: window)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        var requestedScale: CaptureScalePreference?
        captureService.captureFrontmostHandler = { scale in
            requestedScale = scale
            return captureResult
        }

        let applications = StubApplicationService(
            applications: [app],
            windowsByApp: [app.name: [window]]
        )
        let services = TestServicesFactory.makePeekabooServices(
            applications: applications,
            screenCapture: captureService
        )
        let path = Self.makeTempCapturePath("desktop-adapter-frontmost.png")

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--mode", "frontmost",
                "--path", path,
                "--json",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        #expect(requestedScale == .logical1x)

        let response = try JSONDecoder().decode(
            CodableJSONResponse<ImageCaptureResult>.self,
            from: Data(result.combinedOutput.utf8)
        )
        let captureSpan = try #require(
            response.data.observations[0].spans.first { $0.name == "capture.frontmost" }
        )
        #expect(captureSpan.metadata["source"] == "desktop-adapter")
        #expect(response.data.observations[0].target?.source == "desktop-adapter")
        #expect(response.data.files[0].path == path)
        #expect(response.data.files[0].item_label == "frontmost")
        #expect(response.data.files[0].window_title == "Frontmost Adapter Window")
        #expect(response.data.files[0].window_id == UInt32(window.windowID))
        #expect(response.data.files[0].window_index == 2)
        #expect(response.data.files[0].mime_type == "image/png")
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == captureResult.imageData)
        try? FileManager.default.removeItem(atPath: path)
    }
}
#endif
