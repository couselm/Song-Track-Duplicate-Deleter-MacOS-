import SwiftUI
import AppKit
import AVFoundation

struct SongMetadata:Identifiable {
    let id = UUID()
    let filename: String
    let title: String
    let artist: String
    let album: String
    let duration: String
    let format: String
    let size: String
    let samplerate: String
    let bitrate: String
}

struct ContentView: View {
    @State private var dirPath: String = ""
    @State private var deleteConfimed: Bool = false
    @State private var searchSubfolders = false
    @State private var showAlert = false
    @State private var songMetadataList: [SongMetadata] = []
    @State private var selection: Set<SongMetadata.ID> = []
    @State private var duplicates: [String] = []
    @State private var files: [String] = []
    @State private var songFileExtensions = ["mp3", "wav", "flac", "w4a"]
    @State private var sortOrder = [KeyPathComparator(\SongMetadata.title, order: .reverse)]
    @State private var trackcount = 0
    

    var body: some View {
        
        VStack {
            Text("🎵 Song Track Duplicate Deleter 🎶").bold().padding()
            Text("Music Folder Location").padding(.leading).frame(maxWidth: .infinity, alignment: .leading)
                
            HStack {
                TextField("Enter Music Directory Path:", text: $dirPath).padding(.leading)
                Button("📁 Browse") {
                    showFilePicker()
                }
                Toggle("Search Subfolders", isOn: $searchSubfolders)
                .padding(.trailing)
            }.padding(.bottom)
            
            HStack {
                Text("Track List").padding( .leading).frame(maxWidth: .infinity, alignment: .leading)
                Button("❌  Clear Track List") {
                    songMetadataList = []
                }.padding()
            }
            
            
            Table(songMetadataList, selection: $selection, sortOrder: $sortOrder) {
                        TableColumn("File", value: \.filename)
                        TableColumn("Title", value: \.title)
                        TableColumn("Artist", value: \.artist)
                        TableColumn("Album", value: \.album)
                        TableColumn("Duration", value: \.duration)
                        TableColumn("Format", value: \.format)
                        TableColumn("Size", value: \.size)
                        TableColumn("Sample Rate", value: \.samplerate)
                        TableColumn("Bitrate", value: \.bitrate)
            }.onChange(of: sortOrder) { newOrder in
                songMetadataList.sort(using: newOrder) }
            Text("Tracks Found: \(trackcount)").padding( .leading).frame(maxWidth: .infinity, alignment: .leading)
                
                    
            HStack {
                
                Button("🔎  Find Duplicate Tracks") {
                    findDuplicates()
                }.padding()
                
                Button("🗑️  Delete Duplicates") {
                    deleteDuplicates();
                }.padding()
                    .alert(isPresented: $deleteConfimed) {
                    Alert(
                        title: Text("Deletion Complete"),
                        message: Text("\(duplicates.count) Duplicate Tracks have been deleted."),
                        dismissButton: .default(Text("OK"))
                    )
            }
            
            }.padding(.trailing)
        }
    }
    

    // Functions
    func showFilePicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false

            panel.begin { response in
                if response == .OK {
                    if let url = panel.url {
                        dirPath = url.path
                        updateMetadataList()
                    }
                }
            }
        }
    }
    
    
    func searchDirectory(atPath path: String) {
        do {
            let fileManager  = FileManager.default
            let folderContents = try fileManager.contentsOfDirectory(atPath: path)
            for fileName in folderContents {
                let filePath = URL(fileURLWithPath: path + "/" + fileName)
                
                // Check if the item is a directory or a file
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: filePath.path, isDirectory: &isDirectory)
                
                if isDirectory.boolValue {
                    // If the item is a directory and the user wants to search subfolders, call the function recursively
                    if searchSubfolders {
                        searchDirectory(atPath: filePath.path)
                    }
                } else {
                    // Check is file is audio format
                    let fileExtension = filePath.pathExtension.lowercased()
                    
                    if songFileExtensions.contains(fileExtension) {
                        let metadata = extractMetadata(from: filePath, filename: fileName)
                        if let validMetadata = metadata {
                            songMetadataList.append(validMetadata)
                            trackcount += 1
                        }
                    }
                }
            }
        }
        catch {
            print("Error listing files: \(error.localizedDescription)")
        }
    }
    
    func updateMetadataList() {
        // Clear the previous list
        songMetadataList.removeAll()
        
        // Call the recursive function with the selected directory path
        searchDirectory(atPath: dirPath)
    }
        
    func extractMetadata(from filePath: URL, filename: String) -> SongMetadata? {
        do {
            let asset = AVAsset(url: filePath)
            let audioFile = try AVAudioFile(forReading: filePath)
            let metadata = asset.metadata
            let duration = getDuration(from: asset)
            let fileSize = calculateFileSize(forURL: filePath)
            let formattedFileSize = "\(round(fileSize * 100) / 100.0) MB"
            let formattedDuration = formatMinSec(durationInSeconds: duration)
            let bitrate = getAudioBitrate(fileSizeMB: fileSize, durationSec: duration)
            let samplerate = "\(getSampleRate(asset: asset)) Hz"
            
            let format = filePath.pathExtension.lowercased()

            var title = ""
            var artist = ""
            var album = ""
        
            

            for item in metadata {
                if let commonKey = item.commonKey, let value = item.value as? String {
                    switch commonKey {
                    case .commonKeyTitle:
                        title = value
                    case .commonKeyArtist:
                        artist = value
                    case .commonKeyAlbumName:
                        album = value
                    default:
                        break
                    }
                }
            }

            return SongMetadata(filename: filename, title: title, artist: artist, album: album, duration: formattedDuration, format: format, size: formattedFileSize, samplerate: samplerate , bitrate: bitrate)

        } catch {
            print("Error extracting metadata: \(error.localizedDescription)")
            return nil
        }
    }


    func calculateFileSize(forURL url: Any) -> Double {
        var fileURL: URL?
        var fileSize: Double = 0.0
        if (url is URL) || (url is String)
        {
            if (url is URL) {
                fileURL = url as? URL
            }
            else {
                fileURL = URL(fileURLWithPath: url as! String)
            }
            var fileSizeValue = 0.0
            try? fileSizeValue = (fileURL?.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).allValues.first?.value as! Double?)!
            if fileSizeValue > 0.0 {
                fileSize = (Double(fileSizeValue) / (1024 * 1024))
            }
        }
        return fileSize
    }


    
    func getDuration(from asset:AVAsset) -> Double {
        let duration = asset.duration
        let durationInSeconds = CMTimeGetSeconds(duration)
        return durationInSeconds
    }
    
    func formatMinSec(durationInSeconds: Double) -> String {
        let minutes = Int(durationInSeconds / 60)
                    let seconds = Int(durationInSeconds.truncatingRemainder(dividingBy: 60))
                    
                    return String(format: "%02d:%02d", minutes, seconds)
    }

    func getSampleRate(asset: AVAsset) -> Float {
        var frameRate: Float = 0
        let tracks = asset.tracks
        // Loop through the tracks
        for track in tracks {
            // Check if the track is an audio track
            if track.mediaType == .audio {
                // Get the frame rate of the track
                frameRate = track.nominalFrameRate
                // Return the frame rate
                return frameRate
            }
        }
        // Return zero if there are no audio tracks
        return frameRate
    }

    
    func getAudioBitrate(fileSizeMB: Double, durationSec: Double) -> String {
            do {
                // convert MB to kilobits
                var kbpsFinal:Int
                let kilobits = fileSizeMB * 8000
                let kbps = kilobits / durationSec
                let kbpsRounded = Int(kbps)
                switch kbpsRounded {
                case 1...40: kbpsFinal = 32
                case 41...70: kbpsFinal = 64
                case 71...109: kbpsFinal = 96
                case 110...150: kbpsFinal = 128
                case 150...215: kbpsFinal = 192
                case 216...270: kbpsFinal = 256
                case 271...355: kbpsFinal = 320
                    
                default:
                    kbpsFinal = kbpsRounded
                }
                return "\(kbpsFinal) kbps"
            }
            catch {
                print("Error: \(error.localizedDescription)")
                return "0 kbps"
            }
            
        }

    

    func findDuplicates() {
        do {
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(atPath: dirPath)
                
                // Print the list of files in the selected directory
                print("Files in \(dirPath):")
                for file in contents {
                    print(file)
                }
                
                // Implement logic to find duplicates and update the 'duplicates' array
                // ...

                // For testing, let's simulate finding duplicates and updating the count
                duplicates = ["Track1", "Track2", "Track3"]

                
            } catch {
                print("Error listing files: \(error.localizedDescription)")
            }
    }
    
    func deleteDuplicates() {
        // Set deleteConfirmed to true after finding duplicates
        deleteConfimed = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
