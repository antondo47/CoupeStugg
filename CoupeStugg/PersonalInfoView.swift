import SwiftUI
import PhotosUI

struct PersonalInfoView: View {
    @EnvironmentObject var sync: CoupleSyncService
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarPreview: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                Section("Avatar") {
                    HStack(spacing: 16) {
                        avatarView
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Text("Choose Photo")
                        }
                    }
                }

                Section("Name") {
                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Personal Info")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        sync.updateProfile(name: trimmed.isEmpty ? "Me" : trimmed, avatarData: avatarPreview?.jpegData(compressionQuality: 0.85))
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                let profile = sync.profiles[sync.currentUserId]
                name = profile?.name ?? ""
            }
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        avatarPreview = image
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarPreview {
            Image(uiImage: avatarPreview)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
        } else if let urlString = sync.profiles[sync.currentUserId]?.avatarURL,
                  let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.2))
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            Circle().fill(Color.gray.opacity(0.2))
                .frame(width: 56, height: 56)
        }
    }
}
