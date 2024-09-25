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
    let filterType: String
}

// Define AudioDevice struct
struct AudioDevice {
    let id: AudioDeviceID
    let name: String
}



class ViewController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSControlTextEditingDelegate {
    
    @IBOutlet weak var myHeadphoneModelComboBox: NSComboBox!
    @IBOutlet weak var targetHeadphoneModelComboBox: NSComboBox!
    @IBOutlet weak var outputDeviceComboBox: NSComboBox!
    @IBOutlet weak var statusLabel: NSTextField!
    
    let audioEngine = AVAudioEngine()
    var headphoneModels: [String] = []
    var myFilteredHeadphoneModels: [String] = []
    var targetFilteredHeadphoneModels: [String] = []
    
    var eqNode: AVAudioUnitEQ!
    var outputDevices: [AudioDevice] = []
    var selectedOutputDeviceID: AudioDeviceID?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set data source and delegate
        myHeadphoneModelComboBox.usesDataSource = true
        myHeadphoneModelComboBox.dataSource = self
        myHeadphoneModelComboBox.delegate = self
        myHeadphoneModelComboBox.completes = false // Disable default auto-completion
        
        targetHeadphoneModelComboBox.usesDataSource = true
        targetHeadphoneModelComboBox.dataSource = self
        targetHeadphoneModelComboBox.delegate = self
        targetHeadphoneModelComboBox.completes = false // Disable default auto-completion
        
        loadHeadphoneModels()
        getAvailableOutputDevices()
        outputDeviceComboBox.delegate = self
        outputDeviceComboBox.dataSource = self // Ensure dataSource is set
        

    }
    
    // MARK: - NSComboBoxDataSource Methods
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        if comboBox == myHeadphoneModelComboBox {
            return myFilteredHeadphoneModels.count
        } else if comboBox == targetHeadphoneModelComboBox {
            return targetFilteredHeadphoneModels.count
        } else if comboBox == outputDeviceComboBox {
            return outputDevices.count
        }
        return 0
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        if comboBox == myHeadphoneModelComboBox {
            return myFilteredHeadphoneModels[index]
        } else if comboBox == targetHeadphoneModelComboBox {
            return targetFilteredHeadphoneModels[index]
        } else if comboBox == outputDeviceComboBox {
            return outputDevices[index].name
        }
        return nil
    }
    
    // MARK: - NSControlTextEditingDelegate Method
    
    func controlTextDidChange(_ notification: Notification) {
        guard let comboBox = notification.object as? NSComboBox else { return }
        
        let searchString = comboBox.stringValue.lowercased()
        
        if comboBox == myHeadphoneModelComboBox {
            if searchString.isEmpty {
                myFilteredHeadphoneModels = headphoneModels
            } else {
                myFilteredHeadphoneModels = headphoneModels.filter { $0.lowercased().contains(searchString) }
            }
        } else if comboBox == targetHeadphoneModelComboBox {
            if searchString.isEmpty {
                targetFilteredHeadphoneModels = headphoneModels
            } else {
                targetFilteredHeadphoneModels = headphoneModels.filter { $0.lowercased().contains(searchString) }
            }
        }
        
        comboBox.reloadData()
    }
    
    // MARK: - NSComboBoxDelegate Methods
    
    func comboBoxWillPopUp(_ notification: Notification) {
        guard let comboBox = notification.object as? NSComboBox else { return }
        
        let searchString = comboBox.stringValue.lowercased()
        
        if comboBox == myHeadphoneModelComboBox {
            if searchString.isEmpty {
                myFilteredHeadphoneModels = headphoneModels
            } else {
                myFilteredHeadphoneModels = headphoneModels.filter { $0.lowercased().contains(searchString) }
            }
        } else if comboBox == targetHeadphoneModelComboBox {
            if searchString.isEmpty {
                targetFilteredHeadphoneModels = headphoneModels
            } else {
                targetFilteredHeadphoneModels = headphoneModels.filter { $0.lowercased().contains(searchString) }
            }
        }
        
        comboBox.reloadData()
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let comboBox = notification.object as? NSComboBox else { return }
        
        if comboBox == myHeadphoneModelComboBox {
            let selectedIndex = comboBox.indexOfSelectedItem
            if selectedIndex >= 0 && selectedIndex < myFilteredHeadphoneModels.count {
                let selectedModel = myFilteredHeadphoneModels[selectedIndex]
                comboBox.stringValue = selectedModel
            }
        } else if comboBox == targetHeadphoneModelComboBox {
            let selectedIndex = comboBox.indexOfSelectedItem
            if selectedIndex >= 0 && selectedIndex < targetFilteredHeadphoneModels.count {
                let selectedModel = targetFilteredHeadphoneModels[selectedIndex]
                comboBox.stringValue = selectedModel
            }
        } else if comboBox == outputDeviceComboBox {
            let selectedIndex = comboBox.indexOfSelectedItem
            if selectedIndex >= 0 && selectedIndex < outputDevices.count {
                let selectedDevice = outputDevices[selectedIndex]
                print("Selected output device: \(selectedDevice.name)")
                // Update the output device ID
                selectedOutputDeviceID = selectedDevice.id
            }
        }
    }
    
    // MARK: - Actions
    
    @IBAction func applyButtonClicked(_ sender: Any) {
        applyEQSettings()
    }
    
    @IBAction func stopEQButtonClicked(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }
        statusLabel.stringValue = "EQ settings have been stopped."
    }

    
    // MARK: - Data Loading
    
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
            
            // print("Loaded headphone models: \(headphoneModels)") Too many models
            
            // Initialize filtered arrays
            myFilteredHeadphoneModels = headphoneModels
            targetFilteredHeadphoneModels = headphoneModels
            
            DispatchQueue.main.async {
                self.myHeadphoneModelComboBox.reloadData()
                self.targetHeadphoneModelComboBox.reloadData()
            }
            
        } catch {
            print("Error loading headphone models: \(error)")
        }
    }
    
    func getAvailableOutputDevices() {
        var devicesPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesPropertyAddress,
            0,
            nil,
            &propertySize
        )
        
        if status != noErr {
            print("Error getting device data size: \(status)")
            return
        }
        
        let numDevices = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: numDevices)
        propertySize = UInt32(numDevices * MemoryLayout<AudioDeviceID>.size)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesPropertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        if status != noErr {
            print("Error getting device data: \(status)")
            return
        }
        
        outputDevices = []
        
        for deviceID in deviceIDs {
            var deviceName: CFString = "" as CFString
            var propertySize = UInt32(MemoryLayout<CFString>.size)
            var namePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            status = AudioObjectGetPropertyData(
                deviceID,
                &namePropertyAddress,
                0,
                nil,
                &propertySize,
                &deviceName
            )
            
            if status != noErr {
                print("Error getting device name: \(status)")
                continue
            }
            
            // Check if the device is an output device
            var outputChannels: UInt32 = 0
            propertySize = UInt32(MemoryLayout<UInt32>.size)
            var channelsPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            status = AudioObjectGetPropertyDataSize(
                deviceID,
                &channelsPropertyAddress,
                0,
                nil,
                &propertySize
            )
            
            if status != noErr {
                continue
            }
            
            let audioBufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propertySize))
            defer {
                audioBufferList.deallocate()
            }
            
            status = AudioObjectGetPropertyData(
                deviceID,
                &channelsPropertyAddress,
                0,
                nil,
                &propertySize,
                audioBufferList
            )
            
            if status != noErr {
                continue
            }
            
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in buffers {
                outputChannels += buffer.mNumberChannels
            }
            
            if outputChannels > 0 {
                let device = AudioDevice(id: deviceID, name: deviceName as String)
                outputDevices.append(device)
            }
        }
        
        DispatchQueue.main.async {
            self.outputDeviceComboBox.removeAllItems()
            for device in self.outputDevices {
                self.outputDeviceComboBox.addItem(withObjectValue: device.name)
            }
        }
    }
    
    // MARK: - EQ Processing Functions
    
    func loadEQData(for modelName: String) -> ([EQPoint], Double)? {
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
            var preampValue: Double = 0.0
            
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if line.isEmpty || line.starts(with: "#") {
                    continue
                }
                
                if line.starts(with: "Preamp:") {
                    // Parse Preamp line
                    let pattern = #"Preamp:\s*(-?\d+\.?\d*)\s*dB"#
                    let regex = try NSRegularExpression(pattern: pattern)
                    let nsLine = line as NSString
                    if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                        if let preampGain = Double(nsLine.substring(with: match.range(at: 1))) {
                            preampValue = preampGain
                        }
                    }
                    continue
                }
                
                // Parse Filter lines
                let pattern = #"Filter \d+: ON (\w+) Fc (\d+\.?\d*) Hz Gain (-?\d+\.?\d*) dB Q (\d+\.?\d*)$"#
                let regex = try NSRegularExpression(pattern: pattern)
                let nsLine = line as NSString
                if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let filterType = nsLine.substring(with: match.range(at: 1))
                    if let frequency = Double(nsLine.substring(with: match.range(at: 2))),
                       let gain = Double(nsLine.substring(with: match.range(at: 3))),
                       let qFactor = Double(nsLine.substring(with: match.range(at: 4))) {
                        let eqPoint = EQPoint(frequency: frequency, gain: gain, qFactor: qFactor, filterType: filterType)
                        eqPoints.append(eqPoint)
                    }
                } else {
                    print("Failed to parse line: \(line)")
                }
            }
            
            return (eqPoints, preampValue)
        } catch {
            print("Error reading EQ file: \(error)")
            return nil
        }
    }
    
    func invertEQData(_ eqData: [EQPoint]) -> [EQPoint] {
        return eqData.map { EQPoint(frequency: $0.frequency, gain: -$0.gain, qFactor: $0.qFactor, filterType: $0.filterType) }
    }
    
    func combineEQData(_ eqData1: [EQPoint], _ eqData2: [EQPoint]) -> [EQPoint] {
        var combinedEQ: [EQPoint] = []
        for i in 0..<min(eqData1.count, eqData2.count) {
            let freq = eqData1[i].frequency
            let gain = eqData1[i].gain + eqData2[i].gain
            let qFactor = (eqData1[i].qFactor + eqData2[i].qFactor) / 2
            let filterType = eqData1[i].filterType // Or decide how to combine filter types
            combinedEQ.append(EQPoint(frequency: freq, gain: gain, qFactor: qFactor, filterType: filterType))
        }
        return combinedEQ
    }
    
    func createOutputAudioUnit(completion: @escaping (AVAudioUnit?) -> Void) {
        let outputComponentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        AVAudioUnit.instantiate(with: outputComponentDescription, options: []) { (audioUnit, error) in
            if let error = error {
                print("Error instantiating custom output audio unit: \(error)")
                completion(nil)
                return
            }
            completion(audioUnit)
        }
    }

    
    func setOutputDevice(for audioUnit: AVAudioUnit, deviceID: AudioDeviceID) -> Bool {
        var deviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit.audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            print("Error setting output device: \(status)")
            return false
        }
        return true
    }



    
    func configureEQNode(eqNode: AVAudioUnitEQ, with eqData: [EQPoint], preampValue: Double) {
        for (index, eqPoint) in eqData.enumerated() {
            if index >= eqNode.bands.count {
                break
            }
            let band = eqNode.bands[index]

            // Set filter type based on eqPoint.filterType
            switch eqPoint.filterType {
            case "PK":
                band.filterType = .parametric
            case "LSC":
                band.filterType = .lowShelf
            case "HSC":
                band.filterType = .highShelf
            default:
                band.filterType = .parametric
            }

            band.frequency = Float(eqPoint.frequency)
            band.gain = Float(eqPoint.gain)

            // Set bandwidth in octaves
            band.bandwidth = Float(1.0 / eqPoint.qFactor)

            band.bypass = false
        }

        // Apply preamp value if needed
        eqNode.globalGain = Float(preampValue)
    }

    
    func applyEQSettings() {
        let myModel = myHeadphoneModelComboBox.stringValue
        let targetModel = targetHeadphoneModelComboBox.stringValue

        guard let (myEQData, myPreamp) = loadEQData(for: myModel) else {
            statusLabel.stringValue = "Your headphone model not found."
            return
        }

        var combinedEQData = myEQData
        var combinedPreamp = myPreamp

        if !targetModel.isEmpty {
            guard let (targetEQData, targetPreamp) = loadEQData(for: targetModel) else {
                statusLabel.stringValue = "Target headphone model not found."
                return
            }
            let invertedTargetEQData = invertEQData(targetEQData)
            combinedEQData = combineEQData(myEQData, invertedTargetEQData)
            combinedPreamp += targetPreamp
        }

        // Stop and reset the audio engine if it's already running
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }

        // Remove existing nodes
        for node in audioEngine.attachedNodes {
            audioEngine.detach(node)
        }

        // Create and configure the EQ node
        eqNode = AVAudioUnitEQ(numberOfBands: combinedEQData.count)
        configureEQNode(eqNode: eqNode, with: combinedEQData, preampValue: combinedPreamp)
        audioEngine.attach(eqNode)

        // Create the custom output audio unit
        createOutputAudioUnit { [weak self] (outputAudioUnit) in
            guard let self = self, let outputAudioUnit = outputAudioUnit else {
                self?.statusLabel.stringValue = "Error creating custom output audio unit."
                return
            }

            // Set the output device
            if let selectedDeviceID = self.selectedOutputDeviceID {
                if !self.setOutputDevice(for: outputAudioUnit, deviceID: selectedDeviceID) {
                    self.statusLabel.stringValue = "Error setting output device."
                    return
                }
            } else {
                self.statusLabel.stringValue = "No output device selected."
                return
            }

            self.audioEngine.attach(outputAudioUnit)

            // Get the input node (BlackHole as the system default input)
            let inputNode = self.audioEngine.inputNode

            // Set the format
            let format = inputNode.outputFormat(forBus: 0)

            // Connect the nodes
            self.audioEngine.connect(inputNode, to: self.eqNode, format: format)
            self.audioEngine.connect(self.eqNode, to: outputAudioUnit, format: format)

            // Start the audio engine
            do {
                try self.audioEngine.start()
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = "EQ settings applied successfully."
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = "Error starting audio engine: \(error.localizedDescription)"
                    print("Error starting audio engine: \(error)")
                }
            }
        }
    }


    
}
