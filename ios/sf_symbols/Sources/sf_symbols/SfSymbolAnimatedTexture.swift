import Flutter
import UIKit

/// A symbol running one of the SF Symbols effects, redrawn every frame.
///
/// Core Animation only advances animations for layers that are part of a
/// window's render tree, so the image view is parked far off screen inside the
/// app's own window rather than kept detached — a detached view simply never
/// animates. Each display link tick draws the view's layer into a pooled pixel
/// buffer and tells the engine a new frame is ready.
@available(iOS 17.0, *)
final class SfSymbolAnimatedTexture: NSObject, FlutterTexture {
    private let imageView: UIImageView
    private let host: UIView
    private let buffers: SfSymbolBufferPool
    private let fallbackColor: UIColor

    private weak var registry: FlutterTextureRegistry?
    private var textureId: Int64 = 0
    private var displayLink: CADisplayLink?

    private let lock = NSLock()
    private var pixelBuffer: CVPixelBuffer?

    let size: CGSize

    init?(request: SfSymbolImage.Request, effect: String, repeats: Bool) {
        guard let image = SfSymbolImage.make(request) else { return nil }
        guard let window = Self.hostWindow() else { return nil }

        let scale = window.screen.scale
        guard let buffers = SfSymbolBufferPool(size: image.size, scale: scale) else {
            return nil
        }

        self.size = image.size
        self.buffers = buffers
        self.fallbackColor = request.fallbackColor

        imageView = UIImageView(image: image)
        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageView.tintColor = request.fallbackColor
        // Effects such as bounce move the symbol beyond its own box.
        imageView.clipsToBounds = false

        host = UIView(frame: CGRect(
            x: -10_000,
            y: -10_000,
            width: image.size.width,
            height: image.size.height))
        host.clipsToBounds = false
        host.isUserInteractionEnabled = false
        host.addSubview(imageView)
        window.addSubview(host)

        super.init()

        add(effect: effect, repeats: repeats)
    }

    /// Starts drawing. Separate from init because the texture id only exists
    /// once the registry has taken the texture.
    func start(registry: FlutterTextureRegistry, textureId: Int64) {
        self.registry = registry
        self.textureId = textureId

        renderFrame()

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(pause),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        center.addObserver(
            self,
            selector: #selector(resume),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        NotificationCenter.default.removeObserver(self)
        host.removeFromSuperview()
    }

    @objc private func pause() { displayLink?.isPaused = true }
    @objc private func resume() { displayLink?.isPaused = false }

    @objc private func tick() {
        renderFrame()
        registry?.textureFrameAvailable(textureId)
    }

    private func renderFrame() {
        let layer = imageView.layer
        let buffer = buffers.draw { context in
            context.setFillColor(self.fallbackColor.cgColor)
            // The effect updates the layer's contents rather than animating a
            // Core Animation property, so the model layer already carries the
            // current frame and there is no need for presentation().
            layer.render(in: context)
        }
        guard let buffer = buffer else { return }

        lock.lock()
        pixelBuffer = buffer
        lock.unlock()
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let pixelBuffer = pixelBuffer else { return nil }
        return Unmanaged<CVPixelBuffer>.passRetained(pixelBuffer)
    }

    private func add(effect: String, repeats: Bool) {
        let options: SymbolEffectOptions = repeats ? .repeating : .default

        switch effect {
        case "bounce":
            imageView.addSymbolEffect(.bounce, options: options)
        case "pulse":
            imageView.addSymbolEffect(.pulse, options: options)
        case "variableColor":
            imageView.addSymbolEffect(.variableColor.iterative, options: options)
        case "scale":
            imageView.addSymbolEffect(.scale.up, options: options)
        case "wiggle":
            if #available(iOS 18.0, *) {
                imageView.addSymbolEffect(.wiggle, options: options)
            }
        case "rotate":
            if #available(iOS 18.0, *) {
                imageView.addSymbolEffect(.rotate, options: options)
            }
        case "breathe":
            if #available(iOS 18.0, *) {
                imageView.addSymbolEffect(.breathe, options: options)
            }
        default:
            break
        }
    }

    private static func hostWindow() -> UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return windows.first { $0.isKeyWindow } ?? windows.first
    }
}
