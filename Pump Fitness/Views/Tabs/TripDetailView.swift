import SwiftUI
import MapKit
import PhotosUI
import TipKit

@available(iOS 17.0, *)
struct TripDetailView: View {
    @State var trip: Trip
    @ObservedObject var recorder: TripRecorderManager
    
    @State private var selectedPoint: TripPoint?
    @State private var position: MapCameraPosition

    init(trip: Trip, recorder: TripRecorderManager) {
        self._trip = State(initialValue: trip)
        self.recorder = recorder
        
        if trip.points.isEmpty {
            self._position = State(initialValue: .userLocation(fallback: .automatic))
        } else {
            self._position = State(initialValue: .automatic)
        }
    }
    
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismissSelf

    @State private var showingRenameAlert = false
    @State private var newName = ""
    
    private var displayColor: Color {
        if themeManager.selectedTheme == .multiColour { return .blue }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }
    
    var body: some View {
        NavigationStack {
            Map(position: $position) {
                if !trip.points.isEmpty {
                    MapPolyline(coordinates: trip.points.map { $0.coordinate })
                        .stroke(.blue, lineWidth: 5)
                }
                
                ForEach(trip.points) { point in
                    Annotation(point.title ?? "", coordinate: point.coordinate) {
                        TripPointAnnotationView(point: point, displayColor: displayColor)
                        .onTapGesture {
                            selectedPoint = point
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if trip.points.count < 3 {
                    TipView(TravelTips.JourneyRecordingGuidanceTip())
                        .padding()
                        .offset(y: -20)
                }
            }
            .onAppear {
                if trip.points.isEmpty {
                    position = .userLocation(fallback: .automatic)
                }
            }
            .navigationTitle(trip.displayTitle(in: recorder.pastTrips))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismissSelf()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .fontWeight(.semibold)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            newName = trip.name ?? ""
                            showingRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            recorder.deleteTrip(trip)
                            dismissSelf()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(displayColor)
                    }
                }
            }
            .alert("Rename Journey", isPresented: $showingRenameAlert) {
                TextField("Trip Title (e.g. Paris 2024)", text: $newName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    trip.name = newName
                    recorder.saveTrip(trip)
                }
            }
            .sheet(item: $selectedPoint) { point in
                TripPointEditorSheet(point: point) { updatedPoint in
                    recorder.updatePoint(updatedPoint, in: trip)
                    // Update local Copy to reflect changes immediately in UI
                    if let idx = trip.points.firstIndex(where: { $0.id == updatedPoint.id }) {
                        trip.points[idx] = updatedPoint
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

struct TripPointEditorSheet: View {
    @State var point: TripPoint
    var onSave: (TripPoint) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isProcessingImages = false
    @State private var previewImageEntry: IdentifiableData?

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: Binding(
                        get: { point.title ?? "" },
                        set: { point.title = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section("Photos") {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 0, matching: .images) {
                        if isProcessingImages {
                            HStack {
                                Text("Processing Photos...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                        }
                    }
                    .disabled(isProcessingImages)
                    .onChange(of: selectedPhotos) { _, newItems in
                        guard !newItems.isEmpty else { return }
                        isProcessingImages = true
                        Task {
                            var newImages: [Data] = []
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    newImages.append(data)
                                }
                            }
                            await MainActor.run {
                                var current = point.imagesData ?? []
                                current.append(contentsOf: newImages)
                                point.imagesData = current
                                selectedPhotos = []
                                isProcessingImages = false
                            }
                        }
                    }

                    if let images = point.imagesData, !images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                                    ZStack(alignment: .topTrailing) {
                                        if let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .onTapGesture {
                                                    previewImageEntry = IdentifiableData(data: data, index: index)
                                                }
                                                .overlay(alignment: .bottomTrailing) {
                                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .padding(6)
                                                        .background(Color.black.opacity(0.45))
                                                        .clipShape(Circle())
                                                        .padding(6)
                                                }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 5)
                            .padding(.trailing, 5)
                        }
                        .frame(height: 90)
                        
                        Button("Clear All", role: .destructive) {
                            point.imagesData = []
                        }
                    }
                }
            }
            .navigationTitle("Edit Point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(point)
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(item: $previewImageEntry) { item in
            ZStack {
                Color.black.ignoresSafeArea()
                if let uiImage = UIImage(data: item.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
                
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            previewImageEntry = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .opacity(0.95)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 18)
                        .padding(.top, 44)
                    }
                    Spacer()
                    
                    Button {
                        if point.imagesData?.indices.contains(item.index) == true {
                             point.imagesData?.remove(at: item.index)
                             previewImageEntry = nil
                        }
                    } label: {
                        Text("Delete Image")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}

struct IdentifiableData: Identifiable {
    let id = UUID()
    let data: Data
    let index: Int
}

struct TripPointAnnotationView: View {
    let point: TripPoint
    let displayColor: Color
    
    var body: some View {
        let hasImages = !(point.imagesData ?? []).isEmpty
        let imageCount = point.imagesData?.count ?? 0
        let size: CGFloat = hasImages ? 45 : 35
        let cornerRadius: CGFloat = hasImages ? 12 : 10
        
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(displayColor)
                    .frame(width: size, height: size)
                
                if let firstData = point.imagesData?.first, let uiImage = UIImage(data: firstData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
                
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: size, height: size)
            }

            if imageCount > 1 {
                Text("\(imageCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 8, y: -8)
                    .shadow(radius: 2)
            }
        }
    }
}
