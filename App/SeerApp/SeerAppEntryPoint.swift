import SwiftUI

@main
enum SeerAppEntryPoint {
    @MainActor
    static func main() {
        #if DEBUG
            // Hosted unit tests must not initialize CloudKit or production services.
            if NSClassFromString("XCTestCase") != nil {
                HostedUnitTestApp.main()
                return
            }
        #endif
        SeerApp.main()
    }
}

#if DEBUG
    private struct HostedUnitTestApp: App {
        var body: some Scene {
            WindowGroup {
                Color.clear
            }
        }
    }
#endif
