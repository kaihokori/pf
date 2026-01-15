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

    @State private var isScanning = false
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TextField("Title", text: Binding(
                        get: { point.title ?? "" },
                        set: { point.title = $0.isEmpty ? nil : $0 }
                    ))
                    .textInputAutocapitalization(.words)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 16))
                    
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Auto-Match Photos")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Intelligently find photos from your library taken at this location and time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if isScanning {
                            ProgressView()
                                .padding(.top, 8)
                        } else {
                            Button {
                                scanForMatchingPhotos()
                            } label: {
                                Text("Start Scan")
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                            .disabled(isProcessingImages)
                        }
                        
                        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 0, matching: .images) {
                            if isProcessingImages {
                                Text("Processing...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Manually Select Photos")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .disabled(isProcessingImages || isScanning)
                        .padding(.top, 8)
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
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .glassEffect(in: .rect(cornerRadius: 16))

                    if let images = point.imagesData, !images.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Attached Photos")
                                    .font(.headline)
                                Spacer()
                                Text("\(images.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1), in: Capsule())
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                                        if let uiImage = UIImage(data: data) {
                                            Button {
                                                previewImageEntry = IdentifiableData(data: data, index: index)
                                            } label: {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                                                    )
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            Button(role: .destructive) {
                                point.imagesData = []
                            } label: {
                                Text("Clear All Photos")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.regular)
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                        }
                        .padding(.vertical)
                        .glassEffect(in: .rect(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
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
            .alert("Photos Access Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                         UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please allow access to your photo library to auto-match photos found around this time and location.")
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

    func scanForMatchingPhotos() {
        isScanning = true
        
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            
            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    isScanning = false
                    showingPermissionAlert = true
                }
                return
            }
            
            let centerDate = point.timestamp
            // Search window: +/- 2 hours to be safe
            let start = centerDate.addingTimeInterval(-7200)
            let end = centerDate.addingTimeInterval(7200)
            
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", start as NSDate, end as NSDate)
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            
            let assets = PHAsset.fetchAssets(with: .image, options: options)
            var matchedData: [Data] = []
            
            let manager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isNetworkAccessAllowed = true
            requestOptions.isSynchronous = true 
            requestOptions.deliveryMode = .highQualityFormat
            
            assets.enumerateObjects { asset, _, stop in
                // Check location if available
                if let location = asset.location {
                    let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
                    let distance = location.distance(from: pointLoc)
                    // 2.5km parameter
                    if distance > 2500 {
                        return // Skip this photo
                    }
                }
                
                // Fetch Data
                manager.requestImageDataAndOrientation(for: asset, options: requestOptions) { data, _, _, _ in
                    if let data = data {
                        matchedData.append(data)
                    }
                }
                
                // Limit to 20 automatch photos
                if matchedData.count >= 20 {
                    stop.pointee = true
                }
            }
            
            await MainActor.run {
                var current = point.imagesData ?? []
                current.append(contentsOf: matchedData)
                point.imagesData = current
                isScanning = false
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
