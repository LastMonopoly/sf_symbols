import Flutter
import UIKit

/// Anything the plugin can hand to the engine as a texture.
protocol SfSymbolRenderable: FlutterTexture {
    /// Draws the symbol, returning its size in points.
    func render() -> CGSize
    /// Called once the texture has an id, and again when it is torn down.
    func attach(registry: FlutterTextureRegistry, textureId: Int64)
    func detach()
}

public class SfSymbolsPlugin: NSObject, FlutterPlugin {
    private static let idKey = "textureId"

    private let textureRegistry: FlutterTextureRegistry
    private var textureMap: [Int64: SfSymbolRenderable] = [:]

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
            guard let request = SfSymbolImage.request(from: arguments) else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "invalid symbol request", details: nil))
                return
            }

            guard let texture = makeTexture(request: request, arguments: arguments) else {
                result(FlutterError(
                    code: "UNKNOWN_SYMBOL",
                    message: "no SF Symbol named \(request.name)",
                    details: nil))
                return
            }

            let id = textureRegistry.register(texture)
            textureMap[id] = texture
            texture.attach(registry: textureRegistry, textureId: id)
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
            textureMap.removeValue(forKey: textureId)?.detach()
            textureRegistry.unregisterTexture(textureId)
            result(nil)

        case "available":
            guard let name = arguments["name"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "name is invalid", details: nil))
                return
            }
            result(UIImage(systemName: name) != nil)

        case "effectsSupported":
            if #available(iOS 18.0, *) {
                result("full")
            } else if #available(iOS 17.0, *) {
                result("partial")
            } else {
                result("none")
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func makeTexture(
        request: SfSymbolImage.Request,
        arguments: [String: Any]
    ) -> SfSymbolRenderable? {
        let effect = arguments["effect"] as? String
        let repeats = arguments["effectRepeats"] as? Bool ?? true

        if let effect = effect, #available(iOS 17.0, *) {
            if let animated = SfSymbolAnimatedTexture(
                request: request,
                effect: effect,
                repeats: repeats
            ) {
                return animated
            }
            // No window to animate in yet: fall through to a static symbol
            // rather than showing nothing at all.
        }

        return SfSymbolTexture(request: request)
    }
}

/// A symbol drawn once and held as a single frame.
class SfSymbolTexture: NSObject, SfSymbolRenderable {
    private let image: UIImage
    private let fallbackColor: UIColor
    private var pixelBuffer: CVPixelBuffer?

    init?(request: SfSymbolImage.Request) {
        guard let image = SfSymbolImage.make(request) else { return nil }
        self.image = image
        self.fallbackColor = request.fallbackColor
        super.init()
    }

    func render() -> CGSize {
        pixelBuffer = image.convertToBuffer(templateColor: fallbackColor)
        return image.size
    }

    func attach(registry: FlutterTextureRegistry, textureId: Int64) {}
    func detach() {}

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        return Unmanaged<CVPixelBuffer>.passRetained(pixelBuffer)
    }
}

@available(iOS 17.0, *)
extension SfSymbolAnimatedTexture: SfSymbolRenderable {
    func render() -> CGSize { size }

    func attach(registry: FlutterTextureRegistry, textureId: Int64) {
        start(registry: registry, textureId: textureId)
    }

    func detach() { stop() }
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

        // Only consulted for template images; images that carry their own
        // colors ignore it.
        context.setFillColor(templateColor.cgColor)

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
