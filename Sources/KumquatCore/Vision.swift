import CoreImage
import Foundation
import Vision

/// On-device machine learning: background removal and text recognition. Nothing leaves the Mac.
public enum VisionTools {
    /// Makes the background transparent. Plain backdrops (a signature on paper, a logo on white)
    /// are keyed out by color, which keeps thin strokes; photos use on-device subject detection.
    public static func removeBackground(_ image: CGImage) throws -> CGImage {
        if let backdrop = Images.plainBackground(image) {
            return Images.removePlainBackground(image, color: backdrop)
        }
        return try removeSubjectBackground(image)
    }

    /// Cuts out the main subject and returns it on a transparent background.
    public static func removeSubjectBackground(_ image: CGImage) throws -> CGImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let observation = request.results?.first else {
            throw KumquatError.noSubject
        }
        let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false)
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let out = Images.ciContext.createCGImage(ci, from: ci.extent) else { throw KumquatError.unsupported("Background removal") }
        return out
    }

    /// Recognizes printed and handwritten text, in reading order.
    public static func recognizeText(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }
}
