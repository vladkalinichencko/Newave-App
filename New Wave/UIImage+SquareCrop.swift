import UIKit

extension UIImage {
    /// Crops the image to a centered 1:1 square without scaling.
    func croppedToSquare() -> UIImage {
        let side = min(size.width, size.height)
        guard side > 0 else { return self }

        let originX = (size.width - side) / 2.0
        let originY = (size.height - side) / 2.0
        let cropRect = CGRect(
            x: originX * scale,
            y: originY * scale,
            width: side * scale,
            height: side * scale
        )

        guard let cgImage = cgImage?.cropping(to: cropRect) else {
            return self
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}
