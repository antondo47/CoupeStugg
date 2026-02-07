//
//  JournalView.swift
//  Coupe stuff
//
//  Created by Do Ngoc Anh on 1/26/26.
//

import SwiftUI
import PhotosUI
import MapKit

// MARK: - 1. DATA MODEL
struct JournalEntry: Identifiable, Hashable {
    // Local stable identifier for SwiftUI lists; not synced to backend
    var id: UUID = UUID()
    // Firestore document id so we can update/delete the right record
    var firestoreId: String?
    var title: String = ""
    var date: Date = Date()
    var content: String = ""
    var locationName: String = ""
    var images: [Data] = []
    var imageURLs: [String] = []

    var latitude: Double?
    var longitude: Double?

    var coordinate: CLLocationCoordinate2D? {
        if let lat = latitude, let long = longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: long)
        }
        return nil
    }
}

// MARK: - 2. HELPER VIEW: ROW CARD (Clean - No Menu Here)
struct JournalRowView: View {
    let entry: JournalEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Date Column
            VStack(spacing: 2) {
                Text(entry.date.formatted(.dateTime.month(.abbreviated))).font(.caption).bold().foregroundStyle(.gray)
                Text(entry.date.formatted(.dateTime.day())).font(.title2).bold()
                Text(entry.date.formatted(.dateTime.year())).font(.caption).foregroundStyle(.gray)
            }.frame(width: 50)
            
            // Memory Card
            VStack(alignment: .leading, spacing: 0) {
                // Cover Image
                if let firstData = entry.images.first, let uiImage = UIImage(data: firstData) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: uiImage).resizable().scaledToFill().frame(height: 180).clipped()
                        if entry.images.count > 0 {
                            HStack(spacing: 4) { Image(systemName: "photo.on.rectangle"); Text("\(entry.images.count)") }
                                .font(.caption2).bold().padding(6).background(.black.opacity(0.6)).foregroundStyle(.white).cornerRadius(6).padding(8)
                        }
                    }
                } else if let firstURL = entry.imageURLs.first, let url = URL(string: firstURL) {
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill().frame(height: 180).clipped()
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 180)
                        }
                        if entry.imageURLs.count > 0 {
                            HStack(spacing: 4) { Image(systemName: "photo.on.rectangle"); Text("\(entry.imageURLs.count)") }
                                .font(.caption2).bold().padding(6).background(.black.opacity(0.6)).foregroundStyle(.white).cornerRadius(6).padding(8)
                        }
                    }
                } else {
                    Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 100).overlay(Image(systemName: "text.justify.left").foregroundColor(.gray))
                }
                
                // Title & Preview
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title).font(.headline).foregroundStyle(.black).lineLimit(2).multilineTextAlignment(.leading)
                    if !entry.content.isEmpty {
                        Text(entry.content).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }.padding(12)
            }
            .background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
    }
}

// MARK: - 3. EDITOR VIEW
struct JournalEditorView: View {
    // We accept the original entry to edit
    let originalEntry: JournalEntry
    
    // We use a local state that defaults to empty, but gets overwritten in .onAppear
    @State private var entry: JournalEntry = JournalEntry()
    
    var onSave: (JournalEntry) -> Void
    var onCancel: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showDatePicker = false
    @State private var showLocationSearch = false
    @State private var showPhotoPicker = false
    @State private var selectedItems: [PhotosPickerItem] = []
    
    // Assumes LocationSearchService is in your LocationServices.swift file
    @StateObject private var locationService = LocationSearchService()
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 15) {
                // Header
                VStack(alignment: .leading, spacing: 5) {
                    TextField("Memory title", text: $entry.title)
                        .font(.system(size: 28, weight: .bold))
                        .submitLabel(.done)
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline).foregroundColor(.gray)
                }
                .padding(.horizontal).padding(.top, 20)
                Divider().padding(.horizontal)
                
                // Location Pill
                if !entry.locationName.isEmpty {
                    HStack {
                        Image(systemName: "mappin.and.ellipse").foregroundColor(.blue)
                        Text(entry.locationName).fontWeight(.medium).foregroundColor(.blue)
                        Spacer()
                        Button {
                            withAnimation {
                                entry.locationName = ""
                                entry.latitude = nil
                                entry.longitude = nil
                            }
                        } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.blue.opacity(0.6)) }
                    }
                    .padding(10).background(Color.blue.opacity(0.1)).cornerRadius(10).padding(.horizontal).transition(.scale)
                }
                
                // Content Editor
                ZStack(alignment: .topLeading) {
                    if entry.content.isEmpty {
                        Text("Write your memory here...").foregroundColor(.gray.opacity(0.5)).padding(.top, 8).padding(.leading, 5)
                    }
                    TextEditor(text: $entry.content).scrollContentBackground(.hidden).frame(maxHeight: .infinity)
                }.padding(.horizontal)
                
                // Photo Strip
                if !entry.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(entry.images, id: \.self) { imgData in
                                if let uiImage = UIImage(data: imgData) {
                                    Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 80, height: 80).cornerRadius(8).clipped()
                                }
                            }
                        }.padding(.horizontal)
                    }.frame(height: 90)
                }
                
                // Bottom Toolbar
                HStack(spacing: 25) {
                    Button { showPhotoPicker = true } label: { Image(systemName: "photo").font(.title2).foregroundColor(.gray) }
                    Button { showDatePicker = true } label: { Image(systemName: "calendar").font(.title2).foregroundColor(.gray) }
                    Button { showLocationSearch = true } label: {
                        Image(systemName: "mappin.and.ellipse").font(.title2)
                            .foregroundColor(entry.locationName.isEmpty ? .gray : .blue)
                    }
                    Spacer()
                    Button { onSave(entry) } label: {
                        HStack { Text("SAVE"); Image(systemName: "chevron.right") }
                            .font(.headline).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.pink.opacity(0.8)).cornerRadius(20)
                    }
                }.padding()
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { onCancel() } label: { Image(systemName: "chevron.left").foregroundColor(.primary) }
                }
            }
            // Load Data Logic
            .onAppear {
                self.entry = originalEntry
            }
            // Sheets
            .sheet(isPresented: $showDatePicker) { DatePicker("Date", selection: $entry.date).datePickerStyle(.graphical).padding().presentationDetents([.medium]) }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItems, matching: .images)
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) { entry.images.append(data) }
                    }
                    selectedItems = []
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                NavigationStack {
                    List {
                        Section { TextField("Search...", text: $locationService.searchQuery) }
                        Section {
                            ForEach(locationService.completions, id: \.self) { completion in
                                Button {
                                    entry.locationName = completion.title
                                    locationService.search(for: completion) { mapItem in
                                        if let item = mapItem {
                                            entry.latitude = item.placemark.coordinate.latitude
                                            entry.longitude = item.placemark.coordinate.longitude
                                        }
                                    }
                                    showLocationSearch = false
                                } label: { VStack(alignment: .leading) { Text(completion.title).font(.headline); Text(completion.subtitle).font(.caption).foregroundColor(.gray) } }
                            }
                        }
                    }.navigationTitle("Add Location").navigationBarTitleDisplayMode(.inline)
                }.presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - 4. DETAIL VIEW
struct JournalDetailView: View {
    @Binding var entry: JournalEntry
    // Callback to handle deletion from the parent view
    var onDelete: () -> Void
    var onSave: (JournalEntry) -> Void
    @EnvironmentObject var sync: CoupleSyncService
    @State private var newComment: String = ""
    
    @Environment(\.dismiss) var dismiss
    @State private var isEditing = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Image
                if !entry.images.isEmpty {
                    TabView {
                        ForEach(entry.images, id: \.self) { imgData in
                            if let image = UIImage(data: imgData) {
                                Image(uiImage: image).resizable().scaledToFill().frame(height: 300).clipped()
                            }
                        }
                    }
                    .frame(height: 300)
                    .tabViewStyle(.page)
                } else if !entry.imageURLs.isEmpty {
                    TabView {
                        ForEach(entry.imageURLs, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill().frame(height: 300).clipped()
                                } placeholder: {
                                    Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 300)
                                }
                            }
                        }
                    }
                    .frame(height: 300)
                    .tabViewStyle(.page)
                }
                
                // Info Section
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.title).font(.largeTitle).bold()
                        Text(entry.date.formatted(date: .long, time: .shortened)).font(.subheadline).foregroundColor(.gray)
                    }
                    
                    if !entry.locationName.isEmpty {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Text(entry.locationName)
                        }
                        .font(.headline).foregroundColor(.blue).padding(.vertical, 5)
                    }
                    
                    Divider()
                    Text(entry.content).font(.body).lineSpacing(6)
                }
                .padding()

                // Comments
                if let fid = entry.firestoreId {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comments").font(.headline)
                        let comments = sync.comments[fid] ?? []
                        if comments.isEmpty {
                            Text("No comments yet").foregroundColor(.secondary).font(.subheadline)
                        } else {
                            ForEach(comments) { comment in
                                CommentRow(
                                    comment: comment,
                                    isMine: comment.authorId == sync.currentUserId,
                                    avatarURL: avatarURL(for: comment)
                                )
                            }
                        }

                        HStack {
                            TextField("Add a comment", text: $newComment)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !text.isEmpty else { return }
                                sync.addComment(to: entry, text: text)
                                newComment = ""
                            } label: {
                                Image(systemName: "paperplane.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // 1. LEFT: Custom Back Button
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundColor(.primary)
                }
            }
            
            // 2. RIGHT: "..." Menu for Edit/Delete
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { isEditing = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        dismiss() // Close the view
                        onDelete() // Delete the data
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primary)
                        .padding(8)
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            JournalEditorView(
                originalEntry: entry,
                onSave: { updatedEntry in
                    entry = updatedEntry
                    onSave(updatedEntry)
                    isEditing = false
                },
                onCancel: { isEditing = false }
            )
        }
        .onAppear {
            if let fid = entry.firestoreId {
                sync.startCommentsListener(for: fid)
            }
        }
        .onDisappear {
            if let fid = entry.firestoreId {
                sync.stopCommentsListener(for: fid)
            }
        }
    }

    private func avatarURL(for comment: Comment) -> String? {
        if let url = comment.authorAvatarURL { return url }
        if !comment.authorId.isEmpty, let profile = sync.profiles[comment.authorId] {
            return profile.avatarURL
        }
        return nil
    }
}

struct CommentRow: View {
    let comment: Comment
    let isMine: Bool
    let avatarURL: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine {
                Spacer()
                bubble
                avatar
            } else {
                avatar
                bubble
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(comment.text)
                .foregroundColor(.primary)
            Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(isMine ? Color.pink.opacity(0.15) : Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var avatar: some View {
        Group {
            if let avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.2))
                }
            } else {
                Circle().fill(Color.gray.opacity(0.2))
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }
}

// MARK: - 5. MAIN JOURNAL VIEW
struct JournalView: View {
    @EnvironmentObject var sync: CoupleSyncService

    @State private var editingEntry: JournalEntry?
    @State private var showMap = false
    @State private var showPersonalInfo = false

    // Sort logic
    var sortedEntries: [JournalEntry] {
        sync.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(sortedEntries) { entry in
                        if let binding = binding(for: entry.id) {
                            NavigationLink(destination:
                                JournalDetailView(
                                    entry: binding,
                                    onDelete: { deleteEntry(id: entry.id) },
                                    onSave: { save($0) }
                                )
                            ) {
                                JournalRowView(entry: entry)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Our Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showMap = true } label: { Image(systemName: "map").font(.body).foregroundColor(.primary) }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { startAddingNew() } label: { Image(systemName: "plus").font(.body).foregroundColor(.primary) }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showPersonalInfo = true } label: { Image(systemName: "person.crop.circle").font(.body).foregroundColor(.primary) }
                }
            }
            // Add New Entry Sheet
            .sheet(item: $editingEntry) { entryToEdit in
                JournalEditorView(
                    originalEntry: entryToEdit,
                    onSave: { newEntry in
                        save(newEntry)
                        editingEntry = nil
                    },
                    onCancel: { editingEntry = nil }
                )
            }
            // Map Sheet
            .sheet(isPresented: $showMap) {
                JournalMapView(entries: $sync.entries, onSave: { save($0) }, onDelete: { id in deleteEntry(id: id) })
            }
            .sheet(isPresented: $showPersonalInfo) {
                PersonalInfoView()
                    .environmentObject(sync)
            }
        }
    }
    
    // Helpers
    func startAddingNew() { editingEntry = JournalEntry() }
    
    func save(_ entry: JournalEntry) {
        sync.save(entry)
    }
    
    func deleteEntry(id: UUID) {
        sync.delete(entryId: id)
    }

    private func binding(for id: UUID) -> Binding<JournalEntry>? {
        guard let index = sync.entries.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { sync.entries[index] },
            set: { sync.entries[index] = $0 }
        )
    }
}
