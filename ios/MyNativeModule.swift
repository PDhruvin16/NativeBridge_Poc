import Foundation
import AVFoundation
import Vision
import CoreML
import UIKit
import React

@objc(MyNativeModule)
class MyNativeModule: NSObject {
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasResolved = false
    private var frameCount = 0
    private let maxFrames = 60
    private let minConfidence: Float = 0.3
    
    private var resolveBlock: RCTPromiseResolveBlock?
    private var rejectBlock: RCTPromiseRejectBlock?
    
    // MARK: - React Native Methods
    
    @objc
    func startObjectDetection(_ resolve: @escaping RCTPromiseResolveBlock,
                             rejecter reject: @escaping RCTPromiseRejectBlock) {
        NSLog("🎥 iOS: Starting object detection...")
        
        self.resolveBlock = resolve
        self.rejectBlock = reject
        self.hasResolved = false
        self.frameCount = 0
        
        DispatchQueue.main.async {
            self.checkPermissionAndStart()
        }
    }
    
    @objc
    func stopObjectDetection() {
        NSLog("⏹ iOS: Stopping camera...")
        cleanup()
    }
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    // MARK: - Permission Check
    
    private func checkPermissionAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startCamera()
                    } else {
                        self?.rejectBlock?("PERMISSION_DENIED", "Camera permission denied", nil)
                    }
                }
            }
        default:
            rejectBlock?("PERMISSION_DENIED", "Camera permission not granted", nil)
        }
    }
    
    // MARK: - Camera Setup
    
    private func startCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            rejectBlock?("NO_CAMERA", "Camera not available", nil)
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            guard let session = captureSession,
                  session.canAddInput(input) else {
                rejectBlock?("CAMERA_ERROR", "Cannot add camera input", nil)
                return
            }
            
            session.addInput(input)
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            
            guard session.canAddOutput(output) else {
                rejectBlock?("CAMERA_ERROR", "Cannot add video output", nil)
                return
            }
            
            session.addOutput(output)
            
            addPreviewLayer(session: session)
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                NSLog("✅ iOS: Camera started")
            }
            
        } catch {
            rejectBlock?("CAMERA_ERROR", "Camera setup failed: \(error.localizedDescription)", error)
        }
    }
    
    private func addPreviewLayer(session: AVCaptureSession) {
        DispatchQueue.main.async { [weak self] in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                return
            }
            
            self?.previewLayer = AVCaptureVideoPreviewLayer(session: session)
            self?.previewLayer?.frame = window.bounds
            self?.previewLayer?.videoGravity = .resizeAspectFill
            
            if let layer = self?.previewLayer {
                window.layer.addSublayer(layer)
                NSLog("📺 iOS: Preview layer added")
            }
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        DispatchQueue.main.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.previewLayer?.removeFromSuperlayer()
            self?.previewLayer = nil
            self?.captureSession = nil
            self?.hasResolved = false
            self?.frameCount = 0
            NSLog("🧹 iOS: Cleanup complete")
        }
    }
    
    // MARK: - Object Detection
    
    private func detectObjects(in pixelBuffer: CVPixelBuffer) {
        guard !hasResolved else { return }
        
        // Try multiple detection methods
        detectFaces(pixelBuffer)
        detectBarcodes(pixelBuffer)
        detectText(pixelBuffer)
        detectRectangles(pixelBuffer)
    }
    
    // Method 1: Face detection
    private func detectFaces(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            NSLog("⚠️ Face detection error: \(error)")
        }
    }
    
    // Method 2: Barcode/QR detection
    private func detectBarcodes(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            self?.handleBarcodeDetection(request: request, error: error)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            NSLog("⚠️ Barcode detection error: \(error)")
        }
    }
    
    // Method 3: Text detection
    private func detectText(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectTextRectanglesRequest { [weak self] request, error in
            self?.handleTextDetection(request: request, error: error)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            NSLog("⚠️ Text detection error: \(error)")
        }
    }
    
    // Method 4: Rectangle/object detection
    private func detectRectangles(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleRectangleDetection(request: request, error: error)
        }
        request.minimumConfidence = 0.3
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.5
        request.minimumSize = 0.1
        request.maximumObservations = 10
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            NSLog("⚠️ Rectangle detection error: \(error)")
        }
    }
    
    // MARK: - Result Handlers
    
    private func handleFaceDetection(request: VNRequest, error: Error?) {
        guard !hasResolved else { return }
        
        if let error = error {
            NSLog("⚠️ Face detection error: \(error)")
            return
        }
        
        guard let observations = request.results as? [VNFaceObservation],
              !observations.isEmpty else {
            NSLog("📊 Faces: No faces found")
            return
        }
        
        var results: [[String: Any]] = []
        
        for (index, observation) in observations.enumerated() {
            if observation.confidence >= minConfidence {
                let detection: [String: Any] = [
                    "label": "Face \(index + 1)",
                    "confidence": Double(observation.confidence)
                ]
                results.append(detection)
                NSLog("🎯 Detected: Face \(index + 1) (\(observation.confidence))")
            }
        }
        
        resolveIfFound(results)
    }
    
    private func handleBarcodeDetection(request: VNRequest, error: Error?) {
        guard !hasResolved else { return }
        
        if let error = error {
            NSLog("⚠️ Barcode detection error: \(error)")
            return
        }
        
        guard let observations = request.results as? [VNBarcodeObservation],
              !observations.isEmpty else {
            NSLog("📊 Barcodes: No barcodes found")
            return
        }
        
        var results: [[String: Any]] = []
        
        for observation in observations {
            if observation.confidence >= minConfidence {
                let type = observation.symbology.rawValue
                let detection: [String: Any] = [
                    "label": "Barcode (\(type))",
                    "confidence": Double(observation.confidence)
                ]
                results.append(detection)
                NSLog("🎯 Detected: Barcode \(type) (\(observation.confidence))")
            }
        }
        
        resolveIfFound(results)
    }
    
    private func handleTextDetection(request: VNRequest, error: Error?) {
        guard !hasResolved else { return }
        
        if let error = error {
            NSLog("⚠️ Text detection error: \(error)")
            return
        }
        
        guard let observations = request.results as? [VNTextObservation],
              !observations.isEmpty else {
            NSLog("📊 Text: No text found")
            return
        }
        
        var results: [[String: Any]] = []
        
        for (index, observation) in observations.enumerated() {
            if observation.confidence >= minConfidence {
                let detection: [String: Any] = [
                    "label": "Text Region \(index + 1)",
                    "confidence": Double(observation.confidence)
                ]
                results.append(detection)
                NSLog("🎯 Detected: Text region \(index + 1) (\(observation.confidence))")
            }
        }
        
        resolveIfFound(results)
    }
    
    private func handleRectangleDetection(request: VNRequest, error: Error?) {
        guard !hasResolved else { return }
        
        if let error = error {
            NSLog("⚠️ Rectangle detection error: \(error)")
            return
        }
        
        guard let observations = request.results as? [VNRectangleObservation],
              !observations.isEmpty else {
            NSLog("📊 Rectangles: No rectangles found")
            return
        }
        
        var results: [[String: Any]] = []
        
        for (index, observation) in observations.enumerated() {
            if observation.confidence >= minConfidence {
                let detection: [String: Any] = [
                    "label": "Object \(index + 1)",
                    "confidence": Double(observation.confidence)
                ]
                results.append(detection)
                NSLog("🎯 Detected: Rectangle/Object \(index + 1) (\(observation.confidence))")
            }
        }
        
        resolveIfFound(results)
    }
    
    private func resolveIfFound(_ results: [[String: Any]]) {
        if !results.isEmpty && !hasResolved {
            hasResolved = true
            NSLog("✅ Found \(results.count) objects, resolving...")
            
            DispatchQueue.main.async { [weak self] in
                self?.resolveBlock?(results)
                self?.cleanup()
            }
        }
    }
    
    private func checkForTimeout() {
        if frameCount >= maxFrames && !hasResolved {
            hasResolved = true
            NSLog("⏱ Timeout: No objects detected after \(maxFrames) frames")
            
            DispatchQueue.main.async { [weak self] in
                self?.resolveBlock?([])
                self?.cleanup()
            }
        }
    }
}

// MARK: - Video Output Delegate

extension MyNativeModule: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        
        guard !hasResolved else { return }
        
        frameCount += 1
        
        if frameCount % 15 == 0 {
            NSLog("📊 Frame: \(frameCount)/\(maxFrames)")
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Process every 5th frame for better performance
        if frameCount % 5 == 0 {
            detectObjects(in: pixelBuffer)
        }
        
        // Check timeout
        if frameCount >= maxFrames {
            checkForTimeout()
        }
    }
}