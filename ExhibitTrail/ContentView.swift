import SwiftUI
import ExhibitTrailKit

/// Skeleton root view. Issue #3 replaces this canvas area with the imported
/// floor-plan view; the whole screen remains wrapped by
/// `ExhibitWorkspaceLayout` (issue #6), the single seam where a future iPhone
/// Duo split would attach.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Exhibit Trail")
                .font(.title)
                .accessibilityAddTraits(.isHeader)
            Text(ExhibitTrailKit.milestone)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Offline. Your map, your shortlist, your clock.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
