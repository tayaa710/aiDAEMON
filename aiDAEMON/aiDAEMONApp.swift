import SwiftUI

@main
struct aiDAEMONApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Settings will go here")
                .frame(width: 300, height: 200)
        }
    }
}
