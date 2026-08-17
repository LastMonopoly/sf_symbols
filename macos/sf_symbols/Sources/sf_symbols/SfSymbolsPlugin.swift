import AppKit
import FlutterMacOS

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
    /// The Flutter view, whose window hosts the animating symbols.
    private weak var view: NSView?
    private var textureMap: [Int64: SfSymbolRenderable] = [:]

    init(textureRegistry: FlutterTextureRegistry, view: NSView?) {
        self.textureRegistry = textureRegistry
        self.view = view
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "sf_symbols",
            binaryMessenger: registrar.messenger)
        let instance = SfSymbolsPlugin(
            textureRegistry: registrar.textures,
            view: registrar.view)
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
            result(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)

        case "effectsSupported":
            if #available(macOS 15.0, *) {
                result("full")
            } else if #available(macOS 14.0, *) {
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

        if let effect = effect, #available(macOS 14.0, *) {
            if let animated = SfSymbolAnimatedTexture(
                request: request,
                effect: effect,
                repeats: repeats,
                window: view?.window
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
    private let image: NSImage
    private let fallbackColor: NSColor
    private let isMulticolor: Bool
    private var pixelBuffer: CVPixelBuffer?

    init?(request: SfSymbolImage.Request) {
        guard let image = SfSymbolImage.make(request) else { return nil }
        self.image = image
        self.fallbackColor = request.fallbackColor
        self.isMulticolor = request.renderingMode == "multicolor"
        super.init()
    }

    func render() -> CGSize {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        pixelBuffer = image.convertToBuffer(
            templateColor: fallbackColor,
            scale: scale,
            recolorUndefined: isMulticolor)
        return image.size
    }

    func attach(registry: FlutterTextureRegistry, textureId: Int64) {}
    func detach() {}

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        return Unmanaged<CVPixelBuffer>.passRetained(pixelBuffer)
    }
}

@available(macOS 14.0, *)
extension SfSymbolAnimatedTexture: SfSymbolRenderable {
    func render() -> CGSize { size }

    func attach(registry: FlutterTextureRegistry, textureId: Int64) {
        start(registry: registry, textureId: textureId)
    }

    func detach() { stop() }
}

extension NSImage {
    func convertToBuffer(
        templateColor: NSColor,
        scale: CGFloat,
        recolorUndefined: Bool
    ) -> CVPixelBuffer? {
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

        let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.scaleBy(x: scale, y: scale)

        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        draw(in: bounds)
        // A template symbol — monochrome, or one with no variant for the
        // requested rendering mode — draws as an alpha mask, so it has to be
        // filled with the color. Symbols carrying their own colors are left be.
        if isTemplate {
            templateColor.set()
            bounds.fill(using: .sourceAtop)
        }
        NSGraphicsContext.current = previous

        // A multicolor symbol is not a template, so the fill above skips it and
        // the layers its variant leaves undefined need painting one by one.
        if recolorUndefined, let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            recolorUndefinedLayers(
                baseAddress: base,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                width: width,
                height: height,
                to: templateColor)
        }

        return pixelBuffer
    }
}
