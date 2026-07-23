@testable import ScaffoldSchema
import Testing

/// These raw values are the wire format of `scaffold.yml`. Changing one is a
/// breaking change for every configuration file in existence, so they are
/// pinned here rather than left to the compiler's discretion.
@Suite("Wire format")
struct WireFormatTests {
    @Test("platform")
    func platform() {
        #expect(ApplePlatform.iOS.rawValue == "ios")
        #expect(ApplePlatform.macOS.rawValue == "macos")
    }

    @Test("product type")
    func productType() {
        #expect(ProductType.application.rawValue == "application")
        #expect(ProductType.framework.rawValue == "framework")
    }

    /// Objective-C is absent on purpose, so `objective-c` is rejected as an
    /// unknown value rather than as a temporarily unsupported one.
    @Test("programming language accepts Swift and nothing else")
    func programmingLanguage() {
        #expect(ProgrammingLanguage.swift.rawValue == "swift")
        #expect(ProgrammingLanguage.allowedValues == ["swift"])
    }

    @Test("swift language mode is a language mode, not a compiler version")
    func swiftLanguageMode() {
        #expect(SwiftLanguageMode.v5.rawValue == "5")
        #expect(SwiftLanguageMode.v6.rawValue == "6")
        #expect(SwiftLanguageMode.allCases.count == 2)
    }

    @Test("user interface framework")
    func uiFramework() {
        #expect(UIFramework.uiKit.rawValue == "uikit")
        #expect(UIFramework.swiftUI.rawValue == "swiftui")
        #expect(UIFramework.appKit.rawValue == "appkit")
    }

    @Test("application lifecycle")
    func applicationLifecycle() {
        #expect(ApplicationLifecycle.swiftUI.rawValue == "swiftui")
        #expect(ApplicationLifecycle.appDelegate.rawValue == "app-delegate")
        #expect(ApplicationLifecycle.appDelegateSceneDelegate.rawValue == "app-delegate-scene-delegate")
    }

    @Test("architecture pattern")
    func architecturePattern() {
        #expect(ArchitecturePattern.minimal.rawValue == "minimal")
        #expect(ArchitecturePattern.mvvm.rawValue == "mvvm")
        #expect(ArchitecturePattern.mvvmCoordinator.rawValue == "mvvm-c")
        #expect(ArchitecturePattern.clean.rawValue == "clean")
    }

    @Test("generator")
    func generator() {
        #expect(GeneratorKind.xcodegen.rawValue == "xcodegen")
        #expect(GeneratorKind.tuist.rawValue == "tuist")
    }

    @Test("unit test framework")
    func unitTestFramework() {
        #expect(UnitTestFramework.swiftTesting.rawValue == "swift-testing")
        #expect(UnitTestFramework.xctest.rawValue == "xctest")
        #expect(UnitTestFramework.disabled.rawValue == "none")
    }
}

@Suite("Interface implies a lifecycle")
struct ImpliedLifecycleTests {
    @Test("SwiftUI implies the SwiftUI lifecycle")
    func swiftUI() {
        #expect(UIFramework.swiftUI.impliedLifecycle == .swiftUI)
    }

    @Test("UIKit implies AppDelegate plus SceneDelegate")
    func uiKit() {
        #expect(UIFramework.uiKit.impliedLifecycle == .appDelegateSceneDelegate)
    }

    @Test("AppKit implies AppDelegate alone, since macOS has no scenes")
    func appKit() {
        #expect(UIFramework.appKit.impliedLifecycle == .appDelegate)
    }
}
