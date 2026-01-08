import Foundation
import AVFoundation
import Vision
import UIKit

@objc(MyNativeBridgeSwift)
class MyNativeBridgeSwift: NSObject {
    
    @objc static let shared = MyNativeBridgeSwift()
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasResolved = false
    private var frameCount = 0
    private let maxFrames = 60
    private let minConfidence: Float = 0.5
    
    private var resolveBlock: RCTPromiseResolveBlock?
    private var rejectBlock: RCTPromiseRejectBlock?
    
    @objc func startObjectDetection(resolve: @escaping RCTPromiseResolveBlock,
                                    reject: @escaping RCTPromiseRejectBlock) {
        self.resolveBlock = resolve
        self.rejectBlock = reject
        self.hasResolved = false
        self.frameCount = 0
        
        DispatchQueue.main.async {
            self.setupCamera()
        }
    }
    
    @objc func stopObjectDetection() {
        DispatchQueue.main.async {
            self.cleanup()
        }
    }
    
    private func setupCamera() {
        // Check camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        if status == .authorized {
            startCamera()
        } else if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.startCamera()
                    }
                } else {
                    self.rejectBlock?("PERMISSION_DENIED", "Camera permission denied", nil)
                }
            }
        } else {
            rejectBlock?("PERMISSION_DENIED", "Camera permission denied", nil)
        }
    }
    
    private func startCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                          for: .video,
                                                          position: .back) else {
            rejectBlock?("NO_CAMERA", "Back camera not available", nil)
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            
            if captureSession?.canAddOutput(videoOutput) == true {
                captureSession?.addOutput(videoOutput)
            }
            
            // Add preview layer
            if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                previewLayer?.frame = keyWindow.bounds
                previewLayer?.videoGravity = .resizeAspectFill
                keyWindow.layer.addSublayer(previewLayer!)
            }
            
            captureSession?.startRunning()
            
        } catch {
            rejectBlock?("CAMERA_ERROR", "Failed to start camera: \(error.localizedDescription)", error)
        }
    }
    
    private func cleanup() {
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        captureSession = nil
        previewLayer = nil
        hasResolved = false
        frameCount = 0
    }
    
    private func processDetections(_ observations: [VNRecognizedObjectObservation]) {
        guard !hasResolved else { return }
        
        var results: [[String: Any]] = []
        
        for observation in observations {
            guard let label = observation.labels.first,
                  label.confidence >= minConfidence else {
                continue
            }
            
            let detection: [String: Any] = [
                "label": label.identifier,
                "confidence": Double(label.confidence)
            ]
            results.append(detection)
            
            print("Detected: \(label.identifier) (\(label.confidence))")
        }
        
        if !results.isEmpty {
            hasResolved = true
            DispatchQueue.main.async {
                self.resolveBlock?(results)
                self.cleanup()
            }
        } else if frameCount >= maxFrames {
            hasResolved = true
            DispatchQueue.main.async {
                self.resolveBlock?([])
                self.cleanup()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension MyNativeBridgeSwift: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        
        guard !hasResolved else { return }
        frameCount += 1
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNRecognizeAnimalsRequest { request, error in
            if let error = error {
                print("Detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                return
            }
            
            self.processDetections(observations)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform detection: \(error)")
        }
    }
}