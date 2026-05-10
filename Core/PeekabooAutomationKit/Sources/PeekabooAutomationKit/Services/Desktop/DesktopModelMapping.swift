import CoreGraphics
import Foundation
import PeekabooDesktop

extension CGRect {
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

extension ScreenInfo {
    public var desktopDisplay: DesktopDisplay {
        DesktopDisplay(
            id: UInt64(self.displayID),
            index: self.index,
            bounds: self.frame.desktopRect,
            workArea: self.visibleFrame.desktopRect,
            isPrimary: self.isPrimary,
            name: self.name,
            scaleFactor: Double(self.scaleFactor))
    }
}

extension ServiceApplicationInfo {
    public var desktopApplication: DesktopApplication {
        DesktopApplication(
            processIdentifier: UInt32(clamping: self.processIdentifier),
            executableName: self.name,
            executablePath: self.bundlePath,
            isActive: self.isActive,
            visibleWindowCount: self.windowCount,
            bundleIdentifier: self.bundleIdentifier,
            isHidden: self.isHidden)
    }
}

extension ServiceWindowInfo {
    public func desktopWindow(processIdentifier: Int32 = 0, executableName: String? = nil) -> DesktopWindow {
        DesktopWindow(
            windowIdentifier: UInt64(clamping: self.windowID),
            processIdentifier: UInt32(clamping: processIdentifier),
            title: self.title,
            bounds: self.bounds.desktopRect,
            isVisible: self.isOnScreen && !self.isOffScreen && self.alpha > 0,
            isMinimized: self.isMinimized,
            isForeground: self.isMainWindow,
            executableName: executableName,
            index: self.index,
            screenIndex: self.screenIndex,
            screenName: self.screenName,
            isOffScreen: self.isOffScreen,
            layer: self.layer,
            isOnScreen: self.isOnScreen,
            isShareable: self.isShareableWindow && !self.isExcludedFromWindowsMenu,
            alpha: Double(self.alpha),
            spaceID: self.spaceID,
            spaceName: self.spaceName)
    }
}
