import Flutter
import UIKit

public class SfSymbolsPlugin: NSObject, FlutterPlugin {
    static var textureRegistry: FlutterTextureRegistry?
    static var textureMap: [Int64: SfSymbolTexture] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "sf_symbols", binaryMessenger: registrar.messenger())
        let instance = SfSymbolsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        self.textureRegistry = registrar.textures()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let idKey = "textureId"

        switch call.method {
        case "init":
            guard let name = (call.arguments as? [String: Any])?["name"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "name is invalid", details: nil))
                return
            }
            guard let weight = (call.arguments as? [String: Any])?["weight"] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "weight is invalid", details: nil))
                return
            }
            guard let size = (call.arguments as? [String: Any])?["size"] as? CGFloat else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "size is invalid", details: nil))
                return
            }

            guard let hexColor = (call.arguments as? [String: Any])?["color"] as? String,
                  let color = UIColor(hex: hexColor)
            else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "color is invalid", details: nil))
                return
            }

            let texture = SfSymbolTexture(name: name, weight: weight, color: color, size: size)
            let id = Self.textureRegistry?.register(texture)
            guard let id = id else {
                result(nil)
                return
            }

            Self.textureMap[id] = texture
            result([idKey: id])

        case "render":
            guard let textureId = (call.arguments as? [String: Any])?[idKey] as? Int64 else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "url is null or textureID is null", details: nil))
                return
            }

            let cgSize = Self.textureMap[textureId]?.render()
            var size = [String: Double]()
            size["width"] = cgSize?.width ?? 0
            size["height"] = cgSize?.height ?? 0
            result(size)

        case "dispose":
            guard let textureId = (call.arguments as? [String: Any])?[idKey] as? Int64 else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "textureID is null", details: nil))
                return
            }
            Self.textureRegistry?.unregisterTexture(textureId)
            Self.textureMap.removeValue(forKey: textureId)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

class SfSymbolTexture: NSObject, FlutterTexture {
    let image: UIImage?
    var pixelBuffer: CVPixelBuffer?

    init(name: String, weight: Int, color: UIColor, size: CGFloat) {
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(
                pointSize: size,
                weight: UIImage.SymbolWeight(rawValue: weight) ?? .regular)

            self.image = UIImage(systemName: name, withConfiguration: config)?
                .withTintColor(color)
        } else {
            self.image = nil
        }
    }

    func render() -> CGSize? {
        guard let uiImage = image else { return nil }

        self.pixelBuffer = uiImage.convertToBuffer()

        return uiImage.size
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = pixelBuffer else {
            return nil
        }
        return Unmanaged<CVPixelBuffer>.passRetained(pixelBuffer)
    }
}

extension UIImage {
    func convertToBuffer() -> CVPixelBuffer? {
        let width = self.size.width * self.scale
        let height = self.size.height * self.scale

        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        ] as [CFString: Any] as CFDictionary

        var pixelBuffer: CVPixelBuffer?

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(width),
            Int(height),
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer)

        guard status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        let context = CGContext(
            data: pixelData,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        context?.translateBy(x: 0, y: height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
}

public extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    b = CGFloat((hexNumber & 0x000000ff) >> 0) / 255
                    a = CGFloat((hexNumber & 0xff000000) >> 24) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}
