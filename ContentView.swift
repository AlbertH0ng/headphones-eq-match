import SwiftUI
import AVFoundation
import PythonKit

struct ContentView: View {
    @State private var inputHeadphones = ""
    @State private var outputHeadphones = ""
    @State private var eqDifference: [[String: Double]]?
    @State private var engine: AVAudioEngine?
    @State private var eqNodes: [AVAudioUnitEQ] = []
    
    var body: some View {
        VStack {
            TextField("Input Headphones", text: $inputHeadphones)
            TextField("Output Headphones", text: $outputHeadphones)
            Button("Calculate EQ") {
                calculateEQ()
            }
            if let eqDifference = eqDifference {
                Text("EQ Difference:")
                List(eqDifference, id: \.self) { eq in
                    Text("Freq: \(eq["freq"] ?? 0), Q: \(eq["q"] ?? 0), Gain: \(eq["gain"] ?? 0)")
                }
                Button("Apply EQ") {
                    applyEQ()
                }
                Button("Stop EQ") {
                    stopEQ()
                }
            }
        }
        .padding()
    }
    
    func calculateEQ() {
        let python = Python.import("eqmanager")
        let result = python.calculate_eq_difference(inputHeadphones, outputHeadphones)
        if let jsonString = String(result) {
            eqDifference = try? JSONDecoder().decode([[String: Double]].self, from: Data(jsonString.utf8))
        }
    }
    
    func applyEQ() {
        guard let eqDifference = eqDifference else { return }
        
        engine = AVAudioEngine()
        guard let engine = engine else { return }
        
        let inputNode = engine.inputNode
        let mainMixer = engine.mainMixerNode
        
        // Create an EQ node for each band
        eqNodes = eqDifference.map { band in
            let eq = AVAudioUnitEQ(numberOfBands: 1)
            let eqBand = eq.bands[0]
            eqBand.filterType = .parametric
            eqBand.frequency = band["freq"] ?? 0
            eqBand.bandwidth = band["q"] ?? 0
            eqBand.gain = band["gain"] ?? 0
            return eq
        }
        
        // Connect nodes
        engine.attach(inputNode)
        var previousNode: AVAudioNode = inputNode
        for eqNode in eqNodes {
            engine.attach(eqNode)
            engine.connect(previousNode, to: eqNode, format: nil)
            previousNode = eqNode
        }
        engine.connect(previousNode, to: mainMixer, format: nil)
        
        // Start the engine
        do {
            try engine.start()
        } catch {
            print("Could not start audio engine: \(error)")
        }
    }
    
    func stopEQ() {
        engine?.stop()
        engine = nil
        eqNodes.removeAll()
    }
}