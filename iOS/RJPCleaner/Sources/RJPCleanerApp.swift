import SwiftUI

@main
struct RJPCleanerApp: App {
    @StateObject private var model = CleanerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
