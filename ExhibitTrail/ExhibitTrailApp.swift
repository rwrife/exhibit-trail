import SwiftUI
import ExhibitTrailKit

@main
struct ExhibitTrailApp: App {
    @State private var store: VisitStore?
    @State private var storageFailed = false

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
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
                        var directory = support.resolvingSymlinksInPath().appendingPathComponent("ExhibitTrail", isDirectory: true)
                        #if DEBUG
                        if MapFixture.enabled, let id = ProcessInfo.processInfo.environment["EXHIBIT_UI_TEST_STORE"],
                           UUID(uuidString: id)?.uuidString == id {
                            directory.appendPathComponent(id, isDirectory: true)
                        }
                        #endif
                        let opened = try VisitStore(directory: directory)
                        store = opened
                        try? await opened.cleanup()
                    } catch {
                        storageFailed = true
                    }
                }
        }
    }
}
