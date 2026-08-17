import Flutter
import UIKit

public class SfSymbolsPlugin: NSObject, FlutterPlugin {
    private static let idKey = "textureId"

    private let textureRegistry: FlutterTextureRegistry
    private var textureMap: [Int64: SfSymbolTexture] = [:]

    init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "sf_symbols", binaryMessenger: registrar.messenger())
        let instance = SfSymbolsPlugin(textureRegistry: registrar.textures())
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "init":
            guard let name = arguments["name"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "name is invalid", details: nil))
                return
            }
            guard let weight = (arguments["weight"] as? NSNumber)?.intValue else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "weight is invalid", details: nil))
                return
            }
            guard let size = (arguments["size"] as? NSNumber)?.doubleValue, size > 0 else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "size is invalid", details: nil))
                return
            }

            let colors = (arguments["colors"] as? [String] ?? []).compactMap { UIColor(hex: $0) }
            guard colors.count == (arguments["colors"] as? [String] ?? []).count else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "color is invalid", details: nil))
                return
            }

            let renderingMode = arguments["renderingMode"] as? String ?? "monochrome"
            let scale = (arguments["scale"] as? NSNumber)?.intValue ?? 2
            let variableValue = (arguments["variableValue"] as? NSNumber)?.doubleValue

            guard let texture = SfSymbolTexture(
                name: name,
                weight: weight,
                scale: scale,
                colors: colors,
                renderingMode: renderingMode,
                variableValue: variableValue,
                size: CGFloat(size)
            ) else {
                result(FlutterError(code: "UNKNOWN_SYMBOL", message: "no SF Symbol named \(name)", details: nil))
                return
            }

            let id = textureRegistry.register(texture)
            textureMap[id] = texture
            result([Self.idKey: id])

        case "render":
            guard let textureId = (arguments[Self.idKey] as? NSNumber)?.int64Value,
                  let texture = textureMap[textureId]
            else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "textureId is invalid", details: nil))
                return
            }
            let cgSize = texture.render()
            textureRegistry.textureFrameAvailable(textureId)
            result(["width": Double(cgSize.width), "height": Double(cgSize.height)])

        case "dispose":
            guard let textureId = (arguments[Self.idKey] as? NSNumber)?.int64Value else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "textureId is invalid", details: nil))
                return
            }
            textureRegistry.unregisterTexture(textureId)
            textureMap.removeValue(forKey: textureId)
            result(nil)

        case "available":
            guard let name = arguments["name"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "name is invalid", details: nil))
                return
            }
            result(UIImage(systemName: name) != nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

class SfSymbolTexture: NSObject, FlutterTexture {
    private let image: UIImage
    /// Drawn with, if `image` turns out to be a template image — which happens
    /// when a symbol has no variant for the requested rendering mode. Without
    /// it such a symbol would draw in the context's default black.
    private let fallbackColor: UIColor
    private var pixelBuffer: CVPixelBuffer?

    init?(
        name: String,
        weight: Int,
        scale: Int,
        colors: [UIColor],
        renderingMode: String,
        variableValue: Double?,
        size: CGFloat
    ) {
        var configuration = UIImage.SymbolConfiguration(
            pointSize: size,
            weight: UIImage.SymbolWeight(rawValue: weight) ?? .regular,
            scale: UIImage.SymbolScale(rawValue: scale) ?? .medium)

        // Layer colors are part of the configuration, not of the drawing
        // context, so they have to be applied before the image is created.
        switch renderingMode {
        case "hierarchical":
            if let color = colors.first {
                configuration = configuration.applying(
                    UIImage.SymbolConfiguration(hierarchicalColor: color))
            }
        case "palette":
            if !colors.isEmpty {
                configuration = configuration.applying(
                    UIImage.SymbolConfiguration(paletteColors: colors))
            }
        case "multicolor":
            configuration = configuration.applying(
                UIImage.SymbolConfiguration.preferringMulticolor())
        default:
            break
        }

        var symbol: UIImage?
        if #available(iOS 16.0, *), let variableValue = variableValue {
            symbol = UIImage(systemName: name, variableValue: variableValue, configuration: configuration)
        } else {
            symbol = UIImage(systemName: name, withConfiguration: configuration)
        }
        guard let symbol = symbol else { return nil }

        if renderingMode == "monochrome", let color = colors.first {
            // Baked in, so drawing does not fall back to the context's fill color.
            self.image = symbol.withTintColor(color, renderingMode: .alwaysOriginal)
        } else {
            // Keep the image exactly as configured: re-wrapping it, even with
            // `withRenderingMode(.alwaysOriginal)`, discards the hierarchical
            // and palette colors carried by the symbol configuration.
            self.image = symbol
        }
        self.fallbackColor = colors.first ?? .label
        super.init()
    }

    /// Renders the symbol into a pixel buffer, returning its size in points.
    func render() -> CGSize {
        pixelBuffer = image.convertToBuffer(templateColor: fallbackColor)
        return image.size
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        return Unmanaged<CVPixelBuffer>.passRetained(pixelBuffer)
    }
}

extension UIImage {
    func convertToBuffer(templateColor: UIColor) -> CVPixelBuffer? {
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())
        guard width > 0, height > 0 else { return nil }

        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        ] as [CFString: Any] as CFDictionary

        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes,
            &buffer)

        guard status == kCVReturnSuccess, let pixelBuffer = buffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else {
            return nil
        }

        // CoreGraphics draws bottom-up, UIKit top-down.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)

        // Only consulted for template images; images that carry their own
        // colors ignore it.
        context.setFillColor(templateColor.cgColor)

        UIGraphicsPushContext(context)
        draw(in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        UIGraphicsPopContext()

        return pixelBuffer
    }
}

public extension UIColor {
    /// Creates a color from an `#AARRGGBB` string.
    convenience init?(hex: String) {
        guard hex.hasPrefix("#") else { return nil }

        let hexColor = String(hex.dropFirst())
        guard hexColor.count == 8 else { return nil }

        var hexNumber: UInt64 = 0
        let scanner = Scanner(string: hexColor)
        guard scanner.scanHexInt64(&hexNumber) else { return nil }

        self.init(
            red: CGFloat((hexNumber & 0x00ff_0000) >> 16) / 255,
            green: CGFloat((hexNumber & 0x0000_ff00) >> 8) / 255,
            blue: CGFloat((hexNumber & 0x0000_00ff) >> 0) / 255,
            alpha: CGFloat((hexNumber & 0xff00_0000) >> 24) / 255)
    }
}
