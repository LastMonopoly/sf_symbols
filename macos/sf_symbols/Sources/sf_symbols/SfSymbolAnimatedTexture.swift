import AppKit
import FlutterMacOS

/// A symbol running one of the SF Symbols effects, redrawn every frame.
///
/// Core Animation only advances animations for layers that are part of a
/// window's render tree, so the image view is parked far outside the window's
/// bounds rather than kept detached — a detached view simply never animates.
/// Each display link tick draws the view's layer into a pooled pixel buffer and
/// tells the engine a new frame is ready.
@available(macOS 14.0, *)
final class SfSymbolAnimatedTexture: NSObject, FlutterTexture {
    private let imageView: NSImageView
    private let host: NSView
    private let buffers: SfSymbolBufferPool
    private let fallbackColor: NSColor
    /// Set for multicolor symbols only; see `recolorUndefinedLayers`.
    private let undefinedLayerColor: NSColor?

    private weak var registry: FlutterTextureRegistry?
    private var textureId: Int64 = 0
    private var displayLink: CADisplayLink?
    private weak var window: NSWindow?

    private let lock = NSLock()
    private var pixelBuffer: CVPixelBuffer?

    let size: CGSize

    init?(request: SfSymbolImage.Request, effect: String, repeats: Bool, window: NSWindow?) {
        guard let image = SfSymbolImage.make(request) else { return nil }
        guard let window = window, let container = window.contentView else { return nil }

        let scale = window.backingScaleFactor
        guard let buffers = SfSymbolBufferPool(size: image.size, scale: scale) else {
            return nil
        }

        self.size = image.size
        self.buffers = buffers
        self.fallbackColor = request.fallbackColor
        self.undefinedLayerColor =
            request.renderingMode == "multicolor" ? request.fallbackColor : nil
        self.window = window

        imageView = NSImageView(frame: CGRect(origin: .zero, size: image.size))
        imageView.image = image
        imageView.imageScaling = .scaleNone
        // Only consulted for template symbols; ones that carry their own colors
        // ignore it.
        imageView.contentTintColor = request.fallbackColor
        imageView.wantsLayer = true

        host = NSView(frame: CGRect(
            x: -10_000,
            y: -10_000,
            width: image.size.width,
            height: image.size.height))
        host.wantsLayer = true
        host.addSubview(imageView)
        container.addSubview(host)

        super.init()

        add(effect: effect, repeats: repeats)
    }

    /// Starts drawing. Separate from init because the texture id only exists
    /// once the registry has taken the texture.
    func start(registry: FlutterTextureRegistry, textureId: Int64) {
        self.registry = registry
        self.textureId = textureId

        renderFrame()

        // CADisplayLink on macOS comes from the view it draws for, so it ticks
        // with the display that view is actually on.
        let link = host.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(occlusionChanged),
            name: NSWindow.didChangeOcclusionStateNotification,
            object: window)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        NotificationCenter.default.removeObserver(self)
        host.removeFromSuperview()
    }

    /// A window the user cannot see — behind another one, or on another Space —
    /// does not deserve frames.
    @objc private func occlusionChanged(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        displayLink?.isPaused = !window.occlusionState.contains(.visible)
    }

    @objc private func tick() {
        renderFrame()
        registry?.textureFrameAvailable(textureId)
    }

    private func renderFrame() {
        guard let layer = imageView.layer else { return }
        let buffer = buffers.draw(recoloringUndefinedLayersTo: undefinedLayerColor) { context in
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
        // Only effects with a natural end honour this: bounce and one cycle of
        // variableColor. pulse, wiggle, rotate and breathe run until removed,
        // and scale simply holds the symbol at its new size.
        let options: SymbolEffectOptions = repeats ? .repeating : .nonRepeating

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
            if #available(macOS 15.0, *) {
                imageView.addSymbolEffect(.wiggle, options: options)
            }
        case "rotate":
            if #available(macOS 15.0, *) {
                imageView.addSymbolEffect(.rotate, options: options)
            }
        case "breathe":
            if #available(macOS 15.0, *) {
                imageView.addSymbolEffect(.breathe, options: options)
            }
        default:
            break
        }
    }
}
