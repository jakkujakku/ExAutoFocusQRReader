//
//  ViewController.swift
//  ExAutoFocusQRReader
//
//  Created by 준우의 MacBook 16 on 4/30/24.
//

import AVFoundation
import UIKit
import Vision

// 목표
/// 1. QR코드 기능 생성
/// 2. Auto Focus 기능 지원

final class QRReaderView: UIViewController {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var videoInput: AVCaptureDeviceInput!
    private var videoOutput: AVCaptureVideoDataOutput!
    private var photoOutput: AVCapturePhotoOutput!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }

        // Autu Focus 설정
        try? captureDevice.lockForConfiguration()
        if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
            captureDevice.focusMode = .continuousAutoFocus
        }
        captureDevice.unlockForConfiguration()

        do {
            videoInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
            print("#### Not Found Camera: \(error.localizedDescription)")
            return
        }

        /// QR코드 촬영 카메라 준비
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.high // 고화질
        captureSession.addInput(videoInput)

        /// QR코드 인식 설정
        let metadataOutput = AVCaptureMetadataOutput()
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
            metadataOutput.metadataObjectTypes = [.qr]
        }
        captureSession.addOutput(metadataOutput)

        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        captureSession.addOutput(videoOutput)

        /// AutoFocus 카메라 준비
        photoOutput = AVCapturePhotoOutput()
        captureSession.addOutput(photoOutput)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    /// When: QR 코드 인식 했을 때, 자동 촬영
    private func takePicture() {
        let settings = AVCapturePhotoSettings()
        settings.livePhotoVideoCodecType = .jpeg
        if captureSession.isRunning {
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "QR 코드 인식", message: message, preferredStyle: .alert)

        let confirmAlert = UIAlertAction(title: "확인", style: .default) { [weak self] action in
            self?.takePicture()
            self?.captureSession.stopRunning()
        }

        let cancelAlert = UIAlertAction(title: "취소", style: .destructive) { [weak self] action in
        }

        alert.addAction(confirmAlert)
        alert.addAction(cancelAlert)
        present(alert, animated: true)
    }
}

extension QRReaderView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let data = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
        }
    }
}

extension QRReaderView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                print("Failed to detect barcodes: \(error.localizedDescription)")
                return
            }

            guard let results = request.results as? [VNBarcodeObservation] else { return }

            for result in results {
                if result.symbology == .qr {
                    // QR 코드 인식 되었을 때
                    guard let payload = result.payloadStringValue else { return }
                    print("#### QR Code: \(payload)")
                    self.showAlert(message: payload)
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform barcode detection: \(error.localizedDescription)")
        }
    }
}

extension QRReaderView: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("will begin")
    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("will capture")
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("did capture: \(output)")
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("finished capture")
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("finish process : \(photo)")
    }
}
