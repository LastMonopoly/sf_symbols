import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Tall enough to show the whole demo without scrolling. Restoring the last
    // size would otherwise win over this.
    self.isRestorable = false
    self.setContentSize(CGSize(width: 820, height: 1000))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
