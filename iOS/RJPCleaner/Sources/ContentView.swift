import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: CleanerModel
    @State private var showFolderPicker = false
    @State private var confirmPhotoDelete = false
    @State private var confirmFileDelete = false

    var body: some View {
        TabView {
            NavigationStack { dashboard }
                .tabItem { Label("Início", systemImage: "gauge.with.dots.needle.67percent") }
            NavigationStack { photosView }
                .tabItem { Label("Fotos", systemImage: "photo.on.rectangle.angled") }
            NavigationStack { filesView }
                .tabItem { Label("Ficheiros", systemImage: "folder") }
        }
        .tint(.teal)
    }

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Image(systemName: "sparkles.rectangle.stack.fill").font(.system(size: 52)).foregroundStyle(.teal)
                    Text("RJP Cleaner").font(.largeTitle.bold())
                    Text("iOS · limpeza segura").foregroundStyle(.secondary)
                }.padding(.top, 24)

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.message, systemImage: "checkmark.shield")
                        HStack {
                            Stat(value: "\(model.photos.count)", label: "Fotos/Vídeos")
                            Spacer()
                            Stat(value: "\(model.files.count)", label: "Ficheiros")
                            Spacer()
                            Stat(value: ByteCountFormatter.string(fromByteCount: model.selectedBytes, countStyle: .file), label: "Selecionado")
                        }
                    }
                }

                Button { Task { await model.scanPhotos() } } label: {
                    ActionCard(icon: "photo.stack", title: "Analisar Fototeca", subtitle: "Fotos, vídeos, grandes e duplicados")
                }
                Button { showFolderPicker = true } label: {
                    ActionCard(icon: "folder.badge.gearshape", title: "Analisar uma pasta", subtitle: "Downloads, iCloud Drive ou outra pasta escolhida")
                }
                Button { Task { await model.findDuplicates() } } label: {
                    ActionCard(icon: "square.on.square", title: "Procurar duplicados", subtitle: "Compara conteúdo exato de até 250 itens")
                }.disabled(model.photos.isEmpty)

                Text("No iPhone, o RJP Cleaner só gere a Fototeca autorizada e pastas que escolhas explicitamente. Não entra nos dados privados do WhatsApp ou de outras apps.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
            }.padding()
        }
        .navigationTitle("RJP Cleaner")
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker { url in
                showFolderPicker = false
                Task { await model.scanFolder(url) }
            }
        }
    }

    private var photosView: some View {
        List {
            if !model.duplicateGroups.isEmpty {
                Section("Duplicados") {
                    ForEach(Array(model.duplicateGroups.enumerated()), id: \.offset) { index, group in
                        HStack { Image(systemName: "square.on.square"); Text("Grupo \(index + 1)"); Spacer(); Text("\(group.count) itens").foregroundStyle(.secondary) }
                    }
                }
            }
            Section("Maiores primeiro") {
                ForEach(model.photos) { item in
                    Button { model.togglePhoto(item.id) } label: {
                        HStack {
                            Image(systemName: item.selected ? "checkmark.circle.fill" : "circle").foregroundStyle(item.selected ? .teal : .secondary)
                            VStack(alignment: .leading) { Text(item.title); Text(item.subtitle).font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Fotos e vídeos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Analisar") { Task { await model.scanPhotos() } } }
            ToolbarItem(placement: .bottomBar) { Button(role: .destructive) { confirmPhotoDelete = true } label: { Label("Apagar \(model.selectedPhotoCount)", systemImage: "trash") }.disabled(model.selectedPhotoCount == 0) }
        }
        .confirmationDialog("Apagar os itens selecionados?", isPresented: $confirmPhotoDelete, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) { Task { await model.deleteSelectedPhotos() } }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var filesView: some View {
        List(model.files) { item in
            Button { model.toggleFile(item.id) } label: {
                HStack {
                    Image(systemName: item.selected ? "checkmark.circle.fill" : "circle").foregroundStyle(item.selected ? .teal : .secondary)
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
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker { url in showFolderPicker = false; Task { await model.scanFolder(url) } }
        }
        .confirmationDialog("Eliminar definitivamente os ficheiros selecionados desta pasta?", isPresented: $confirmFileDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { model.deleteSelectedFiles() }
            Button("Cancelar", role: .cancel) {}
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
