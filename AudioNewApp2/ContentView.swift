import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    
    var body: some View {
        VStack {
            Button("Start Recording") {
                audioRecorder.startRecording()
            }
            .padding()
            .disabled(audioRecorder.isRecording)
            
            Button("Stop Recording") {
                audioRecorder.stopRecording()
            }
            .padding()
            .disabled(!audioRecorder.isRecording)
            
            Button("Play Recording") {
                audioRecorder.playRecording()
            }
            .padding()
            .disabled(!audioRecorder.recordingExists)
        }
    }
}
