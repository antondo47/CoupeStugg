# Coupe stuff

SwiftUI companion app for couples: shared anniversary timer, photo backdrop, and collaborative journal with map memories. Realtime sync is via Firebase Firestore/Storage.

## Features
- Home tab: shared hero photo + live “together for” counter.
- Journal: add entries with text, photos, date, and location; map view of tagged memories.
- Pairing: auto-generated couple code; partner enters code to sync stats and journal in realtime.

## Requirements
- Xcode 15+ (SPM support for Firebase).
- iOS 17+ deployment target.
- Firebase project (Firestore + Storage enabled).

## Setup
1) **Clone** and open `Coupe stuff.xcodeproj`.
2) **Firebase plist**  
3) **SPM deps** (if missing)  
   - File → Add Package Dependencies → `https://github.com/firebase/firebase-ios-sdk` (Up to Next Major).  
   - Add to target: `FirebaseFirestore`, `FirebaseFirestoreSwift`, `FirebaseStorage` (optionally Auth/Analytics).
4) **Firestore**  
   - In Firebase console: Build → Firestore Database → Create database (any region).  
   - Start with test rules for development, then tighten before production.

## Running on your iPhone (free Personal Team)
1) Plug in iPhone, unlock, Trust This Computer.  
2) Xcode Settings → Accounts → add your Apple ID.  
3) Target `Coupe stuff` → Signing & Capabilities: Team = your Apple ID (Personal Team), bundle id unique if needed.  
4) Select your device in the run destination dropdown → `Cmd+R`.  
5) On device: Settings → General → VPN & Device Management → trust the developer app. Re-run if needed.  
Note: free profiles expire after 7 days; rebuild to refresh.

## TestFlight / distribution
- Requires Apple Developer Program.  
- Product → Archive → Distribute → App Store Connect → Upload.  
- Add partner as internal tester or create a public link in TestFlight.

## How sync works (overview)
- `CoupleSyncService`: listens to Firestore for `couples/{coupleId}/meta/stats` and `couples/{coupleId}/entries`.  
- Photo uploads go to Firebase Storage under `couples/{coupleId}/stats` or `entries/{docId}`.  
- Pairing code stored locally in `UserDefaults` and in Firestore path.

## Notes / TODOs
- Firestore security rules needed for real use (restrict access by coupleId/token).  
- Current image download grabs only the first image per entry for bandwidth; extend as needed.  
- Free Firebase tier has read/write limits—monitor in console.

