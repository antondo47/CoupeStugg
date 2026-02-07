import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import UIKit

@MainActor
final class CoupleSyncService: ObservableObject {
    @Published var coupleId: String = UserDefaults.standard.string(forKey: "coupleId") ?? String(UUID().uuidString.prefix(6))
    @Published var currentUserId: String = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
    @Published var stats: CoupleStats = CoupleStats()
    @Published var entries: [JournalEntry] = []
    @Published var comments: [String: [Comment]] = [:] // keyed by firestore entry id
    @Published var profiles: [String: UserProfile] = [:] // keyed by userId
    @Published var isUploadingPhoto = false

    private var statsListener: ListenerRegistration?
    private var entriesListener: ListenerRegistration?
    private var commentListeners: [String: ListenerRegistration] = [:]
    private var profilesListener: ListenerRegistration?

    private let db: Firestore = {
        let db = Firestore.firestore()
        var settings = db.settings
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
        return db
    }()
    private let storage = Storage.storage()

    init() {
        UserDefaults.standard.set(coupleId, forKey: "coupleId")
        UserDefaults.standard.set(currentUserId, forKey: "userId")
        configureListeners()
    }

    func configure(coupleId: String) {
        guard !coupleId.isEmpty else { return }
        statsListener?.remove()
        entriesListener?.remove()
        self.coupleId = coupleId
        UserDefaults.standard.set(coupleId, forKey: "coupleId")
        configureListeners()
    }

    private func configureListeners() {
        listenToStats()
        listenToEntries()
        listenToProfiles()
    }

    private func listenToStats() {
        statsListener?.remove()
        statsListener = db.collection("couples").document(coupleId).collection("meta").document("stats")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let data = snapshot?.data() else { return }
                let timestamp = data["anniversaryDate"] as? Timestamp
                let urlString = data["photoURL"] as? String
                self.stats.anniversaryDate = timestamp?.dateValue() ?? Date()
                self.stats.photoURL = urlString.flatMap { URL(string: $0) }
            }
    }

    private func listenToEntries() {
        entriesListener?.remove()
        entriesListener = db.collection("couples").document(coupleId).collection("entries")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                Task { [weak self] in
                    var built: [JournalEntry] = []
                    for doc in documents {
                        guard let entry = self?.entryFromDoc(id: doc.documentID, data: doc.data()) else { continue }
                        var hydrated = entry
                        let datas = await self?.downloadAllImages(urlStrings: entry.imageURLs) ?? []
                        hydrated.images = datas
                        built.append(hydrated)
                    }
                    self?.entries = built
                }
            }
    }

    private func listenToProfiles() {
        profilesListener?.remove()
        profilesListener = db.collection("couples")
            .document(coupleId)
            .collection("profiles")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                var next: [String: UserProfile] = [:]
                for doc in documents {
                    let data = doc.data()
                    let name = data["name"] as? String ?? "Partner"
                    let avatarURL = data["avatarURL"] as? String
                    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                    let profile = UserProfile(id: doc.documentID, name: name, avatarURL: avatarURL, updatedAt: updatedAt)
                    next[doc.documentID] = profile
                }
                self.profiles = next
            }
    }

    private func downloadAllImages(urlStrings: [String]) async -> [Data] {
        var results: [Data] = []
        await withTaskGroup(of: Data?.self) { group in
            for urlString in urlStrings {
                group.addTask {
                    guard let url = URL(string: urlString) else { return nil }
                    return try? await URLSession.shared.data(from: url).0
                }
            }
            for await value in group {
                if let data = value { results.append(data) }
            }
        }
        return results
    }

    private func entryFromDoc(id: String, data: [String: Any]) -> JournalEntry? {
        let title = data["title"] as? String ?? ""
        let content = data["content"] as? String ?? ""
        let locationName = data["locationName"] as? String ?? ""
        let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let imageURLs = data["imageURLs"] as? [String] ?? []

        var entry = JournalEntry(
            id: UUID(),
            firestoreId: id,
            title: title,
            date: date,
            content: content,
            locationName: locationName,
            images: [],
            imageURLs: imageURLs
        )
        entry.latitude = latitude
        entry.longitude = longitude
        return entry
    }

    func updateStats(date: Date? = nil, photoData: Data? = nil) {
        Task {
            var newStats = stats
            if let date = date { newStats.anniversaryDate = date }
            if let photoData = photoData {
                isUploadingPhoto = true
                if let url = try? await uploadPhoto(data: photoData, path: "stats/main.jpg") {
                    newStats.photoURL = url
                }
                isUploadingPhoto = false
            }
            stats = newStats

            var payload: [String: Any] = [
                "anniversaryDate": Timestamp(date: newStats.anniversaryDate)
            ]
            if let url = newStats.photoURL { payload["photoURL"] = url.absoluteString }

            try? await db.collection("couples").document(coupleId)
                .collection("meta").document("stats")
                .setData(payload, merge: true)
        }
    }

    func save(_ entry: JournalEntry) {
        Task {
            var remote = RemoteEntry(from: entry)

            // Pre-create/choose the doc id so Storage paths match Firestore doc
            let entriesRef = db.collection("couples").document(coupleId).collection("entries")
            let docRef: DocumentReference = {
                if let fid = entry.firestoreId { return entriesRef.document(fid) }
                return entriesRef.document() // generate id first
            }()
            let docId = docRef.documentID

            // Upload images and replace data with URLs
            var urls: [String] = []
            for (idx, data) in entry.images.enumerated() {
                let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.8) ?? data
                do {
                    let url = try await uploadPhoto(data: jpeg, path: "entries/\(docId)/img_\(idx).jpg")
                    urls.append(url.absoluteString)
                } catch {
                    print("⚠️ Storage upload failed: \(error.localizedDescription)")
                }
            }
            remote.imageURLs = urls

            // If we expected images but none uploaded, abort so we don't save an empty entry
            if !entry.images.isEmpty && urls.isEmpty {
                print("⚠️ No images uploaded; skipping Firestore write")
                return
            }

            do {
                try await docRef.setData(remote.asDict(), merge: true)
            } catch {
                print("⚠️ Firestore save failed: \(error.localizedDescription)")
                return
            }

            // Optimistic local update with images so UI shows immediately
            var updated = entry
            updated.firestoreId = docId
            updated.imageURLs = urls
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index] = updated
            } else {
                entries.insert(updated, at: 0)
            }
        }
    }

    func delete(entryId: UUID) {
        guard let entry = entries.first(where: { $0.id == entryId }),
              let firestoreId = entry.firestoreId else { return }
        Task {
            try? await db.collection("couples").document(coupleId).collection("entries").document(firestoreId).delete()
        }
    }

    // MARK: - Comments
    func startCommentsListener(for entryFirestoreId: String) {
        // Avoid duplicate listeners
        if commentListeners[entryFirestoreId] != nil { return }
        let listener = db.collection("couples")
            .document(coupleId)
            .collection("entries")
            .document(entryFirestoreId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    let comments = documents.compactMap { doc -> Comment? in
                        if var comment = try? doc.data(as: Comment.self) {
                            comment.id = doc.documentID
                            return comment
                        }
                        let data = doc.data()
                        guard let text = data["text"] as? String else { return nil }
                        let author = data["author"] as? String ?? "Partner"
                        let authorId = data["authorId"] as? String ?? ""
                        let authorAvatarURL = data["authorAvatarURL"] as? String
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        var fallback = Comment(text: text)
                        fallback.id = doc.documentID
                        fallback.authorId = authorId
                        fallback.author = author
                        fallback.authorAvatarURL = authorAvatarURL
                        fallback.createdAt = createdAt
                        return fallback
                    }
                    self.comments[entryFirestoreId] = comments
                }
            }
        commentListeners[entryFirestoreId] = listener
    }

    func stopCommentsListener(for entryFirestoreId: String) {
        commentListeners[entryFirestoreId]?.remove()
        commentListeners.removeValue(forKey: entryFirestoreId)
    }

    func addComment(to entry: JournalEntry, text: String, author: String = "Partner") {
        guard let firestoreId = entry.firestoreId else { return }
        let profile = profiles[currentUserId]
        let payload: [String: Any] = [
            "authorId": currentUserId,
            "author": profile?.name ?? author,
            "authorAvatarURL": profile?.avatarURL as Any,
            "text": text,
            "createdAt": Timestamp(date: Date())
        ]
        Task {
            do {
                try await db.collection("couples")
                    .document(coupleId)
                    .collection("entries")
                    .document(firestoreId)
                    .collection("comments")
                    .addDocument(data: payload)
            } catch {
                print("⚠️ Failed to add comment: \(error.localizedDescription)")
            }
        }
    }

    func updateProfile(name: String, avatarData: Data?) {
        Task {
            var avatarURL: String? = profiles[currentUserId]?.avatarURL
            if let avatarData = avatarData {
                do {
                    let url = try await uploadPhoto(data: avatarData, path: "profiles/\(currentUserId)/avatar.jpg")
                    avatarURL = url.absoluteString
                } catch {
                    print("⚠️ Avatar upload failed: \(error.localizedDescription)")
                }
            }

            let payload: [String: Any] = [
                "name": name,
                "avatarURL": avatarURL as Any,
                "updatedAt": Timestamp(date: Date())
            ]

            do {
                try await db.collection("couples")
                    .document(coupleId)
                    .collection("profiles")
                    .document(currentUserId)
                    .setData(payload, merge: true)
            } catch {
                print("⚠️ Profile save failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Storage helper
    private func uploadPhoto(data: Data, path: String) async throws -> URL {
        let ref = storage.reference().child("couples").child(coupleId).child(path)
        _ = try await ref.putDataAsync(data, metadata: nil)
        return try await ref.downloadURL()
    }
}

// MARK: - Remote entry for Firestore
private struct RemoteEntry: Codable {
    var title: String
    var date: Date
    var content: String
    var locationName: String
    var latitude: Double?
    var longitude: Double?
    var imageURLs: [String]

    init(from entry: JournalEntry) {
        self.title = entry.title
        self.date = entry.date
        self.content = entry.content
        self.locationName = entry.locationName
        self.latitude = entry.latitude
        self.longitude = entry.longitude
        self.imageURLs = entry.imageURLs
    }

    func toJournalEntry(id: String) -> JournalEntry {
        var e = JournalEntry(
            id: UUID(),
            firestoreId: id,
            title: title,
            date: date,
            content: content,
            locationName: locationName,
            images: [],
            imageURLs: imageURLs
        )
        e.latitude = latitude
        e.longitude = longitude
        return e
    }

    func asDict() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "date": Timestamp(date: date),
            "content": content,
            "locationName": locationName,
            "imageURLs": imageURLs
        ]
        if let latitude = latitude { dict["latitude"] = latitude }
        if let longitude = longitude { dict["longitude"] = longitude }
        return dict
    }
}
