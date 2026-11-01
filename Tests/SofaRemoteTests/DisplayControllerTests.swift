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
}
