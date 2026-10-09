import SwiftUI
import ExhibitTrailKit

@main
struct ExhibitTrailApp: App {
    @State private var store: VisitStore?
    @State private var storageFailed = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay(alignment: .bottom) {
                    if storageFailed {
                        Text("Local storage could not be opened. Your saved data has not been reset.")
                            .font(.footnote)
                            .padding()
                    }
                }
                .task {
                    guard store == nil else { return }
                    do {
                        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        let opened = try VisitStore(directory: support.resolvingSymlinksInPath().appendingPathComponent("ExhibitTrail", isDirectory: true))
                        store = opened
                        try? await opened.cleanup()
                    } catch {
                        storageFailed = true
                    }
                }
        }
    }
}
