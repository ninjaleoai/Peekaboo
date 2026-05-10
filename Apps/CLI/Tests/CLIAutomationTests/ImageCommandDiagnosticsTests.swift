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
