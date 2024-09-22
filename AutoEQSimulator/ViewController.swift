//
//  ViewController.swift
//  AutoEQSimulator
//
//  Created by Anting Hong on 22/09/2024.
//

import Cocoa
import AVFoundation

struct EQPoint {
    let frequency: Double
    let gain: Double
    let qFactor: Double
}


class ViewController:NSViewController, NSComboBoxDataSource, NSComboBoxDelegate {
    
    
    @IBOutlet weak var myHeadphoneModelComboBox: NSComboBox!
    @IBOutlet weak var targetHeadphoneModelComboBox: NSComboBox!
    @IBOutlet weak var statusLabel: NSTextField!
    
    var headphoneModels: [String] = []
    
    let audioEngine = AVAudioEngine()
    var eqNode: AVAudioUnitEQ!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set data source and delegate
        myHeadphoneModelComboBox.usesDataSource = true
        myHeadphoneModelComboBox.dataSource = self
        myHeadphoneModelComboBox.delegate = self
        
        targetHeadphoneModelComboBox.usesDataSource = true
        targetHeadphoneModelComboBox.dataSource = self
        targetHeadphoneModelComboBox.delegate = self
        
        loadHeadphoneModels()
    }
    
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        print("numberOfItems called, count: \(headphoneModels.count)")
        return headphoneModels.count
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        print("objectValueForItemAt called for index \(index)")
        return headphoneModels[index]
    }
    
    func comboBox(_ comboBox: NSComboBox, completedString string: String) -> String? {
        print("completedString called with \(string)")
        return headphoneModels.first(where: { $0.lowercased().hasPrefix(string.lowercased()) })
    }
    
    
    @IBAction func applyButtonClicked(_ sender: Any) {
        applyEQSettings()
    }
    
    
    func loadHeadphoneModels() {
        headphoneModels = []
        
        // Access the 'results' folder within the app bundle
        guard let resultsURL = Bundle.main.resourceURL?.appendingPathComponent("results") else {
            print("Results folder not found")
            return
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: resultsURL, includingPropertiesForKeys: nil, options: [])
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "txt" {
                    let fileName = fileURL.deletingPathExtension().lastPathComponent
                    // Extract model name from the file name
                    let modelName = fileName.replacingOccurrences(of: " ParametricEQ", with: "")
                    headphoneModels.append(modelName)
                }
            }
            
            print("Loaded headphone models: \(headphoneModels)")
            
            DispatchQueue.main.async {
                self.myHeadphoneModelComboBox.reloadData()
                self.targetHeadphoneModelComboBox.reloadData()
            }
            
        } catch {
            print("Error loading headphone models: \(error)")
        }
    }
    
    
    
    func loadEQData(for modelName: String) -> [EQPoint]? {
        let fileName = "\(modelName) ParametricEQ"
        
        // Access the 'results' folder within the app bundle
        guard let resultsURL = Bundle.main.resourceURL?.appendingPathComponent("results") else {
            print("Results folder not found")
            return nil
        }
        
        let fileURL = resultsURL.appendingPathComponent("\(fileName).txt")
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            var eqPoints: [EQPoint] = []
            
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if line.isEmpty || line.starts(with: "#") {
                    continue
                }
                
                let components = line.split(separator: ",")
                if components.count >= 3,
                   let frequency = Double(components[0].trimmingCharacters(in: .whitespaces)),
                   let gain = Double(components[1].trimmingCharacters(in: .whitespaces)),
                   let qFactor = Double(components[2].trimmingCharacters(in: .whitespaces)) {
                    
                    let eqPoint = EQPoint(frequency: frequency, gain: gain, qFactor: qFactor)
                    eqPoints.append(eqPoint)
                }
            }
            
            return eqPoints
        } catch {
            print("Error reading EQ file: \(error)")
            return nil
        }
    }
    
    
    
    func invertEQData(_ eqData: [EQPoint]) -> [EQPoint] {
        return eqData.map { EQPoint(frequency: $0.frequency, gain: -$0.gain, qFactor: $0.qFactor) }
    }
    
    func combineEQData(_ eqData1: [EQPoint], _ eqData2: [EQPoint]) -> [EQPoint] {
        var combinedEQ: [EQPoint] = []
        for i in 0..<min(eqData1.count, eqData2.count) {
            let freq = eqData1[i].frequency
            let gain = eqData1[i].gain + eqData2[i].gain
            let qFactor = (eqData1[i].qFactor + eqData2[i].qFactor) / 2
            combinedEQ.append(EQPoint(frequency: freq, gain: gain, qFactor: qFactor))
        }
        return combinedEQ
    }
    
    func configureEQNode(eqNode: AVAudioUnitEQ, with eqData: [EQPoint]) {
        for (index, eqPoint) in eqData.enumerated() {
            if index >= eqNode.bands.count {
                break
            }
            let band = eqNode.bands[index]
            band.filterType = .parametric
            band.frequency = Float(eqPoint.frequency)
            band.gain = Float(eqPoint.gain)
            band.bandwidth = Float(1.0 / eqPoint.qFactor)
            band.bypass = false
        }
    }
    
    func setupAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }
        
        // Do not re-initialize eqNode here
        // eqNode = AVAudioUnitEQ(numberOfBands: 10)
        
        audioEngine.attach(eqNode)
        
        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode
        let format = outputNode.outputFormat(forBus: 0)
        
        audioEngine.connect(mainMixer, to: eqNode, format: format)
        audioEngine.connect(eqNode, to: outputNode, format: format)
        
        // Remove the installTap if not needed
        // outputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, time) in
        //     // Process audio buffer if needed
        // }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("Audio engine started")
        } catch {
            print("Error starting audio engine: \(error)")
            statusLabel.stringValue = "Error starting audio engine: \(error.localizedDescription)"
        }
    }
    
    
    
    func applyEQSettings() {
        let myModel = myHeadphoneModelComboBox.stringValue
        let targetModel = targetHeadphoneModelComboBox.stringValue
        
        guard let myEQData = loadEQData(for: myModel) else {
            statusLabel.stringValue = "Your headphone model not found."
            return
        }
        
        var combinedEQData = myEQData
        
        if !targetModel.isEmpty {
            guard let targetEQData = loadEQData(for: targetModel) else {
                statusLabel.stringValue = "Target headphone model not found."
                return
            }
            let invertedTargetEQData = invertEQData(targetEQData)
            combinedEQData = combineEQData(myEQData, invertedTargetEQData)
        }
        
        // Initialize eqNode with the correct number of bands
        eqNode = AVAudioUnitEQ(numberOfBands: combinedEQData.count)
        
        // Configure the EQ node with the combined EQ data
        configureEQNode(eqNode: eqNode, with: combinedEQData)
        
        // Set up and start the audio engine
        setupAudioEngine()
        
        statusLabel.stringValue = "EQ settings applied successfully."
    }
    
    @IBAction func stopEQButtonClicked(_ sender: Any) {
        // Stop and reset the audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
            print("Audio engine stopped")
        }

        // Optionally, reset eqNode
        eqNode = nil

        // Update status label
        statusLabel.stringValue = "EQ settings have been stopped."
    }

}
