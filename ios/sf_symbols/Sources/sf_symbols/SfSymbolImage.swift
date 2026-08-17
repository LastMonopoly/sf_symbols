import UIKit

/// Builds the `UIImage` for a symbol configuration sent from Dart.
enum SfSymbolImage {
    struct Request {
        let name: String
        let weight: Int
        let scale: Int
        let colors: [UIColor]
        let renderingMode: String
        let variableValue: Double?
        let size: CGFloat

        /// Drawn with if the symbol turns out to be a template image, which
        /// happens when it has no variant for the requested rendering mode.
        /// Without it such a symbol would draw in the context's default black.
        var fallbackColor: UIColor { colors.first ?? .label }
    }

    static func configuration(for request: Request) -> UIImage.SymbolConfiguration {
        var configuration = UIImage.SymbolConfiguration(
            pointSize: request.size,
            weight: UIImage.SymbolWeight(rawValue: request.weight) ?? .regular,
            scale: UIImage.SymbolScale(rawValue: request.scale) ?? .medium)

        // Layer colors are part of the configuration, not of the drawing
        // context, so they have to be applied before the image is created.
        switch request.renderingMode {
        case "hierarchical":
            if let color = request.colors.first {
                configuration = configuration.applying(
                    UIImage.SymbolConfiguration(hierarchicalColor: color))
            }
        case "palette":
            if !request.colors.isEmpty {
                configuration = configuration.applying(
                    UIImage.SymbolConfiguration(paletteColors: request.colors))
            }
        case "multicolor":
            configuration = configuration.applying(
                UIImage.SymbolConfiguration.preferringMulticolor())
        default:
            break
        }

        return configuration
    }

    static func make(_ request: Request) -> UIImage? {
        let configuration = configuration(for: request)

        var symbol: UIImage?
        if #available(iOS 16.0, *), let variableValue = request.variableValue {
            symbol = UIImage(
                systemName: request.name,
                variableValue: variableValue,
                configuration: configuration)
        } else {
            symbol = UIImage(systemName: request.name, withConfiguration: configuration)
        }
        guard let symbol = symbol else { return nil }

        if request.renderingMode == "monochrome", let color = request.colors.first {
            // Baked in, so drawing does not fall back to the context's fill color.
            return symbol.withTintColor(color, renderingMode: .alwaysOriginal)
        }
        // Keep the image exactly as configured: re-wrapping it, even with
        // `withRenderingMode(.alwaysOriginal)`, discards the hierarchical and
        // palette colors carried by the symbol configuration.
        return symbol
    }

    static func request(from arguments: [String: Any]) -> Request? {
        guard let name = arguments["name"] as? String,
              let weight = (arguments["weight"] as? NSNumber)?.intValue,
              let size = (arguments["size"] as? NSNumber)?.doubleValue, size > 0
        else { return nil }

        let hexColors = arguments["colors"] as? [String] ?? []
        let colors = hexColors.compactMap { UIColor(hex: $0) }
        guard colors.count == hexColors.count else { return nil }

        return Request(
            name: name,
            weight: weight,
            scale: (arguments["scale"] as? NSNumber)?.intValue ?? 2,
            colors: colors,
            renderingMode: arguments["renderingMode"] as? String ?? "monochrome",
            variableValue: (arguments["variableValue"] as? NSNumber)?.doubleValue,
            size: CGFloat(size))
    }
}

/// Recycles pixel buffers for a texture that redraws every frame.
///
/// A pool hands back only buffers nothing else still holds, so a frame being
/// read by the engine is never drawn over.
final class SfSymbolBufferPool {
    private let pool: CVPixelBufferPool
    let pixelWidth: Int
    let pixelHeight: Int
    let scale: CGFloat

    init?(size: CGSize, scale: CGFloat) {
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())
        guard width > 0, height > 0 else { return nil }

        let bufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            nil,
            bufferAttributes as CFDictionary,
            &pool)
        guard status == kCVReturnSuccess, let created = pool else { return nil }

        self.pool = created
        self.pixelWidth = width
        self.pixelHeight = height
        self.scale = scale
    }

    /// Draws into a fresh buffer. The closure gets a context already flipped to
    /// UIKit's top-down orientation and scaled to points.
    func draw(_ body: (CGContext) -> Void) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
            == kCVReturnSuccess, let pixelBuffer = buffer
        else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }

        // Buffers come out of the pool dirty, so start from transparent.
        context.clear(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        // CoreGraphics draws bottom-up, UIKit top-down.
        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: scale, y: -scale)

        body(context)
        return pixelBuffer
    }
}
