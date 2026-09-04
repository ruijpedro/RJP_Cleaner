import Foundation
import Photos
import CryptoKit

@MainActor
final class CleanerModel: ObservableObject {
    @Published var authorization: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var photos: [PhotoItem] = []
    @Published var duplicateGroups: [[PhotoItem]] = []
    @Published var files: [FileItem] = []
    @Published var isScanningPhotos = false
    @Published var isScanningFiles = false
    @Published var message = "Pronto para analisar"
    @Published var photoFilter: PhotoFilter = .all

    @Published var autoScanEnabled: Bool = UserDefaults.standard.object(forKey: "autoScan") as? Bool ?? true { didSet { UserDefaults.standard.set(autoScanEnabled, forKey: "autoScan") } }
    @Published var suggestLargeVideos: Bool = UserDefaults.standard.object(forKey: "largeVideos") as? Bool ?? true { didSet { UserDefaults.standard.set(suggestLargeVideos, forKey: "largeVideos") } }
    @Published var suggestOldMedia: Bool = UserDefaults.standard.object(forKey: "oldMedia") as? Bool ?? true { didSet { UserDefaults.standard.set(suggestOldMedia, forKey: "oldMedia") } }
    @Published var suggestScreenshots: Bool = UserDefaults.standard.object(forKey: "screenshots") as? Bool ?? true { didSet { UserDefaults.standard.set(suggestScreenshots, forKey: "screenshots") } }
    @Published var largeVideoMB: Int = UserDefaults.standard.object(forKey: "largeVideoMB") as? Int ?? 300 { didSet { UserDefaults.standard.set(largeVideoMB, forKey: "largeVideoMB"); refreshRecommendations() } }
    @Published var oldDays: Int = UserDefaults.standard.object(forKey: "oldDays") as? Int ?? 180 { didSet { UserDefaults.standard.set(oldDays, forKey: "oldDays"); refreshRecommendations() } }
    private var didAutoAnalyze = false

    var selectedPhotoCount: Int { photos.filter(\.selected).count }
    var selectedFileCount: Int { files.filter(\.selected).count }
    var selectedPhotoBytes: Int64 { photos.filter(\.selected).reduce(0) { $0 + $1.size } }
    var selectedBytes: Int64 { selectedPhotoBytes + files.filter(\.selected).reduce(0) { $0 + $1.size } }
    var photoBytes: Int64 { photos.reduce(0) { $0 + $1.size } }
    var recommendedBytes: Int64 { photos.filter(\.recommended).reduce(0) { $0 + $1.size } }
    var reclaimableProgress: Double { photoBytes > 0 ? min(1, Double(recommendedBytes) / Double(photoBytes)) : 0 }
    var filteredPhotos: [PhotoItem] {
        switch photoFilter {
        case .all: photos
        case .recommended: photos.filter(\.recommended)
        case .photos: photos.filter { !$0.isVideo }
        case .videos: photos.filter(\.isVideo)
        }
    }

    func autoAnalyzeIfNeeded() async {
        guard autoScanEnabled, !didAutoAnalyze else { return }
        didAutoAnalyze = true
        await scanPhotos()
    }

    func requestPhotoAccess() async { authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }

    func scanPhotos() async {
        if authorization != .authorized && authorization != .limited { await requestPhotoAccess() }
        guard authorization == .authorized || authorization == .limited else { message = "Acesso à Fototeca não autorizado"; return }
        isScanningPhotos = true; message = "A analisar fotografias e vídeos…"
        defer { isScanningPhotos = false }

        let fetch = PHAsset.fetchAssets(with: nil)
        var result: [PhotoItem] = []; result.reserveCapacity(fetch.count)
        for index in 0..<fetch.count {
            let asset = fetch.object(at: index)
            let size = await assetApproximateSize(asset)
            result.append(PhotoItem(id: asset.localIdentifier, asset: asset, size: size))
        }
        photos = result.sorted { $0.size > $1.size }
        refreshRecommendations()
        message = "\(photos.count) itens · \(ByteCountFormatter.string(fromByteCount: recommendedBytes, countStyle: .file)) potencialmente recuperáveis"
    }

    private func refreshRecommendations() {
        guard !photos.isEmpty else { return }
        let oldLimit = Date().addingTimeInterval(-Double(oldDays) * 86_400)
        for i in photos.indices {
            let p = photos[i]
            let largeVideo = suggestLargeVideos && p.isVideo && p.size >= Int64(largeVideoMB) * 1024 * 1024
            let old = suggestOldMedia && (p.asset.creationDate ?? Date()) < oldLimit
            let screenshot = suggestScreenshots && p.isScreenshot && (p.asset.creationDate ?? Date()) < Date().addingTimeInterval(-30 * 86_400)
            photos[i].recommended = largeVideo || old || screenshot
        }
    }

    func selectRecommendedPhotos() {
        for i in photos.indices { photos[i].selected = photos[i].recommended }
        message = "\(selectedPhotoCount) recomendações selecionadas · confirma antes de apagar"
    }

    private func assetApproximateSize(_ asset: PHAsset) async -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else { return 0 }
        return await withCheckedContinuation { continuation in
            var total: Int64 = 0
            let options = PHAssetResourceRequestOptions(); options.isNetworkAccessAllowed = false
            PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { total += Int64($0.count) }, completionHandler: { _ in continuation.resume(returning: total) })
        }
    }

    func findDuplicates(limit: Int = 250) async {
        guard !photos.isEmpty else { return }
        message = "A procurar duplicados…"
        var buckets: [String: [PhotoItem]] = [:]
        for item in photos.prefix(limit) { if let digest = await hash(asset: item.asset) { buckets[digest, default: []].append(item) } }
        duplicateGroups = buckets.values.filter { $0.count > 1 }.sorted { left, right in
            left.reduce(Int64(0)) { $0 + $1.size } > right.reduce(Int64(0)) { $0 + $1.size }
        }
        let duplicateIds = Set(duplicateGroups.flatMap { Array($0.dropFirst()).map(\.id) })
        for i in photos.indices { if duplicateIds.contains(photos[i].id) { photos[i].recommended = true } }
        message = duplicateGroups.isEmpty ? "Sem duplicados exatos na amostra" : "\(duplicateGroups.count) grupos de duplicados encontrados"
    }

    private func hash(asset: PHAsset) async -> String? {
        guard let resource = PHAssetResource.assetResources(for: asset).first else { return nil }
        return await withCheckedContinuation { continuation in
            var hasher = SHA256(); let options = PHAssetResourceRequestOptions(); options.isNetworkAccessAllowed = false
            PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { hasher.update(data: $0) }, completionHandler: { error in
                guard error == nil else { continuation.resume(returning: nil); return }
                continuation.resume(returning: hasher.finalize().map { String(format: "%02x", $0) }.joined())
            })
        }
    }

    func scanFolder(_ url: URL) async {
        isScanningFiles = true; message = "A analisar a pasta selecionada…"
        defer { isScanningFiles = false }
        let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
        guard granted else { message = "Sem autorização para esta pasta"; return }
        guard let found = Self.enumerateFiles(in: url) else { message = "Não foi possível ler a pasta"; return }
        files = found.sorted { $0.size > $1.size }; message = "\(files.count) ficheiros encontrados"
    }

    private nonisolated static func enumerateFiles(in url: URL) -> [FileItem]? {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return nil }
        var found: [FileItem] = []
        while let itemURL = enumerator.nextObject() as? URL {
            guard let values = try? itemURL.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            let size = Int64(values.fileSize ?? 0); if size > 0 { found.append(FileItem(url: itemURL, size: size)) }
        }
        return found
    }

    func deleteSelectedPhotos() async {
        let assets = photos.filter(\.selected).map(\.asset); guard !assets.isEmpty else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets as NSArray) }
            let ids = Set(assets.map(\.localIdentifier)); photos.removeAll { ids.contains($0.id) }
            message = "Fotos/vídeos enviados para Apagados recentemente"
        } catch { message = "Não foi possível eliminar: \(error.localizedDescription)" }
    }

    func deleteSelectedFiles() {
        let selected = files.filter(\.selected); var removed = Set<UUID>()
        for item in selected {
            let parent = item.url.deletingLastPathComponent(); let granted = parent.startAccessingSecurityScopedResource()
            defer { if granted { parent.stopAccessingSecurityScopedResource() } }
            if granted, (try? FileManager.default.removeItem(at: item.url)) != nil { removed.insert(item.id) }
        }
        files.removeAll { removed.contains($0.id) }; message = "\(removed.count) ficheiros eliminados"
    }

    func togglePhoto(_ id: String) { guard let i = photos.firstIndex(where: { $0.id == id }) else { return }; photos[i].selected.toggle() }
    func toggleFile(_ id: UUID) { guard let i = files.firstIndex(where: { $0.id == id }) else { return }; files[i].selected.toggle() }
}
