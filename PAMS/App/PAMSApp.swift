import SwiftUI

@main
struct PAMSApp: App {

    init() {
        KeyManager.bootstrap() 
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
