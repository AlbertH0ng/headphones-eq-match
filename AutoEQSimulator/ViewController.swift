//
//  ViewController.swift
//  AutoEQSimulator
//
//  Created by Anting Hong on 22/09/2024.
//

import Cocoa
import AudioToolbox

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
    
    var audioGraph: AUGraph?
    var eqUnit: AudioUnit?
    var outputUnit: AudioUnit?
    
    
    var headphoneModels: [String] = []
    var myFilteredHeadphoneModels: [String] = []
    var targetFilteredHeadphoneModels: [String] = []
    
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
        stopAudioGraph()
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
    
    // MARK: - Audio Graph Setup and Control
    
    func initializeAUGraph() {
        var status = NewAUGraph(&audioGraph)
        if status != noErr {
            printError("creating AUGraph", error: status)
        }
    }
    
    var outputAudioUnit: AudioUnit?
    
    func startOutputUnit() {
        if let outputAudioUnit = outputAudioUnit {
            let status = AudioOutputUnitStart(outputAudioUnit)
            if status != noErr {
                printError("starting output audio unit", error: status)
            }
        }
    }

    
    func setupAUGraph(eqData: [EQPoint], preampValue: Double) {
        guard let audioGraph = audioGraph else { return }
        
        var status: OSStatus = noErr
        
        // **Input Unit Description**
        var inputDesc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput, // For input unit
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        // **EQ Unit Description**
        var eqDesc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_NBandEQ,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        // **Output Unit Description**
        var outputDesc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput, // For output unit
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        var inputNode = AUNode()
        var eqNode = AUNode()
        var outputNode = AUNode()
        
        // **Add Nodes to the Graph**
        status = AUGraphAddNode(audioGraph, &inputDesc, &inputNode)
        if status != noErr {
            printError("adding Input node", error: status)
            return
        }
        
        status = AUGraphAddNode(audioGraph, &eqDesc, &eqNode)
        if status != noErr {
            printError("adding EQ node", error: status)
            return
        }
        
        status = AUGraphAddNode(audioGraph, &outputDesc, &outputNode)
        if status != noErr {
            printError("adding Output node", error: status)
            return
        }
        
        // **Open the Graph**
        status = AUGraphOpen(audioGraph)
        if status != noErr {
            printError("opening AUGraph", error: status)
            return
        }
        
        // **Get Audio Unit Instances from Nodes**
        var inputUnit: AudioUnit?
        status = AUGraphNodeInfo(audioGraph, inputNode, nil, &inputUnit)
        if status != noErr {
            printError("getting Input unit from node", error: status)
            return
        }
        
        status = AUGraphNodeInfo(audioGraph, eqNode, nil, &eqUnit)
        if status != noErr {
            printError("getting EQ unit from node", error: status)
            return
        }
        
        status = AUGraphNodeInfo(audioGraph, outputNode, nil, &outputUnit)
        if status != noErr {
            printError("getting Output unit from node", error: status)
            return
        }
        
        // **Configure Input Unit**
        // Enable input on the input unit (element 1)
        var enableIO: UInt32 = 1
        status = AudioUnitSetProperty(
            inputUnit!,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1, // Input Element
            &enableIO,
            UInt32(MemoryLayout<UInt32>.size)
        )
        if status != noErr {
            printError("enabling input on input unit", error: status)
            return
        }
        
        // Disable output on the input unit (element 0)
        var disableIO: UInt32 = 0
        status = AudioUnitSetProperty(
            inputUnit!,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0, // Output Element
            &disableIO,
            UInt32(MemoryLayout<UInt32>.size)
        )
        if status != noErr {
            printError("disabling output on input unit", error: status)
            return
        }
        
        // Set the Input Device to BlackHole
        var inputDeviceID = AudioDeviceID(kAudioObjectUnknown)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultInputDeviceProperty = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputDeviceProperty,
            0,
            nil,
            &propertySize,
            &inputDeviceID
        )
        if status != noErr {
            printError("getting default input device", error: status)
            return
        }
        
        status = AudioUnitSetProperty(
            inputUnit!,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &inputDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            printError("setting input device", error: status)
            return
        }
        
        // **Configure Output Unit**
        // Enable output on the output unit (element 0)
        status = AudioUnitSetProperty(
            outputUnit!,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0, // Output Element
            &enableIO,
            UInt32(MemoryLayout<UInt32>.size)
        )
        if status != noErr {
            printError("enabling output on output unit", error: status)
            return
        }
        
        // Disable input on the output unit (element 1)
        status = AudioUnitSetProperty(
            outputUnit!,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1, // Input Element
            &disableIO,
            UInt32(MemoryLayout<UInt32>.size)
        )
        if status != noErr {
            printError("disabling input on output unit", error: status)
            return
        }
        
        // Set the Output Device to Selected Device
        if let deviceID = selectedOutputDeviceID {
            var deviceID = deviceID
            status = AudioUnitSetProperty(
                outputUnit!,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if status != noErr {
                printError("setting output device", error: status)
                return
            }
        } else {
            print("No output device selected")
            return
        }
        
        // **Configure the EQ Unit**
        configureEQUnit(eqUnit: eqUnit!, eqData: eqData, preampValue: preampValue)
        
        // **Set Stream Formats**
        // Get the hardware stream format from the input unit
        var streamFormat = AudioStreamBasicDescription()
        propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioUnitGetProperty(
            inputUnit!,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            1, // Input Element
            &streamFormat,
            &propertySize
        )
        if status != noErr {
            printError("getting stream format from input unit", error: status)
            return
        }
        
        // Set stream format on EQ unit input
        status = AudioUnitSetProperty(
            eqUnit!,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,
            &streamFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        if status != noErr {
            printError("setting stream format on EQ unit input", error: status)
            return
        }
        
        // Set stream format on EQ unit output
        status = AudioUnitSetProperty(
            eqUnit!,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            0,
            &streamFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        if status != noErr {
            printError("setting stream format on EQ unit output", error: status)
            return
        }
        
        // Set stream format on output unit input
        status = AudioUnitSetProperty(
            outputUnit!,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,
            &streamFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        if status != noErr {
            printError("setting stream format on output unit input", error: status)
            return
        }
        
        // **Connect the Nodes**
        status = AUGraphConnectNodeInput(audioGraph, inputNode, 1, eqNode, 0)
        if status != noErr {
            printError("connecting Input node to EQ node", error: status)
            return
        }
        
        status = AUGraphConnectNodeInput(audioGraph, eqNode, 0, outputNode, 0)
        if status != noErr {
            printError("connecting EQ node to Output node", error: status)
            return
        }
        
        // **Initialize the Graph**
        status = AUGraphInitialize(audioGraph)
        if status != noErr {
            printError("initializing AUGraph", error: status)
            return
        }
    }



    func osTypeString(_ error: OSStatus) -> String {
        let n = UInt32(bitPattern: error)
        let bytes: [CChar] = [
            CChar(bitPattern: UInt8((n >> 24) & 0xFF)),
            CChar(bitPattern: UInt8((n >> 16) & 0xFF)),
            CChar(bitPattern: UInt8((n >> 8) & 0xFF)),
            CChar(bitPattern: UInt8(n & 0xFF)),
            0
        ]
        if isprint(Int32(bytes[0])) != 0 && isprint(Int32(bytes[1])) != 0 &&
           isprint(Int32(bytes[2])) != 0 && isprint(Int32(bytes[3])) != 0 {
            return String(cString: bytes)
        } else {
            return "\(error)"
        }
    }

    
    func printError(_ operation: String, error: OSStatus) {
        let errorString = String(format: "%d (or 0x%X): %@", error, error, osTypeString(error))
        print("Error during \(operation): \(errorString)")
    }


    

    
    func configureEQUnit(eqUnit: AudioUnit, eqData: [EQPoint], preampValue: Double) {
        var status: OSStatus = noErr
        
        // Set number of bands
        var numBands: UInt32 = UInt32(eqData.count)
        status = AudioUnitSetProperty(eqUnit,
                                      kAUNBandEQProperty_NumberOfBands,
                                      kAudioUnitScope_Global,
                                      0,
                                      &numBands,
                                      UInt32(MemoryLayout<UInt32>.size))
        if status != noErr {
            print("Error setting number of bands: \(status)")
            return
        }
        
        for (index, eqPoint) in eqData.enumerated() {
            let bandIndex = UInt32(index)
            
            // Enable the band
            let bypass: UInt32 = 0 // 0 means enabled
            status = AudioUnitSetParameter(eqUnit,
                                           kAUNBandEQParam_BypassBand + bandIndex,
                                           kAudioUnitScope_Global,
                                           0,
                                           Float(bypass),
                                           0)
            if status != noErr {
                print("Error enabling band \(bandIndex): \(status)")
                continue
            }
            
            // Set filter type
            var filterType: UInt32
            switch eqPoint.filterType {
            case "PK":
                filterType = UInt32(kAUNBandEQFilterType_Parametric)
            case "LSC":
                filterType = UInt32(kAUNBandEQFilterType_LowShelf)
            case "HSC":
                filterType = UInt32(kAUNBandEQFilterType_HighShelf)
            default:
                filterType = UInt32(kAUNBandEQFilterType_Parametric)
            }
            
            status = AudioUnitSetParameter(eqUnit,
                                           kAUNBandEQParam_FilterType + bandIndex,
                                           kAudioUnitScope_Global,
                                           0,
                                           Float(filterType),
                                           0)
            if status != noErr {
                print("Error setting filter type for band \(bandIndex): \(status)")
                continue
            }
            
            // Set frequency
            status = AudioUnitSetParameter(eqUnit,
                                           kAUNBandEQParam_Frequency + bandIndex,
                                           kAudioUnitScope_Global,
                                           0,
                                           Float(eqPoint.frequency),
                                           0)
            if status != noErr {
                print("Error setting frequency for band \(bandIndex): \(status)")
                continue
            }
            
            // Set gain
            status = AudioUnitSetParameter(eqUnit,
                                           kAUNBandEQParam_Gain + bandIndex,
                                           kAudioUnitScope_Global,
                                           0,
                                           Float(eqPoint.gain),
                                           0)
            if status != noErr {
                print("Error setting gain for band \(bandIndex): \(status)")
                continue
            }
            
            // Set bandwidth (Q-factor)
            status = AudioUnitSetParameter(eqUnit,
                                           kAUNBandEQParam_Bandwidth + bandIndex,
                                           kAudioUnitScope_Global,
                                           0,
                                           Float(1.0 / eqPoint.qFactor),
                                           0)
            if status != noErr {
                print("Error setting bandwidth for band \(bandIndex): \(status)")
                continue
            }
        }
        
        // Set global gain (preamp)
        status = AudioUnitSetParameter(eqUnit,
                                       kAUNBandEQParam_GlobalGain,
                                       kAudioUnitScope_Global,
                                       0,
                                       Float(preampValue),
                                       0)
        if status != noErr {
            print("Error setting global gain: \(status)")
        }
    }
    
    func setOutputDevice(deviceID: AudioDeviceID) {
        guard let outputUnit = outputUnit else { return }
        var deviceID = deviceID
        let status = AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            print("Error setting output device: \(status)")
        }
    }

    func startAudioGraph() {
        guard let audioGraph = audioGraph else { return }
        let status = AUGraphStart(audioGraph)
        if status != noErr {
            print("Error starting AUGraph: \(status)")
        }
    }
    
    func stopAudioGraph() {
        if let audioGraph = audioGraph {
            AUGraphStop(audioGraph)
            AUGraphUninitialize(audioGraph)
            AUGraphClose(audioGraph)
            DisposeAUGraph(audioGraph)
            self.audioGraph = nil
            self.eqUnit = nil
            self.outputUnit = nil
        }
    }



    
    func applyEQSettings() {
        let myModel = myHeadphoneModelComboBox.stringValue
        let targetModel = targetHeadphoneModelComboBox.stringValue

        // Load EQ data for your headphone model
        guard let (myEQData, myPreamp) = loadEQData(for: myModel) else {
            statusLabel.stringValue = "Your headphone model not found."
            return
        }

        var combinedEQData = myEQData
        var combinedPreamp = myPreamp

        // If a target model is selected, load and invert its EQ data
        if !targetModel.isEmpty {
            guard let (targetEQData, targetPreamp) = loadEQData(for: targetModel) else {
                statusLabel.stringValue = "Target headphone model not found."
                return
            }
            let invertedTargetEQData = invertEQData(targetEQData)
            combinedEQData = combineEQData(myEQData, invertedTargetEQData)
            combinedPreamp += targetPreamp
        }

        // Stop the audio graph if it's already running
        stopAudioGraph()

        // Initialize and set up the AUGraph
        initializeAUGraph()
        setupAUGraph(eqData: combinedEQData, preampValue: combinedPreamp)

        // Start the audio graph
        startAudioGraph()

        statusLabel.stringValue = "EQ settings applied successfully."
    }


}
