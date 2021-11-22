//
//  SKViewController.swift
//  ARVideoKit-Example
//
//  Created by Ahmed Bekhit on 11/2/17.
//  Copyright © 2017 Ahmed Fathi Bekhit. All rights reserved.
//

import UIKit
import ARKit
import ARVideoKit
import Photos
import Network

@available(iOS 12.0, *)
class SKViewController: UIViewController, ARSKViewDelegate, RenderARDelegate, RecordARDelegate, ARSessionDelegate  {
    
    @IBOutlet var SKSceneView: ARSKView!
    @IBOutlet var recordBtn: UIButton!
    @IBOutlet var pauseBtn: UIButton!
    @IBOutlet weak var DistanceText: UITextField!
    @IBOutlet weak var DurationText: UITextField!
    @IBOutlet weak var WarningTex: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var Instruct1: UITextView!
    @IBOutlet weak var Instruct2: UITextView!
    let depthcapture = DepthCapture()
    let recordingQueue = DispatchQueue(label: "recordingThread")
    let caprturingQueue = DispatchQueue(label: "capturingThread", attributes: .concurrent)
    var isRecording = false
    var recorder:RecordAR?
    var count = 0
    let formatter = DateFormatter()
    var timestamps: String = ""
    var distanceNum = 0.0
    var recordingTime = 0
    var broadcastStat = ""
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
    var txtPath:String = ""
    var csvwriter:CHCSVWriter?
    var timestampOutput = OutputStream.toMemory()
    var timestampCsvWriter:CHCSVWriter?
    var timestampBuffer:Data?
    
    var listener: NWListener?
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    override func viewDidAppear(_ animated: Bool) {
        let alertController = UIAlertController(title: "使用须知", message: "在录制开始前，将脸部放入蓝色圆内。保持脸部距离手机35cm左右。录制时，尽量保持静止。", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.DistanceText.isEnabled = false
        self.WarningTex.isEnabled = false
        self.DurationText.isEnabled = false
        self.Instruct1.isEditable = false
        self.Instruct2.isEditable = false
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.dateFormat = "yyyy_MM_dd'_'HH_mm_ss"
        let date = Date(timeIntervalSince1970: Date().timeIntervalSince1970)
        txtPath  = "\(documentsPath)/\(formatter.string(from: date))_DepthTimeStamp.txt"
        timestampCsvWriter = CHCSVWriter(outputStream: timestampOutput, encoding: String.Encoding.utf8.rawValue, delimiter: ",".utf16.first!)
        timestampBuffer = (timestampOutput.property(forKey: .dataWrittenToMemoryStreamKey) as? Data)!
        
        // Set the view's delegate
        SKSceneView.delegate = self
        
        // Show statistics such as fps and node count
        SKSceneView.showsFPS = false
        SKSceneView.showsNodeCount = false
        
        // Load the SKScene from 'Scene.sks'
        let scene = SKScene(size: CGSize(width: CGFloat(1440), height: CGFloat(1920)))
        print(scene.camera?.containedNodeSet())
        scene.scaleMode = .aspectFit
        scene.backgroundColor = .black
        print(scene.size.width)
        print(scene.size.height)
        SKSceneView.presentScene(scene)
        SKSceneView.scene?.scaleMode = .aspectFit
        
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 280, height: 350))

            let img = renderer.image { ctx in
                let rect = CGRect(x: 30, y: 30, width: 220, height: 275)

                // 6
                if #available(iOS 13.0, *) {
                    ctx.cgContext.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
                } else {
                    // Fallback on earlier versions
                }
                ctx.cgContext.setStrokeColor(UIColor.systemBlue.cgColor)
                ctx.cgContext.setLineWidth(3)

                ctx.cgContext.addEllipse(in: rect)
                ctx.cgContext.drawPath(using: .fillStroke)
            }

            imageView.image = img
        
        
        // Initialize ARVideoKit recorder
        recorder = RecordAR(ARSpriteKit: SKSceneView)
        
        /*----👇---- ARVideoKit Configuration ----👇----*/
        
        // Set the recorder's delegate
        recorder?.delegate = self
        
        // Set the renderer's delegate
        recorder?.renderAR = self
        
        // Configure the renderer to perform additional image & video processing 👁
        recorder?.onlyRenderWhileRecording = false
        
        // Set the UIViewController orientations
        recorder?.inputViewOrientations = [.landscapeLeft, .landscapeRight, .portrait]
        
        // Configure RecordAR to store media files in local app directory
        recorder?.deleteCacheWhenExported = false
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            var distanceStr = String(format: "%.2f", self.distanceNum)
            self.DistanceText.text = "距离屏幕" + distanceStr + "cm" + self.broadcastStat
            if (self.distanceNum < 31){
                self.WarningTex.text = "离人脸过近！"
            }
            else if (self.distanceNum > 39){
                self.WarningTex.text = "离人脸过远！"
            }
            else{
                self.WarningTex.text = ""
            }
    }
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if #available(iOS 14.0, *) {
            let depthFrame = frame.sceneDepth?.depthMap
            if depthFrame != nil{
            CVPixelBufferLockBaseAddress(depthFrame!, .readOnly)
            let rowData = CVPixelBufferGetBaseAddress(depthFrame!)! + Int(128) * CVPixelBufferGetBytesPerRow(depthFrame!)
            var f16Pixel = rowData.assumingMemoryBound(to: Float32.self)[Int(96)]
            
            distanceNum = Double(f16Pixel * 100)
            }
            if isRecording == true{
                count = count + 1
                
                
                
                //                let img = UIImage(ciImage: CIImage(cvPixelBuffer:frame.capturedImage))
                //                if let data = img.pngData() {
                //                    let filename = getDocumentsDirectory().appendingPathComponent(String(count) + ".png")
                //                    try? data.write(to: filename)
                //                }
                //            print(CVPixelBufferGetWidth(depthFrame!))
                //            print(CVPixelBufferGetHeight(depthFrame!))
                //            assert(kCVPixelFormatType_DepthFloat32 == CVPixelBufferGetPixelFormatType(depthFrame!))
               
                //                print(String(Int(Date().timeIntervalSince1970 * 1000)))
                timestamps = timestamps + String(Int(Date().timeIntervalSince1970 * 1000)) + "\n"
                var queue = DispatchQueue(label: "dd")
                queue.async {
                    self.depthcapture.addPixelBuffers(pixelBuffer: depthFrame!)}
            }
            
            
        } else {
            // Fallback on earlier versions
        }
        
        
        // swift does not have an Float16 data type. Use UInt16 instead, and then translate
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Create a session configuration
        
        do {
            if #available(iOS 12.0, *) {
                listener = try NWListener(using: .udp, on: 3600)
            } else {
                // Fallback on earlier versions
            }
        } catch {
            print("exception upon creating listener")
        }
        
        listener?.stateUpdateHandler = {(newState) in
            switch newState {
            case .ready:
                print("ready")
                self.broadcastStat = "连接成功"
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = {(newConnection) in
            newConnection.stateUpdateHandler = {newState in
                switch newState {
                case .setup:
                                   print("Listener: Setup")
               case .waiting(let error):
                    self.broadcastStat = "连接失败"
                   print("Listener: Waiting \(error)")
                case .ready:
                    print("connection ready")
                    
                    
                    let strIPAddress : String = self.getIPAddress()
                    if strIPAddress.isEmpty
                    {print("连接失败")
                        self.broadcastStat = "连接失败"
//                        self.BroadCastView.text = "连接失败"
                    }
                    else{print("连接成功")
                        self.broadcastStat = "连接成功"
//                        self.BroadCastView.text = "成功连接"
                    }
                    print("IPAddress :: \(strIPAddress)")
                    newConnection.receiveMessage { (data, context, isComplete, error) in
                        let stringValue = String(decoding: data!, as: UTF8.self)
                        if !stringValue.isEmpty
                        {
                            if stringValue == "true"
                            {print("开始录制")
                                self.broadcastStat = "开始录制"
                            //--------------start recording
//                            self.BroadCastView.text = "开始录制"
                            print(stringValue)
                                if self.recorder?.status == .readyToRecord {
                                    self.depthcapture.prepareForRecording()
                                    self.isRecording = true
                                    
                                    
                                    //                pauseBtn.setTitle("Pause", for: .normal)
                                    //                pauseBtn.isEnabled = true
                                    self.recordingQueue.async {
                                        self.recorder?.record()
                                    }
                                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                                        print("timer fired!")
                                        
                                        self.recordingTime += 1
                                        var remainder = "\(self.recordingTime % 60)"
                                        if (self.recordingTime % 60 < 10)
                                        {
                                            remainder = "0\(self.recordingTime % 60)"
                                        }
                                        self.DurationText.text = String("录制时间:0\(Int(self.recordingTime/60)):\(remainder)")
                                        //            print(timeLeft)
                                        
                                        if (!self.isRecording){
                                            timer.invalidate()
                                            self.recordingTime = 0
                                            self.DurationText.text = "录制时间:00:00"
                                            let alertController = UIAlertController(title: "完成录制", message: "录制完成。文件已保存！", preferredStyle: .alert)
                                            alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
                                            self.present(alertController, animated: true, completion: nil)
                                        }
                                        
                                        if (self.recordingTime == 300)
                                        {
                                            timer.invalidate()
                                            self.recordingTime = 0
                                            self.DurationText.text = "录制时间:00:00"
                                            let alertController = UIAlertController(title: "达到录制时长上限", message: "录制五分钟，达到录制上线。文件已自动保存！", preferredStyle: .alert)
                                            alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
                                            self.present(alertController, animated: true, completion: nil)
                                            
                                            self.isRecording = false
                                            self.isRecording = false
                                            do {
                                                try self.timestamps.write(to: URL(fileURLWithPath: self.txtPath), atomically: true, encoding: String.Encoding.utf8)
                                            } catch {
                                                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                                            }
                                            do {
                                                try self.depthcapture.finishRecording(success: { (url: URL) -> Void in
                                                    print(url.absoluteString)
                                                    
                                                })
                                            } catch {
                                                print("Error while finishing depth capture.")
                                            }
                                           
                                            //                pauseBtn.setTitle("Pause", for: .normal)
                                            //                pauseBtn.isEnabled = false
                                            self.recorder?.stop() { path in
                                                self.recorder?.export(video: path) { saved, status in
                                                    DispatchQueue.main.sync {
                                                        self.exportMessage(success: saved, status: status)
                                                    }
                                                }
                                            }
                                           
                                        }
                                    }
                                    
                                }
//                                self.record(self.recordBtn)
                            //--------------start recording
                            }
                                else
                                {print("停止录制")
                                    self.broadcastStat = "停止录制"
                                    //--------------stop recording
//                                self.BroadCastView.text = "停止录制"
                                   if self.recorder?.status == .recording {
                                        self.isRecording = false
                                        do {
                                            try self.timestamps.write(to: URL(fileURLWithPath: self.txtPath), atomically: true, encoding: String.Encoding.utf8)
                                        } catch {
                                            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                                        }
                                        do {
                                            try self.depthcapture.finishRecording(success: { (url: URL) -> Void in
                                                print(url.absoluteString)
                                                
                                            })
                                        } catch {
                                            print("Error while finishing depth capture.")
                                        }
                                        
                                        //                pauseBtn.setTitle("Pause", for: .normal)
                                        //                pauseBtn.isEnabled = false
                                        self.recorder?.stop() { path in
                                            self.recorder?.export(video: path) { saved, status in
                                                DispatchQueue.main.sync {
                                                    self.exportMessage(success: saved, status: status)
                                                }
                                            }
                                        }
                                    }
                                    
                                    
                                    //--------------stop recording
                                print(stringValue)
                                }
                        }
                        
                        
                    }
                default:
                    break
                }
            }
            newConnection.start(queue: DispatchQueue(label: "newconn"))
        }
        
        listener?.start(queue: .main)
        
        let configuration = ARWorldTrackingConfiguration()
        
        if #available(iOS 14.0, *) {
            configuration.environmentTexturing = .automatic
            if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics = .sceneDepth
            }
        } else {
            // Fallback on earlier versions
        }
        // Run the view's session
        SKSceneView.session.delegate = self
        SKSceneView.scene?.scaleMode = .aspectFit
        SKSceneView.session.run(configuration)
        
        // Prepare the recorder with sessions configuration
        recorder?.prepare(configuration)
        
        
    }
    func getIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface.ifa_name))
                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address ?? ""
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        SKSceneView.session.pause()
        
        if recorder?.status == .recording {
            recorder?.stopAndExport()
        }
        recorder?.onlyRenderWhileRecording = true
        recorder?.prepare(ARWorldTrackingConfiguration())
        
        // Switch off the orientation lock for UIViewControllers with AR Scenes
        recorder?.rest()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Hide Status Bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Exported UIAlert present method
    func exportMessage(success: Bool, status:PHAuthorizationStatus) {
        if success {
            let alert = UIAlertController(title: "Exported", message: "Media exported to camera roll successfully!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Awesome", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }else if status == .denied || status == .restricted || status == .notDetermined {
            let errorView = UIAlertController(title: "😅", message: "Please allow access to the photo library in order to save this media file.", preferredStyle: .alert)
            let settingsBtn = UIAlertAction(title: "Open Settings", style: .cancel) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        })
                    } else {
                        UIApplication.shared.openURL(URL(string:UIApplication.openSettingsURLString)!)
                    }
                }
            }
            errorView.addAction(UIAlertAction(title: "Later", style: UIAlertAction.Style.default, handler: {
                (UIAlertAction)in
            }))
            errorView.addAction(settingsBtn)
            self.present(errorView, animated: true, completion: nil)
        }else{
            let alert = UIAlertController(title: "Exporting Failed", message: "There was an error while exporting your media file.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

//MARK: - Button Action Methods
@available(iOS 12.0, *)
extension SKViewController {
    @IBAction func goBack(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func capture(_ sender: UIButton) {
        if sender.tag == 0 {
            //Photo
            if recorder?.status == .readyToRecord {
                let image = self.recorder?.photo()
                self.recorder?.export(UIImage: image) { saved, status in
                    if saved {
                        // Inform user photo has exported successfully
                        self.exportMessage(success: saved, status: status)
                    }
                }
            }
        }else if sender.tag == 1 {
            //Live Photo
            if recorder?.status == .readyToRecord {
                caprturingQueue.async {
                    self.recorder?.livePhoto(export: true) { ready, photo, status, saved in
                        /*
                         if ready {
                         // Do something with the `photo` (PHLivePhotoPlus)
                         }
                         */
                        
                        if saved {
                            // Inform user Live Photo has exported successfully
                            self.exportMessage(success: saved, status: status)
                        }
                    }
                }
            }
        }else if sender.tag == 2 {
            //GIF
            if recorder?.status == .readyToRecord {
                recorder?.gif(forDuration: 3.0, export: true) { ready, gifPath, status, saved in
                    /*
                     if ready {
                     // Do something with the `gifPath`
                     }
                     */
                    
                    if saved {
                        // Inform user GIF image has exported successfully
                        self.exportMessage(success: saved, status: status)
                    }
                }
            }
        }
    }
    
    @IBAction func record(_ sender: UIButton) {
        if sender.tag == 0 {
            //Record
            
            if recorder?.status == .readyToRecord {
                depthcapture.prepareForRecording()
                isRecording = true
                
                sender.setTitle("停止", for: .normal)
                //                pauseBtn.setTitle("Pause", for: .normal)
                //                pauseBtn.isEnabled = true
                recordingQueue.async {
                    self.recorder?.record()
                }
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    print("timer fired!")
                    
                    self.recordingTime += 1
                    var remainder = "\(self.recordingTime % 60)"
                    if (self.recordingTime % 60 < 10)
                    {
                        remainder = "0\(self.recordingTime % 60)"
                    }
                    self.DurationText.text = String("录制时间:0\(Int(self.recordingTime/60)):\(remainder)")
                    //            print(timeLeft)
                    
                    if (!self.isRecording){
                        timer.invalidate()
                        self.recordingTime = 0
                        self.DurationText.text = "录制时间:00:00"
                        let alertController = UIAlertController(title: "完成录制", message: "录制完成。文件已保存！", preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }
                    
                    if (self.recordingTime == 300)
                    {
                        timer.invalidate()
                        self.recordingTime = 0
                        self.DurationText.text = "录制时间:00:00"
                        let alertController = UIAlertController(title: "达到录制时长上限", message: "录制五分钟，达到录制上线。文件已自动保存！", preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                        
                        self.isRecording = false
                        self.isRecording = false
                        do {
                            try self.timestamps.write(to: URL(fileURLWithPath: self.txtPath), atomically: true, encoding: String.Encoding.utf8)
                        } catch {
                            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                        }
                        do {
                            try self.depthcapture.finishRecording(success: { (url: URL) -> Void in
                                print(url.absoluteString)
                                
                            })
                        } catch {
                            print("Error while finishing depth capture.")
                        }
                        sender.setTitle("开始", for: .normal)
                        //                pauseBtn.setTitle("Pause", for: .normal)
                        //                pauseBtn.isEnabled = false
                        self.recorder?.stop() { path in
                            self.recorder?.export(video: path) { saved, status in
                                DispatchQueue.main.sync {
                                    self.exportMessage(success: saved, status: status)
                                }
                            }
                        }
                        sender.setTitle("开始", for: .normal)
                    }
                }
                
            }else if recorder?.status == .recording {
                isRecording = false
                do {
                    try timestamps.write(to: URL(fileURLWithPath: txtPath), atomically: true, encoding: String.Encoding.utf8)
                } catch {
                    // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                }
                do {
                    try depthcapture.finishRecording(success: { (url: URL) -> Void in
                        print(url.absoluteString)
                        
                    })
                } catch {
                    print("Error while finishing depth capture.")
                }
                sender.setTitle("开始", for: .normal)
                //                pauseBtn.setTitle("Pause", for: .normal)
                //                pauseBtn.isEnabled = false
                recorder?.stop() { path in
                    self.recorder?.export(video: path) { saved, status in
                        DispatchQueue.main.sync {
                            self.exportMessage(success: saved, status: status)
                        }
                    }
                }
            }
        }else if sender.tag == 1 {
            //Record with duration
            if recorder?.status == .readyToRecord {
                isRecording = true
                sender.setTitle("停止", for: .normal)
                //                pauseBtn.setTitle("Pause", for: .normal)
                //                pauseBtn.isEnabled = false
                recordBtn.isEnabled = false
                recordingQueue.async {
                    self.recorder?.record(forDuration: 10) { path in
                        self.recorder?.export(video: path) { saved, status in
                            DispatchQueue.main.sync {
                                sender.setTitle("w/Duration", for: .normal)
                                //                                self.pauseBtn.setTitle("Pause", for: .normal)
                                //                                self.pauseBtn.isEnabled = false
                                self.recordBtn.isEnabled = true
                                self.exportMessage(success: saved, status: status)
                                
                                
                            }
                        }
                    }
                }
            }else if recorder?.status == .recording {
                isRecording = false
                sender.setTitle("w/Duration", for: .normal)
                //                pauseBtn.setTitle("Pause", for: .normal)
                //                pauseBtn.isEnabled = false
                recordBtn.isEnabled = true
                recorder?.stop() { path in
                    self.recorder?.export(video: path) { saved, status in
                        DispatchQueue.main.sync {
                            self.exportMessage(success: saved, status: status)
                        }
                    }
                }
            }
        }else if sender.tag == 2 {
            //Pause
            if recorder?.status == .paused {
                sender.setTitle("Pause", for: .normal)
                recorder?.record()
            }else if recorder?.status == .recording {
                sender.setTitle("Resume", for: .normal)
                recorder?.pause()
            }
        }
    }
}

//MARK: - ARVideoKit Delegate Methods
@available(iOS 12.0, *)
extension SKViewController {
    func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        // Do some image/video processing.
    }
    
    func recorder(didEndRecording path: URL, with noError: Bool) {
        if noError {
            // Do something with the video path.
        }
    }
    
    func recorder(didFailRecording error: Error?, and status: String) {
        // Inform user an error occurred while recording.
    }
    
    func recorder(willEnterBackground status: RecordARStatus) {
        // Use this method to pause or stop video recording. Check [applicationWillResignActive(_:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622950-applicationwillresignactive) for more information.
        if status == .recording {
            recorder?.stopAndExport()
        }
    }
}

// MARK: - ARSKView Delegate Methods
@available(iOS 12.0, *)
extension SKViewController {
    //    var randoMoji:String {
    //        let emojis = ["👾", "🤓", "🔥", "😜", "😇", "🤣", "🤗"]
    //        return emojis[Int(arc4random_uniform(UInt32(emojis.count)))]
    //    }
    
    //    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
    //        // Create and configure a node for the anchor added to the view's session.
    //        let labelNode = SKLabelNode(text: randoMoji)
    //        labelNode.horizontalAlignmentMode = .center
    //        labelNode.verticalAlignmentMode = .center
    //        return labelNode;
    //    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

