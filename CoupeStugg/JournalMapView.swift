//
//  JournalMapView.swift
//  Coupe stuff
//
//  Created by Do Ngoc Anh on 1/26/26.
//

import SwiftUI
import MapKit

// 1. EXTRACTED VIEW: This fixes the compiler error by simplifying the main view.
struct MapPinView: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Bubble
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white)
                    .shadow(radius: 3)
                
                if let firstData = entry.images.first,
                   let uiImage = UIImage(data: firstData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                        .padding(3)
                } else {
                    Image(systemName: "mappin.circle.fill")
                        .resizable()
                        .foregroundColor(.red)
                        .frame(width: 40, height: 40)
                        .padding(5)
                }
            }
            .frame(width: 56, height: 56)
            
            // Triangle Pointer
            Image(systemName: "triangle.fill")
                .resizable()
                .frame(width: 10, height: 8)
                .foregroundColor(.white)
                .rotationEffect(.degrees(180))
                .offset(y: -2)
                .shadow(radius: 2)
            
            // Title Label
            Text(entry.title)
                .font(.caption)
                .bold()
                .foregroundColor(.black)
                .padding(4)
                .background(.white.opacity(0.8))
                .cornerRadius(4)
                .fixedSize()
                .offset(y: -5)
        }
    }
}

// 2. MAIN MAP VIEW
struct JournalMapView: View {
    @Binding var entries: [JournalEntry]
    var onSave: (JournalEntry) -> Void
    var onDelete: (UUID) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            // Filter entries safely
            let mapEntries = entries.filter { $0.latitude != nil && $0.longitude != nil }
            
            Map {
                ForEach(mapEntries) { entry in
                    if let coordinate = entry.coordinate {
                        Annotation(entry.locationName, coordinate: coordinate) {
                            // Link to Detail View
                            NavigationLink(value: entry.id) {
                                // Use the extracted view here
                                MapPinView(entry: entry)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .navigationTitle("Memory Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            // Navigate to Detail View logic
            .navigationDestination(for: UUID.self) { entryID in
                if let index = entries.firstIndex(where: { $0.id == entryID }) {
                    JournalDetailView(
                        entry: $entries[index],
                        onDelete: {
                            let id = entries[index].id
                            entries.remove(at: index)
                            onDelete(id)
                        },
                        onSave: { updated in onSave(updated) }
                    )
                }
            }
        }
    }
}
