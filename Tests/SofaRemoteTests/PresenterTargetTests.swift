import Testing
@testable import SofaRemote

@Suite struct PresenterTargetTests {
    @Test func recognizesOnlySupportedFrontmostApps() {
        #expect(PresenterTarget.classify("com.apple.iWork.Keynote") == "keynote")
        #expect(PresenterTarget.classify("com.microsoft.Powerpoint") == "powerpoint")
        #expect(PresenterTarget.classify("com.brave.Browser") == "browser")
        #expect(PresenterTarget.classify("unknown") == "")
        #expect(!PresenterTarget.matches("keynote", bundleID: "com.brave.Browser"))
        #expect(!PresenterTarget.matches("", bundleID: nil))
    }
}
