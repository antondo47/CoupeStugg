//
//  LocationPickerView.swift
//  Coupe stuff
//
//  Created by Do Ngoc Anh on 1/26/26.
//

import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    
    // Default start position (San Francisco, or generic)
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    // Tracks the center of the map as user drags
    @State private var centerCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    var body: some View {
        ZStack {
            // 1. The Map
            Map(position: $position)
                .onMapCameraChange { context in
                    // Update our tracker whenever the map moves
                    centerCoordinate = context.region.center
                }
                .ignoresSafeArea()
            
            // 2. The Pin (Always in center)
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .background(Circle().fill(.white))
                .shadow(radius: 4)
                .padding(.bottom, 40) // Lift it slightly so the point is center
            
            // 3. Selection Button
            VStack {
                Spacer()
                Button {
                    // Save the coordinates
                    latitude = centerCoordinate.latitude
                    longitude = centerCoordinate.longitude
                    dismiss()
                } label: {
                    Text("Set Location Here")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.blue)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
        .navigationTitle("Pick Location")
        .navigationBarTitleDisplayMode(.inline)
    }
}
