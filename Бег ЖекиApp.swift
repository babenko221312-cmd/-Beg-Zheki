import SwiftUI

@main
struct Бег_ЖекиApp: App {
    @StateObject private var runManager = RunManager()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Бег", systemImage: "figure.run")
                    }

                HistoryView()
                    .tabItem {
                        Label("История", systemImage: "clock.arrow.circlepath")
                    }
            }
            .environmentObject(runManager)
        }
    }
}
