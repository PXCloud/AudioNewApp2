import SwiftUI
import AVFoundation

@main
struct AudioNewApp: App {
    @StateObject private var audioRecorder = AudioRecorder()
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(audioRecorder)
        }
    }
}

class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    
    @Published var isRecording = false
    @Published var recordingExists = false
    
    var webSocket: URLSessionWebSocketTask?
    
    override init() {
        super.init()
        print("AudioRecorder initialized")
        setupRecorder()
        startListeningForCommands()
    }
    
    func startListeningForCommands() {
        print("Starting to listen for commands")
        let url = URL(string: "ws://localhost:3002")!
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        print("WebSocket connection resumed")
        
        // Send a ping message to check the connection
        webSocket?.sendPing { error in
            if let error = error {
                print("WebSocket ping error: \(error)")
            } else {
                print("WebSocket ping successful")
            }
        }
    }
    
    func sendMessage(_ message: String) {
        print("Sending message: \(message)")
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocket?.send(message) { error in
            if let error = error {
                print("WebSocket sending error: \(error)")
            } else {
                print("Message sent successfully")
            }
        }
    }
    
    func setupRecorder() {
        print("Setting up recorder")
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
            recordingExists = FileManager.default.fileExists(atPath: audioFilename.path)
            print("Recorder setup completed")
        } catch {
            print("Failed to set up recorder: \(error)")
        }
    }
    
    func startRecording() {
        print("Starting recording")
        audioRecorder?.record()
        isRecording = true
        recordingExists = false
        print("Recording started")
    }
    
    func stopRecording() {
        print("Stopping recording")
        audioRecorder?.stop()
        isRecording = false
        recordingExists = true
        print("Recording stopped")
        
        uploadAudioFile()
    }
    
    func uploadAudioFile() {
        print("Uploading audio file")
        guard let audioRecorder = audioRecorder else {
            print("Audio recorder is nil")
            return
        }
        let audioFilename = audioRecorder.url
        
        // Create a URLRequest to upload the audio file to the server
        var request = URLRequest(url: URL(string: "http://localhost:3002/uploadAudio")!)
        request.httpMethod = "POST"
        
        // Set up the request body with the audio file data
        let boundary = UUID().uuidString
        let contentType = "multipart/form-data; boundary=\(boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(try! Data(contentsOf: audioFilename))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Send the request to upload the audio file
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error uploading audio file: \(error)")
                return
            }
            
            // Handle the response from the server if needed
            print("Audio file uploaded successfully")
        }
        task.resume()
    }
    
    func playRecording() {
        print("Playing recording")
        guard let audioRecorder = audioRecorder else {
            print("Audio recorder is nil")
            return
        }
        let audioFilename = audioRecorder.url
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFilename)
            audioPlayer?.play()
            print("Playback started")
        } catch {
            print("Playback failed: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension AudioRecorder: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocolName: String?) {
        print("WebSocket connected with protocol: \(protocolName ?? "none")")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket disconnected with code: \(closeCode.rawValue), reason: \(String(data: reason ?? Data(), encoding: .utf8) ?? "none")")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("WebSocket task completed with error: \(error)")
        } else {
            print("WebSocket task completed successfully")
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didReceiveMessage message: URLSessionWebSocketTask.Message) {
        print("Received message from WebSocket")
        switch message {
        case .string(let text):
            print("Received text message: \(text)")
            if text == "startRecording" {
                print("Received startRecording command")
                DispatchQueue.main.async {
                    self.startRecording()
                }
            } else if text == "stopRecording" {
                print("Received stopRecording command")
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            } else {
                print("Unknown command received: \(text)")
            }
        case .data(let data):
            print("Received binary message: \(data)")
        @unknown default:
            break
        }
    }
}
