//
//  ContentView.swift
//  Coupe stuff
//
//  Created by Do Ngoc Anh on 1/25/26.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject var sync: CoupleSyncService
    // 1. App State
    @State private var selectedItem: PhotosPickerItem?
    @State private var partnerImage: UIImage?
    @State private var anniversaryDate = Date()
    
    // UI States
    @State private var isCropping = false
    @State private var showDatePicker = false
    @State private var showPairing = false
    
    // Manual Crop States (Default values)
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    
    // 2. Timer Logic
    @State private var timeRemaining = DateComponents()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            TabView {
            // --- TAB 1: HOME ---
            ZStack {
                // Background Layer
                GeometryReader { geo in
                    // If we have a photo, show it with crop settings
                        if let url = sync.stats.photoURL {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .ignoresSafeArea()
                        } placeholder: {
                            LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
                                .ignoresSafeArea()
                        }
                    } else if let uiImage = partnerImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .ignoresSafeArea()
                    } else {
                        // Fallback Gradient
                        LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea()
                    }
                }

                // Foreground Content
                VStack {
                        // Top Bar: Photo Picker & Crop Button
                        HStack {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Image(systemName: "photo.badge.plus")
                                    .foregroundColor(.white)
                                    .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        
                            // Only show crop button if we actually have an image
                            if partnerImage != nil || sync.stats.photoURL != nil {
                                Button {
                                    isCropping.toggle()
                                } label: {
                                Image(systemName: "crop")
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }
                        Spacer()
                    }
                    .padding()

                    Spacer()

                    // Interactive Countdown Box
                    Button {
                        showDatePicker = true
                    } label: {
                        VStack(spacing: 15) {
                            Text("TOGETHER FOR")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(2)
                                .foregroundColor(.white.opacity(0.8))

                            HStack(spacing: 15) {
                        timeUnit(value: timeRemaining.day ?? 0, label: "days")
                        divider
                        timeUnit(value: timeRemaining.hour ?? 0, label: "hours")
                        divider
                        timeUnit(value: timeRemaining.minute ?? 0, label: "minutes")
                        divider
                        timeUnit(value: timeRemaining.second ?? 0, label: "seconds")
                    }
                }
                        .padding(.vertical, 25)
                        .padding(.horizontal, 20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle()) // Removes the default blue button tint
                    .padding(.bottom, 60)
                }
                
                // Crop Overlay (Appears on top when isCropping is true)
                if isCropping {
                    cropOverlayView
                }
            }
            .tabItem { Label("Home", systemImage: "heart.fill") }
            .onReceive(timer) { _ in updateTime() }
            .onAppear {
                anniversaryDate = sync.stats.anniversaryDate
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPairing = true
                    } label: {
                        Image(systemName: "person.2.wave.2")
                    }
                }
            }
            
            // Date Picker Sheet
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack {
                        DatePicker("Anniversary Date", selection: $anniversaryDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding()
                        Spacer()
                    }
                    .navigationTitle("Set Start Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        Button("Done") {
                            sync.updateStats(date: anniversaryDate)
                            showDatePicker = false
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showPairing) {
                PairingView()
                    .environmentObject(sync)
            }
            .onChange(of: sync.stats) { _, newStats in
                anniversaryDate = newStats.anniversaryDate
            }
            // Photo Picker Logic (iOS 17+ Syntax)
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        
                        // 1. Set the new image
                        partnerImage = uiImage
                        
                        // 2. BUG FIX: Reset crop settings for the new image
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                        
                        // 3. Upload to shared storage (no local save to Photos)
                        sync.updateStats(photoData: data)
                    }
                }
            }
            
            // --- TAB 2: JOURNAL ---
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.fill") }
        }
        .accentColor(.white)
        }
    }

    // --- Subview: The Manual Crop Interface ---
    var cropOverlayView: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack {
                Text("Drag to Move / Pinch to Zoom")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(.top, 50)
                
                Spacer()
                
                // The Image being manipulated
                ZStack {
                    if let uiImage = partnerImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: 300, height: 500) // Simulates phone screen ratio
                            .clipped()
                            .overlay(
                                Rectangle()
                                    .stroke(Color.white, lineWidth: 2) // White border to show crop area
                            )
                            // Gesture 1: Dragging
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in lastOffset = offset }
                            )
                            // Gesture 2: Zooming
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        // Limit zoom so it doesn't get too crazy (optional)
                                        scale = max(1.0, value)
                                    }
                            )
                    }
                }
                
                Spacer()
                
                Button("Done") {
                    isCropping = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.black)
                .padding(.bottom, 50)
            }
        }
    }

    // --- Helpers ---
    func updateTime() {
        let startDate = sync.stats.anniversaryDate
        let components = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: startDate, to: Date())
        timeRemaining = components
    }

    func timeUnit(value: Int, label: String) -> some View {
        VStack {
            Text(String(format: "%02d", value))
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .opacity(0.7)
        }
        .foregroundColor(.white)
    }

    var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1, height: 25)
    }
}
