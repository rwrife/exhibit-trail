import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import ExhibitTrailKit

struct ContentView: View {
    let store: VisitStore?
    @State private var visit: Visit?
    @State private var plan: FloorPlan?
    @State private var image: UIImage?
    @State private var importing = false
    @State private var errorText: String?
    @State private var zoom: CGFloat = 1
    @State private var name = ""
    @State private var priority: Priority = .interested
    @State private var selectedID: String?
    @State private var pdfData: Data?
    @State private var page = 0
    @State private var pageCount = 0
    @FocusState private var nameFocused: Bool
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if let visit {
                    Section("Floor plan") {
                        if let plan, let image {
                            ScrollView([.horizontal, .vertical]) {
                                let width = 300.0 * zoom
                                let height = width * CGFloat(plan.height / plan.width)
                                ZStack(alignment: .topLeading) {
                                        Image(uiImage: image).resizable().frame(width: width, height: height)
                                        ForEach(Array(visit.stops.enumerated()), id: \.element.id) { index, stop in
                                            if let pin = stop.pin {
                                                Button { select(stop) } label: {
                                                    Text("\(index + 1)").font(.headline).frame(width: 44, height: 44)
                                                        .background(.blue, in: Circle()).foregroundStyle(.white)
                                                }
                                                .position(x: min(max(pin.x * width, 22), max(width - 22, 22)),
                                                          y: min(max(pin.y * height, 22), max(height - 22, 22)))
                                                .accessibilityLabel("Pin \(index + 1), \(stop.title)")
                                            }
                                        }
                                    }
                                    .frame(width: width, height: height)
                                    .contentShape(Rectangle())
                                    .onTapGesture { location in
                                        guard let pin = MapCoordinate.pin(x: Double(location.x), y: Double(location.y), width: Double(width), height: Double(height)) else { return }
                                        if let selectedID, let index = self.visit?.stops.firstIndex(where: { $0.id == selectedID }) {
                                            self.visit?.stops[index].pin = pin
                                        } else {
                                            self.visit?.stops.append(Stop(title: "Stop \(visit.stops.count + 1)", pin: pin))
                                        }
                                        save()
                                    }
                            }
                            .frame(height: 320)
                            Text("Floor plan, page \(plan.page + 1). The ordered stop list below lets you select, reorder and remove stops without gestures.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Zoom out") { zoom = max(1, zoom / 1.5) }
                                Button("Zoom in") { zoom = min(4, zoom * 1.5) }
                            }
                        } else {
                            Text("Import a floor plan you own or have permission to use.")
                        }
                        Button("Import image or PDF") { importing = true }
                        #if DEBUG
                        if MapFixture.enabled {
                            Button("Import test fixture map") { Task { await importFixture() } }
                                .accessibilityIdentifier("map.fixture")
                        }
                        #endif
                        if let pdfData, pageCount > 1 {
                            Stepper("PDF page \(page + 1) of \(pageCount)", value: $page, in: 0...(pageCount - 1))
                            Button("Use selected page") { Task { await usePage(pdfData, page: page) } }
                        }
                    }
                    Section("Ordered stops — select, then tap map to position") {
                        if selectedID != nil {
                            Button("New stop") {
                                selectedID = nil; name = ""; priority = .interested; nameFocused = false
                            }
                        }
                        TextField("Exhibit name", text: $name).accessibilityIdentifier("stop.name")
                            .focused($nameFocused)
                        Picker("Priority", selection: $priority) {
                            Text("Must-see").tag(Priority.mustSee)
                            Text("Interested").tag(Priority.interested)
                            Text("Bonus").tag(Priority.bonus)
                        }
                        Button(selectedID == nil ? "Add unpinned stop" : "Save stop") {
                            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let selectedID, let index = self.visit?.stops.firstIndex(where: { $0.id == selectedID }) {
                                self.visit?.stops[index].title = trimmed
                                self.visit?.stops[index].priority = priority
                            } else {
                                self.visit?.stops.append(Stop(title: trimmed, priority: priority))
                            }
                            selectedID = nil; name = ""; nameFocused = false; save()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        ForEach(Array(visit.stops.enumerated()), id: \.element.id) { index, stop in
                            HStack {
                                Button("\(index + 1). \(stop.title), \(stop.priority.rawValue)\(stop.pin == nil ? ", unpinned" : ", pinned")") { select(stop) }
                                Spacer()
                                if index > 0 { Button("Move up \(stop.title)") { move(index, index - 1) } }
                                if index + 1 < visit.stops.count { Button("Move down \(stop.title)") { move(index, index + 1) } }
                            }
                            .buttonStyle(.borderless)
                        }
                        .onDelete { offsets in
                            self.visit?.stops.remove(atOffsets: offsets)
                            selectedID = nil; save()
                        }
                    }
                } else {
                    Button("Start local visit") { visit = Visit(title: "My visit"); save() }
                        .disabled(store == nil)
                }
                if let errorText { Text(errorText).foregroundStyle(.red).accessibilityIdentifier("visit.error") }
            }
            .navigationTitle("Exhibit Trail")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.png, .jpeg, .pdf]) { result in
                switch result {
                case .success(let url): Task { await importPlan(url) }
                case .failure(let error): errorText = error.localizedDescription
                }
            }
            .task(id: store != nil) { await load() }
        }
    }

    private func select(_ stop: Stop) { selectedID = stop.id; name = stop.title; priority = stop.priority }
    #if DEBUG
    private func importFixture() async {
        do { pdfData = nil; pageCount = 0; try await persist(MapFixture.pngData(), page: 0) }
        catch { errorText = error.localizedDescription }
    }
    #endif
    private func save() {
        guard let store, let visit else { return }
        // Snapshot the value; Swift 6 forbids escaping mutable @State into a Task.
        let snapshot = visit
        // Chain on the previous write so overlapping edits commit in order.
        let previous = saveTask
        saveTask = Task {
            await previous?.value
            do { try await store.save(snapshot); errorText = nil } catch { errorText = error.localizedDescription }
        }
    }
    private func flushSave() async {
        let pending = saveTask
        saveTask = nil
        await pending?.value
    }
    private func move(_ from: Int, _ to: Int) {
        visit?.stops.swapAt(from, to)
        save()
    }
    private func load() async {
        guard let store else { return }
        do {
            visit = try await store.visits().first
            if let visit {
                plan = try await store.floorPlan(visitID: visit.id)
                if let plan {
                    let data = try await store.attachmentData(id: plan.attachmentID)
                    image = try render(data, page: plan.page).image
                    if data.starts(with: Array("%PDF-".utf8)) {
                        pdfData = data; pageCount = try validPDF(data).pageCount; page = plan.page
                    }
                }
            }
        } catch { errorText = error.localizedDescription }
    }
    private func importPlan(_ url: URL) async {
        guard let store, visit != nil else { return }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard size.isRegularFile == true, let bytes = size.fileSize,
                  bytes > 0, bytes <= VisitStore.maximumAssetBytes else { throw StorageError.oversizedAsset }
            let input = try FileHandle(forReadingFrom: url)
            defer { try? input.close() }
            var data = Data()
            while let chunk = try input.read(upToCount: min(65536, VisitStore.maximumAssetBytes + 1 - data.count)), !chunk.isEmpty {
                data.append(chunk)
                guard data.count <= VisitStore.maximumAssetBytes else { throw StorageError.oversizedAsset }
            }
            guard data.count == bytes else { throw StorageError.invalidData }
            if data.starts(with: Array("%PDF-".utf8)) {
                let pdf = try validPDF(data)
                pdfData = data; pageCount = pdf.pageCount; page = 0
            } else {
                pdfData = nil; pageCount = 0
            }
            try await persist(data, page: 0)
        } catch { errorText = error.localizedDescription }
    }
    private func usePage(_ data: Data, page: Int) async {
        guard let store, let visit, let plan else { return }
        await flushSave()
        do {
            let drawn = try render(data, page: page)
            let next = FloorPlan(attachmentID: plan.attachmentID, page: page, width: drawn.width, height: drawn.height)
            try await store.setFloorPlan(next, visitID: visit.id)
            self.plan = next; image = drawn.image; zoom = 1; errorText = nil
        } catch { errorText = error.localizedDescription }
    }
    private func persist(_ data: Data, page: Int) async throws {
        guard let visit, let store else { throw StorageError.invalidData }
        await flushSave()
        let drawn = try render(data, page: page)
        let type: AssetType = data.starts(with: Array("%PDF-".utf8)) ? .pdf :
            data.starts(with: [137,80,78,71,13,10,26,10]) ? .png : .jpeg
        // Provider URL is never persisted. Controlled app-owned temporary copy passes store path checks.
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: temporary, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let asset = try await store.importAsset(from: temporary, visitID: visit.id, type: type,
                                               width: drawn.width, height: drawn.height)
        let next = FloorPlan(attachmentID: asset.id, page: page, width: drawn.width, height: drawn.height)
        do { try await store.setFloorPlan(next, visitID: visit.id) }
        catch { try? await store.deleteAttachment(id: asset.id); throw error }
        let previous = plan?.attachmentID
        plan = next; image = drawn.image; zoom = 1
        if let previous, previous != asset.id {
            do { try await store.deleteAttachment(id: previous) }
            catch { errorText = "New map saved, but old copy could not be removed: \(error.localizedDescription)"; return }
        }
        errorText = nil
    }
    private func validPDF(_ data: Data) throws -> PDFDocument {
        guard let pdf = PDFDocument(data: data), (1...100).contains(pdf.pageCount), !pdf.isEncrypted else { throw StorageError.invalidData }
        return pdf
    }
    private func render(_ data: Data, page: Int) throws -> (image: UIImage, width: Double, height: Double) {
        guard !data.isEmpty, data.count <= VisitStore.maximumAssetBytes else { throw StorageError.oversizedAsset }
        if data.starts(with: Array("%PDF-".utf8)) {
            let pdf = try validPDF(data)
            guard (0..<pdf.pageCount).contains(page), let sheet = pdf.page(at: page) else { throw StorageError.invalidData }
            let bounds = sheet.bounds(for: .cropBox)
            guard bounds.minX.isFinite, bounds.minY.isFinite else { throw StorageError.invalidData }
            let width = Double(bounds.width), height = Double(bounds.height)
            guard width.isFinite, height.isFinite, width > 0, height > 0,
                  width <= 10_000, height <= 10_000, width * height <= 25_000_000 else { throw StorageError.invalidData }
            let scale = min(1, 4096 / max(width, height))
            return (sheet.thumbnail(of: CGSize(width: width * scale, height: height * scale), for: .cropBox), width, height)
        }
        guard data.starts(with: [137,80,78,71,13,10,26,10]) || data.starts(with: [255,216,255]),
              let image = UIImage(data: data) else { throw StorageError.invalidData }
        let width = Double(image.size.width), height = Double(image.size.height)
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              width <= 10_000, height <= 10_000, width * height <= 25_000_000 else { throw StorageError.invalidData }
        return (image, width, height)
    }
}
