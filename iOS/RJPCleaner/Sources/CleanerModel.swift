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

    var selectedPhotoCount: Int { photos.filter(\.selected).count }
    var selectedFileCount: Int { files.filter(\.selected).count }
    var selectedBytes: Int64 { photos.filter(\.selected).reduce(0) { $0 + $1.size } + files.filter(\.selected).reduce(0) { $0 + $1.size } }

    func requestPhotoAccess() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func scanPhotos() async {
        if authorization != .authorized && authorization != .limited {
            await requestPhotoAccess()
        }

        guard authorization == .authorized || authorization == .limited else {
            message = "Acesso à Fototeca não autorizado"
            return
        }
        isScanningPhotos = true
        message = "A analisar fotografias e vídeos…"
        defer { isScanningPhotos = false }

        let fetch = PHAsset.fetchAssets(with: nil)
        var result: [PhotoItem] = []
        result.reserveCapacity(fetch.count)

        for index in 0..<fetch.count {
            let asset = fetch.object(at: index)
            let size = await assetApproximateSize(asset)
            result.append(PhotoItem(id: asset.localIdentifier, asset: asset, size: size))
        }
        photos = result.sorted { $0.size > $1.size }
        message = "\(photos.count) itens analisados"
    }

    private func assetApproximateSize(_ asset: PHAsset) async -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else { return 0 }
        return await withCheckedContinuation { continuation in
            var total: Int64 = 0
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { data in
                total += Int64(data.count)
            }, completionHandler: { _ in
                continuation.resume(returning: total)
            })
        }
    }

    func findDuplicates(limit: Int = 250) async {
        guard !photos.isEmpty else { return }
        message = "A procurar duplicados…"
        var buckets: [String: [PhotoItem]] = [:]
        for item in photos.prefix(limit) {
            if let digest = await hash(asset: item.asset) {
                buckets[digest, default: []].append(item)
            }
        }
        duplicateGroups = buckets.values.filter { $0.count > 1 }.sorted { a, b in
            a.reduce(0) { $0 + $1.size } > b.reduce(0) { $0 + $1.size }
        }
        message = duplicateGroups.isEmpty ? "Sem duplicados exatos na amostra" : "\(duplicateGroups.count) grupos de duplicados encontrados"
    }

    private func hash(asset: PHAsset) async -> String? {
        guard let resource = PHAssetResource.assetResources(for: asset).first else { return nil }
        return await withCheckedContinuation { continuation in
            var hasher = SHA256()
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { data in
                hasher.update(data: data)
            }, completionHandler: { error in
                guard error == nil else { continuation.resume(returning: nil); return }
                continuation.resume(returning: hasher.finalize().map { String(format: "%02x", $0) }.joined())
            })
        }
    }

    func scanFolder(_ url: URL) async {
        isScanningFiles = true
        message = "A analisar a pasta selecionada…"
        defer { isScanningFiles = false }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        guard granted else { message = "Sem autorização para esta pasta"; return }

        guard let found = Self.enumerateFiles(in: url) else {
            message = "Não foi possível ler a pasta"
            return
        }
        files = found.sorted { $0.size > $1.size }
        message = "\(files.count) ficheiros encontrados"
    }


    private nonisolated static func enumerateFiles(in url: URL) -> [FileItem]? {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var found: [FileItem] = []
        while let itemURL = enumerator.nextObject() as? URL {
            guard let values = try? itemURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                continue
            }
            let size = Int64(values.fileSize ?? 0)
            if size > 0 {
                found.append(FileItem(url: itemURL, size: size))
            }
        }
        return found
    }

    func deleteSelectedPhotos() async {
        let assets = photos.filter(\.selected).map(\.asset)
        guard !assets.isEmpty else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            photos.removeAll { assets.contains($0.asset) }
            message = "Fotografias/vídeos enviados para Apagados recentemente"
        } catch {
            message = "Não foi possível eliminar: \(error.localizedDescription)"
        }
    }

    func deleteSelectedFiles() {
        let selected = files.filter(\.selected)
        var removed = Set<UUID>()
        for item in selected {
            let parent = item.url.deletingLastPathComponent()
            let granted = parent.startAccessingSecurityScopedResource()
            defer { if granted { parent.stopAccessingSecurityScopedResource() } }
            if granted, (try? FileManager.default.removeItem(at: item.url)) != nil { removed.insert(item.id) }
        }
        files.removeAll { removed.contains($0.id) }
        message = "\(removed.count) ficheiros eliminados"
    }

    func togglePhoto(_ id: String) {
        guard let i = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[i].selected.toggle()
    }

    func toggleFile(_ id: UUID) {
        guard let i = files.firstIndex(where: { $0.id == id }) else { return }
        files[i].selected.toggle()
    }
}
