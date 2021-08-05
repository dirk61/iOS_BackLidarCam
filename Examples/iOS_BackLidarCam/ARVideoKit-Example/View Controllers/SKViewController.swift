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

class SKViewController: UIViewController, ARSKViewDelegate, RenderARDelegate, RecordARDelegate, ARSessionDelegate  {
    
    @IBOutlet var SKSceneView: ARSKView!
    @IBOutlet var recordBtn: UIButton!
    @IBOutlet var pauseBtn: UIButton!
    let depthcapture = DepthCapture()
    let recordingQueue = DispatchQueue(label: "recordingThread")
    let caprturingQueue = DispatchQueue(label: "capturingThread", attributes: .concurrent)
    var isRecording = false
    var recorder:RecordAR?
    var count = 0
    let formatter = DateFormatter()
    var timestamps: String = ""
    
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
    var txtPath:String = ""
    var csvwriter:CHCSVWriter?
    var timestampOutput = OutputStream.toMemory()
    var timestampCsvWriter:CHCSVWriter?
    var timestampBuffer:Data?
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.dateFormat = "yyyy-MM-dd'@'HH-mm-ssZZZZ"
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
        
        
        
        depthcapture.prepareForRecording()
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
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if #available(iOS 14.0, *) {
            if isRecording == true{
                count = count + 1
                let depthFrame = frame.sceneDepth?.depthMap

                
                //                let img = UIImage(ciImage: CIImage(cvPixelBuffer:frame.capturedImage))
                //                if let data = img.pngData() {
                //                    let filename = getDocumentsDirectory().appendingPathComponent(String(count) + ".png")
                //                    try? data.write(to: filename)
                //                }
                //            print(CVPixelBufferGetWidth(depthFrame!))
                //            print(CVPixelBufferGetHeight(depthFrame!))
                //            assert(kCVPixelFormatType_DepthFloat32 == CVPixelBufferGetPixelFormatType(depthFrame!))
                //            CVPixelBufferLockBaseAddress(depthFrame!, .readOnly)
                //            let rowData = CVPixelBufferGetBaseAddress(depthFrame!)! + Int(128) * CVPixelBufferGetBytesPerRow(depthFrame!)
                //            var f16Pixel = rowData.assumingMemoryBound(to: Float32.self)[Int(96)]
                //
                //            print(f16Pixel)
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
                isRecording = true
                
                sender.setTitle("Stop", for: .normal)
                //                pauseBtn.setTitle("Pause", for: .normal)
                //                pauseBtn.isEnabled = true
                recordingQueue.async {
                    self.recorder?.record()
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
                sender.setTitle("Record", for: .normal)
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
                sender.setTitle("Stop", for: .normal)
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
