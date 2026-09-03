import Foundation
import Photos

struct PhotoItem: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    var size: Int64
    var selected: Bool = false

    var title: String { asset.mediaType == .video ? "Vídeo" : "Foto" }
    var subtitle: String {
        let date = asset.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "Sem data"
        return "\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) · \(date)"
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    var selected: Bool = false

    var name: String { url.lastPathComponent }
    var subtitle: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}
