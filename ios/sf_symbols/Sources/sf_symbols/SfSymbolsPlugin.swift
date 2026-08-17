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
            guard let hexColor = arguments["color"] as? String,
                  let color = UIColor(hex: hexColor)
            else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "color is invalid", details: nil))
                return
            }

            guard let texture = SfSymbolTexture(
                name: name,
                weight: weight,
                color: color,
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

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

class SfSymbolTexture: NSObject, FlutterTexture {
    private let image: UIImage
    private var pixelBuffer: CVPixelBuffer?

    init?(name: String, weight: Int, color: UIColor, size: CGFloat) {
        let config = UIImage.SymbolConfiguration(
            pointSize: size,
            weight: UIImage.SymbolWeight(rawValue: weight) ?? .regular)

        guard let image = UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        else {
            return nil
        }

        self.image = image
        super.init()
    }

    /// Renders the symbol into a pixel buffer, returning its size in points.
    func render() -> CGSize {
        pixelBuffer = image.convertToBuffer()
        return image.size
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        return Unmanaged<CVPixelBuffer>.passRetained(pixelBuffer)
    }
}

extension UIImage {
    func convertToBuffer() -> CVPixelBuffer? {
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
