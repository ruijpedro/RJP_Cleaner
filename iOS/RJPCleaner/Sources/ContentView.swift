import SwiftUI
import Photos
import UIKit

struct ContentView: View {
    @EnvironmentObject var model: CleanerModel
    @State private var showFolderPicker = false
    @State private var confirmPhotoDelete = false
    @State private var confirmFileDelete = false
    private let columns = [GridItem(.adaptive(minimum: 105), spacing: 10)]

    var body: some View {
        TabView {
            NavigationStack { dashboard }
                .tabItem { Label("Início", systemImage: "gauge.with.dots.needle.67percent") }
            NavigationStack { photosView }
                .tabItem { Label("Fotos", systemImage: "photo.on.rectangle.angled") }
            NavigationStack { filesView }
                .tabItem { Label("Ficheiros", systemImage: "folder") }
            NavigationStack { automationView }
                .tabItem { Label("Automático", systemImage: "wand.and.stars") }
        }
        .tint(.teal)
        .task { await model.autoAnalyzeIfNeeded() }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Image(systemName: "sparkles.rectangle.stack.fill").font(.system(size: 52)).foregroundStyle(.teal)
                    Text("RJP Cleaner").font(.largeTitle.bold())
                    Text("iOS · limpeza visual e segura").foregroundStyle(.secondary)
                }.padding(.top, 20)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(model.message, systemImage: "checkmark.shield")
                        ProgressView(value: model.reclaimableProgress)
                        HStack {
                            Stat(value: ByteCountFormatter.string(fromByteCount: model.photoBytes, countStyle: .file), label: "Fototeca")
                            Spacer()
                            Stat(value: ByteCountFormatter.string(fromByteCount: model.recommendedBytes, countStyle: .file), label: "Recuperável")
                            Spacer()
                            Stat(value: ByteCountFormatter.string(fromByteCount: model.selectedBytes, countStyle: .file), label: "Selecionado")
                        }
                    }
                }

                Button { Task { await model.scanPhotos() } } label: {
                    ActionCard(icon: "photo.stack", title: "Analisar Fototeca", subtitle: "Miniaturas, grandes, antigos e duplicados")
                }
                Button { model.selectRecommendedPhotos() } label: {
                    ActionCard(icon: "wand.and.stars", title: "Selecionar recomendações", subtitle: "Marca candidatos sem apagar automaticamente")
                }.disabled(model.photos.isEmpty)
                Button { showFolderPicker = true } label: {
                    ActionCard(icon: "folder.badge.gearshape", title: "Analisar uma pasta", subtitle: "Downloads, iCloud Drive ou outra pasta escolhida")
                }
                Button { Task { await model.findDuplicates() } } label: {
                    ActionCard(icon: "square.on.square", title: "Procurar duplicados", subtitle: "Deteta cópias exatas e estima espaço recuperável")
                }.disabled(model.photos.isEmpty)

                Text("A limpeza automática do iPhone funciona como análise e recomendação automática. Fotos, vídeos e ficheiros pessoais só são eliminados depois da tua confirmação.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
            }.padding()
        }
        .navigationTitle("RJP Cleaner")
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker { url in showFolderPicker = false; Task { await model.scanFolder(url) } }
        }
    }

    private var photosView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Filtro", selection: $model.photoFilter) {
                    ForEach(PhotoFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if model.isScanningPhotos { ProgressView("A analisar Fototeca…").padding() }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(model.filteredPhotos) { item in
                        Button { model.togglePhoto(item.id) } label: {
                            PhotoTile(item: item)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal)
            }.padding(.vertical)
        }
        .navigationTitle("Fotos e vídeos")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { model.selectRecommendedPhotos() } label: { Image(systemName: "wand.and.stars") }
                Button("Analisar") { Task { await model.scanPhotos() } }
            }
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) { confirmPhotoDelete = true } label: {
                    Label("Apagar \(model.selectedPhotoCount) · \(ByteCountFormatter.string(fromByteCount: model.selectedPhotoBytes, countStyle: .file))", systemImage: "trash")
                }.disabled(model.selectedPhotoCount == 0)
            }
        }
        .confirmationDialog("Mover os itens selecionados para Apagados recentemente?", isPresented: $confirmPhotoDelete, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) { Task { await model.deleteSelectedPhotos() } }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var filesView: some View {
        List(model.files) { item in
            Button { model.toggleFile(item.id) } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.selected ? "checkmark.circle.fill" : "circle").foregroundStyle(item.selected ? .teal : .secondary)
                    Image(systemName: "doc.fill").frame(width: 28).foregroundStyle(.secondary)
                    VStack(alignment: .leading) { Text(item.name).lineLimit(1); Text(item.subtitle).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                }
            }.buttonStyle(.plain)
        }
        .navigationTitle("Ficheiros")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Escolher pasta") { showFolderPicker = true } }
            ToolbarItem(placement: .bottomBar) { Button(role: .destructive) { confirmFileDelete = true } label: { Label("Apagar \(model.selectedFileCount)", systemImage: "trash") }.disabled(model.selectedFileCount == 0) }
        }
        .sheet(isPresented: $showFolderPicker) { FolderPicker { url in showFolderPicker = false; Task { await model.scanFolder(url) } } }
        .confirmationDialog("Eliminar definitivamente os ficheiros selecionados desta pasta?", isPresented: $confirmFileDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { model.deleteSelectedFiles() }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var automationView: some View {
        Form {
            Section("Gestão automática") {
                Toggle("Analisar automaticamente ao abrir", isOn: $model.autoScanEnabled)
                Toggle("Sugerir vídeos grandes", isOn: $model.suggestLargeVideos)
                Toggle("Sugerir conteúdos antigos", isOn: $model.suggestOldMedia)
                Toggle("Sugerir screenshots antigos", isOn: $model.suggestScreenshots)
            }
            Section("Regras") {
                Stepper("Vídeo grande: \(model.largeVideoMB) MB", value: $model.largeVideoMB, in: 100...2000, step: 100)
                Stepper("Antigo: \(model.oldDays) dias", value: $model.oldDays, in: 30...730, step: 30)
            }
            Section("Ação") {
                Button("Analisar agora") { Task { await model.scanPhotos() } }
                Button("Selecionar todos os recomendados") { model.selectRecommendedPhotos() }.disabled(model.photos.isEmpty)
                HStack { Text("Espaço potencial"); Spacer(); Text(ByteCountFormatter.string(fromByteCount: model.recommendedBytes, countStyle: .file)).foregroundStyle(.secondary) }
            }
            Section { Text("O RJP Cleaner nunca elimina fotos ou vídeos automaticamente em segundo plano. Faz a triagem automática e deixa a decisão final contigo.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Automático")
    }
}

private struct PhotoTile: View {
    let item: PhotoItem
    @State private var image: UIImage?
    private let manager = PHCachingImageManager()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let image { Image(uiImage: image).resizable().scaledToFill() }
                    else { Rectangle().fill(.quaternary).overlay { ProgressView() } }
                }
                .frame(height: 125).clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        if item.isVideo { Image(systemName: "video.fill") }
                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    }.font(.caption.bold())
                    if item.recommended { Text("Recomendado").font(.caption2) }
                }.foregroundStyle(.white).padding(7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(item.selected ? .teal : .white).shadow(radius: 2).padding(7)
        }
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(item.selected ? Color.teal : Color.clear, lineWidth: 3) }
        .task(id: item.id) { requestThumbnail() }
    }

    private func requestThumbnail() {
        let options = PHImageRequestOptions(); options.deliveryMode = .opportunistic; options.resizeMode = .fast; options.isNetworkAccessAllowed = true
        manager.requestImage(for: item.asset, targetSize: CGSize(width: 260, height: 260), contentMode: .aspectFill, options: options) { img, _ in
            if let img { DispatchQueue.main.async { image = img } }
        }
    }
}

private struct Stat: View {
    let value: String; let label: String
    var body: some View { VStack(alignment: .leading) { Text(value).font(.headline); Text(label).font(.caption).foregroundStyle(.secondary) } }
}
private struct ActionCard: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).frame(width: 38).foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(.primary); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
