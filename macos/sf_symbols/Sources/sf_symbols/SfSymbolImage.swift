import AppKit

/// Builds the `NSImage` for a symbol configuration sent from Dart.
enum SfSymbolImage {
    struct Request {
        let name: String
        let weight: Int
        let scale: Int
        let colors: [NSColor]
        let renderingMode: String
        let variableValue: Double?
        let size: CGFloat

        /// Drawn with if the symbol turns out to be a template image, which
        /// happens when it has no variant for the requested rendering mode.
        /// Without it such a symbol would draw in the context's default black.
        var fallbackColor: NSColor { colors.first ?? .labelColor }
    }

    /// Dart sends UIKit's `UIImage.SymbolWeight` raw values, 1 (ultraLight) to
    /// 9 (black). AppKit takes an `NSFont.Weight` instead.
    private static func fontWeight(_ raw: Int) -> NSFont.Weight {
        switch raw {
        case 1: return .ultraLight
        case 2: return .thin
        case 3: return .light
        case 5: return .medium
        case 6: return .semibold
        case 7: return .bold
        case 8: return .heavy
        case 9: return .black
        default: return .regular
        }
    }

    /// AppKit has no equivalent of UIKit's `unspecified` scale, and its enum
    /// takes any raw value in Swift only to abort deep inside the framework
    /// later, so nothing but the three real ones gets through.
    private static func symbolScale(_ raw: Int) -> NSImage.SymbolScale {
        switch raw {
        case 1: return .small
        case 3: return .large
        default: return .medium
        }
    }

    static func configuration(for request: Request) -> NSImage.SymbolConfiguration {
        var configuration = NSImage.SymbolConfiguration(
            pointSize: request.size,
            weight: fontWeight(request.weight),
            scale: symbolScale(request.scale))

        // Layer colors are part of the configuration, not of the drawing
        // context, so they have to be applied before the image is created.
        switch request.renderingMode {
        case "hierarchical":
            if let color = request.colors.first {
                configuration = configuration.applying(
                    NSImage.SymbolConfiguration(hierarchicalColor: color))
            }
        case "palette":
            if !request.colors.isEmpty {
                configuration = configuration.applying(
                    NSImage.SymbolConfiguration(paletteColors: request.colors))
            }
        case "multicolor":
            configuration = configuration.applying(
                NSImage.SymbolConfiguration.preferringMulticolor())
        default:
            break
        }

        return configuration
    }

    static func make(_ request: Request) -> NSImage? {
        var symbol: NSImage?
        if #available(macOS 13.0, *), let variableValue = request.variableValue {
            symbol = NSImage(
                systemSymbolName: request.name,
                variableValue: variableValue,
                accessibilityDescription: nil)
        } else {
            symbol = NSImage(systemSymbolName: request.name, accessibilityDescription: nil)
        }

        // A configured symbol reports the size the configuration asks for,
        // which is what the widget lays itself out with.
        return symbol?.withSymbolConfiguration(configuration(for: request))
    }

    static func request(from arguments: [String: Any]) -> Request? {
        guard let name = arguments["name"] as? String,
              let weight = (arguments["weight"] as? NSNumber)?.intValue,
              let size = (arguments["size"] as? NSNumber)?.doubleValue, size > 0
        else { return nil }

        let hexColors = arguments["colors"] as? [String] ?? []
        let colors = hexColors.compactMap { NSColor(hex: $0) }
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

/// Paints `color` over the layers a multicolor symbol leaves undefined.
///
/// UIKit draws those from the context's fill color; AppKit draws them black,
/// whatever it was asked for — every way of naming a color in a symbol
/// configuration (`paletteColors`, `hierarchicalColor`) overrides the multicolor
/// variant entirely instead of standing behind it. So the black is fixed up
/// afterwards, which also covers symbols with no multicolor variant at all.
///
/// The buffer must be locked, and is 32BGRA with premultiplied alpha.
func recolorUndefinedLayers(
    baseAddress: UnsafeMutableRawPointer,
    bytesPerRow: Int,
    width: Int,
    height: Int,
    to color: NSColor
) {
    guard let srgb = color.usingColorSpace(.sRGB) else { return }
    let red = UInt32(srgb.redComponent * 255)
    let green = UInt32(srgb.greenComponent * 255)
    let blue = UInt32(srgb.blueComponent * 255)

    for y in 0..<height {
        let row = baseAddress.advanced(by: y * bytesPerRow)
            .assumingMemoryBound(to: UInt8.self)
        for x in 0..<width {
            let pixel = row.advanced(by: x * 4)
            // A layer the variant does define is never pure black: the colors
            // are vivid system ones, and a layer meant to follow the foreground
            // is exactly the one being fixed here.
            guard pixel[0] == 0, pixel[1] == 0, pixel[2] == 0 else { continue }
            let alpha = UInt32(pixel[3])
            guard alpha > 0 else { continue }
            pixel[0] = UInt8(blue * alpha / 255)
            pixel[1] = UInt8(green * alpha / 255)
            pixel[2] = UInt8(red * alpha / 255)
        }
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

    /// Draws into a fresh buffer. The closure gets a context scaled to points
    /// and left in Core Graphics' bottom-up orientation, which is AppKit's too.
    ///
    /// Pass `recoloringUndefinedLayersTo` for a multicolor symbol; see
    /// `recolorUndefinedLayers`.
    func draw(
        recoloringUndefinedLayersTo color: NSColor? = nil,
        _ body: (CGContext) -> Void
    ) -> CVPixelBuffer? {
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
        context.scaleBy(x: scale, y: scale)

        body(context)

        if let color = color, let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            recolorUndefinedLayers(
                baseAddress: base,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                width: pixelWidth,
                height: pixelHeight,
                to: color)
        }

        return pixelBuffer
    }
}

public extension NSColor {
    /// Creates a color from an `#AARRGGBB` string.
    convenience init?(hex: String) {
        guard hex.hasPrefix("#") else { return nil }

        let hexColor = String(hex.dropFirst())
        guard hexColor.count == 8 else { return nil }

        var hexNumber: UInt64 = 0
        let scanner = Scanner(string: hexColor)
        guard scanner.scanHexInt64(&hexNumber) else { return nil }

        self.init(
            srgbRed: CGFloat((hexNumber & 0x00ff_0000) >> 16) / 255,
            green: CGFloat((hexNumber & 0x0000_ff00) >> 8) / 255,
            blue: CGFloat((hexNumber & 0x0000_00ff) >> 0) / 255,
            alpha: CGFloat((hexNumber & 0xff00_0000) >> 24) / 255)
    }
}
