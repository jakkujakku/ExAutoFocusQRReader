# QR 코드 Auto Focus 테스트

## 목표

1. QR 코드 인식
2. Auto Focus
3. 인식한 QR 코드 결과값 Alert 형식으로 표현

## 1. QR 코드 인식

- 필요한 변수들

```swift
private var captureSession: AVCaptureSession!
private var previewLayer: AVCaptureVideoPreviewLayer!
private var videoInput: AVCaptureDeviceInput!
private var videoOutput: AVCaptureVideoDataOutput!
```

- 관련 메서드

```swift
private func setupCaptureSession() {
      guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }

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

      /// QR코드 인식 설정 - QR 코드 메다데이터 캡쳐
      let metadataOutput = AVCaptureMetadataOutput()
      metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
      if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
          metadataOutput.metadataObjectTypes = [.qr]
      }
      captureSession.addOutput(metadataOutput)

      videoOutput = AVCaptureVideoDataOutput()
      videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
      captureSession.addOutput(videoOutput)

      previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
      previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
      previewLayer.frame = view.layer.bounds
      view.layer.addSublayer(previewLayer)

      captureSession.startRunning() // QR 코드 인식 시작
  }
```

- AVCaptureMetadataOutputObjectsDelegate : 메타데이터 객체가 캡처될 때마다 호출되는 메서드

```swift
extension QRReaderView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let data = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
        }
    }
}
```

- AVCaptureVideoDataOutputSampleBufferDelegate : 비디오 프레임에서 QR 코드 인식할 수 있게 해주는 Delegate

```swift
extension QRReaderView: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
      guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        /// Vison 사용
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
```

## 2. Auto Focus

관련 자료들이 iOS 10 버전인 7,8년 전 자료들이 많이 존재하여, 바뀌거나 사라진 변수와 메서드들이 존재했음.
특히, AVCaptureStillImageOutput 메서드는 iOS 10 이후로 지원이 안되는 메서드여서 바꾸어 사용해함.

```swift
/// [iOS 10]
output.outputSettings = [ AVVideoCodecKey: AVVideoCodecJPEG ]

/// [iOS 17]
settings.livePhotoVideoCodecType = .jpeg

```

- 필요한 변수

```swift
private var photoOutput: AVCapturePhotoOutput!
```

- 관련 메서드 : QR 코드가 인식 될 때 자동 포커싱

```swift
private func takePicture() {
    let settings = AVCapturePhotoSettings()
    settings.livePhotoVideoCodecType = .jpeg
    if captureSession.isRunning {
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}
```

- setupCaptureSession() 내부 메서드도 변경해야함.

```swift
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

/// AutoFocus 카메라 준비
photoOutput = AVCapturePhotoOutput()
captureSession.addOutput(photoOutput)
```

- 관련 Delegate

```swift
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
```

## 3. 인식한 QR 코드 결과값 Alert 형식으로 표현

<img src="https://velog.velcdn.com/images/jakkujakku98/post/a32ecb60-2117-41cc-986d-da1700c07e46/image.PNG" width="30%" height="30%">
