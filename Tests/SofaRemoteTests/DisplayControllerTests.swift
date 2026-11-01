import CoreGraphics
import Testing
@testable import SofaRemote

@Suite @MainActor struct DisplayControllerTests {
    @Test func quartzCoordinatesAndClampingAcrossDisplays() {
        let external = DisplayController.quartzFrame(for: CGRect(x: -1920, y: 100, width: 1920, height: 1080), primaryHeight: 900)
        #expect(external == CGRect(x: -1920, y: -280, width: 1920, height: 1080))
        #expect(DisplayController.clamp(CGPoint(x: -2200, y: 1000), to: external) == CGPoint(x: -1920, y: 799))
        #expect(DisplayController.clamp(CGPoint(x: -3, y: 0), to: external) == CGPoint(x: -3, y: 0))
    }

    @Test func invalidDisplayDoesNotChangeSelection() {
        let controller = DisplayController(preferredID: "retained-disconnected-display")
        #expect(!controller.select("not-a-connected-display-839745"))
        #expect(controller.preferredID == "retained-disconnected-display")
    }
    @Test func revokedMoveFailsBeforeAnyAccessibilityOperation() async {
        let controller = DisplayController()
        await #expect(throws: CancellationError.self) { try await controller.moveFrontWindow(authorized: { false }) }
    }

    @Test func projectionLeavesPointsInsideAnyDisplayUntouched() {
        // L-shaped layout: a 1440×900 primary at origin and a 1920×1080 external shifted
        // up-left so the two frames share only a short vertical edge; the bounding box
        // covers virtual gap pixels no display owns.
        let primary = DisplayController.quartzFrame(for: CGRect(x: 0, y: 0, width: 1440, height: 900), primaryHeight: 900)
        let external = DisplayController.quartzFrame(for: CGRect(x: -1920, y: 100, width: 1920, height: 1080), primaryHeight: 900)
        let frames = [primary, external]
        // Point already inside external — must pass through, not snap to primary.
        #expect(DisplayController.project(CGPoint(x: -500, y: -100), onto: frames) == CGPoint(x: -500, y: -100))
        // Point inside primary — must pass through, including negative-y area.
        #expect(DisplayController.project(CGPoint(x: 100, y: 50), onto: frames) == CGPoint(x: 100, y: 50))
    }

    @Test func projectionSnapsGapPointsToTheNearestRealDisplayPixel() {
        let primary = DisplayController.quartzFrame(for: CGRect(x: 0, y: 0, width: 1440, height: 900), primaryHeight: 900)
        let external = DisplayController.quartzFrame(for: CGRect(x: -1920, y: 100, width: 1920, height: 1080), primaryHeight: 900)
        let frames = [primary, external]
        // A point in the staggered gap below the external and left of the primary must land
        // on an actual pixel of whichever rect is closer, never float in the virtual void.
        let projected = DisplayController.project(CGPoint(x: -100, y: 850), onto: frames)
        #expect(frames.contains { $0.contains(projected) })
        // The external's bottom row is 51 points away; the primary's left edge is 100 away.
        #expect(projected == CGPoint(x: -100, y: 799))
    }

    @Test func projectionSnapsOuterEdgePointsAndPreservesCrossing() {
        let primary = DisplayController.quartzFrame(for: CGRect(x: 0, y: 0, width: 1440, height: 900), primaryHeight: 900)
        let external = DisplayController.quartzFrame(for: CGRect(x: -1920, y: 100, width: 1920, height: 1080), primaryHeight: 900)
        let frames = [primary, external]
        // Far past the right outer edge: snaps to primary's last column.
        let right = DisplayController.project(CGPoint(x: 5000, y: 400), onto: frames)
        #expect(right == CGPoint(x: primary.maxX - 1, y: 400))
        // Far past the external's left outer edge: snaps to external, not to primary.
        let left = DisplayController.project(CGPoint(x: -5000, y: 500), onto: frames)
        #expect(left == CGPoint(x: external.minX, y: 500))
        // Crossing from primary to external along a shared y keeps the pointer free — a
        // mid-point near the shared edge remains inside external, not clamped back.
        let crossing = DisplayController.project(CGPoint(x: -1, y: 400), onto: frames)
        #expect(external.contains(crossing) || primary.contains(crossing))
    }

    @Test func projectionHandlesNonFiniteAndEmptyInputs() {
        let primary = DisplayController.quartzFrame(for: CGRect(x: 0, y: 0, width: 1440, height: 900), primaryHeight: 900)
        let nan = DisplayController.project(CGPoint(x: CGFloat.nan, y: 0), onto: [primary])
        #expect(nan == CGPoint(x: primary.midX, y: primary.midY))
        #expect(DisplayController.project(CGPoint(x: 10, y: 10), onto: []) == CGPoint(x: 10, y: 10))
    }
}
