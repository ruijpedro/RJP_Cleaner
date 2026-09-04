import Foundation
import Photos

enum PhotoFilter: String, CaseIterable, Identifiable {
    case all, recommended, photos, videos
    var id: String { rawValue }
    var title: String { switch self { case .all: "Todos"; case .recommended: "Sugestões"; case .photos: "Fotos"; case .videos: "Vídeos" } }
}

struct PhotoItem: Identifiable {
    let id: String
    let asset: PHAsset
    let size: Int64
    var selected = false
    var recommended = false
    var isVideo: Bool { asset.mediaType == .video }
    var isScreenshot: Bool { asset.mediaSubtypes.contains(.photoScreenshot) }
    var title: String { isVideo ? "Vídeo" : (isScreenshot ? "Screenshot" : "Fotografia") }
    var subtitle: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    var selected = false
    var name: String { url.lastPathComponent }
    var subtitle: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) + " · " + url.deletingLastPathComponent().lastPathComponent }
}
