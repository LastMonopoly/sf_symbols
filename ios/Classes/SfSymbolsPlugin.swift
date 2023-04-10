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
            let texture = SfSymbolTexture(name: "ChatGPT")
            let id = Self.textureRegistry?.register(texture)
            guard let id = id else {
                result([idKey: -1])
                return
            }

            print("id is \(id)")
            print("num of textures \(Self.textureMap.count)")
            Self.textureMap[id] = texture
            result([idKey: id])

        case "render":
            guard let textureId = (call.arguments as? NSDictionary)?[idKey] as? Int64 else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "url is null or textureID is null", details: nil))
                return
            }

            let cgSize = Self.textureMap[textureId]?.render()
            var size = [String: Double]()
            size["width"] = cgSize?.width ?? 0
            size["height"] = cgSize?.height ?? 0
            result(size)

        case "dispose":
            guard let textureId = (call.arguments as? NSDictionary)?[idKey] as? Int64 else {
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

    init(name: String) {
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(
                pointSize: 100,
                weight: UIImage.SymbolWeight(rawValue: 9) ?? .regular)

            self.image = UIImage(systemName: "airplane", withConfiguration: config)?
                .withTintColor(.magenta)
        } else {
            self.image = nil
        }
    }

    func render() -> CGSize? {
        guard let uiImage = image else { return nil }

        self.pixelBuffer = uiImage.convertToBuffer()
        print(uiImage.size)
        print(uiImage.scale)

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
