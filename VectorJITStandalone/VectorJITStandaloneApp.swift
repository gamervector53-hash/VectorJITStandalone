import SwiftUI

@main
struct VectorJITStandaloneApp: App {
    @StateObject private var model = JITModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onOpenURL { url in model.handle(url: url) }
        }
    }
}
