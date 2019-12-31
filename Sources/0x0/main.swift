import Cocoa

extension URL {
    var mimeType: String {
        get {
            let pathExtension = self.pathExtension
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue() {
                if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                    return mimetype as String
                }
            }
            return "application/octet-stream"
        }
    }
}

class DragArea: NSView {
    let supportedTypes: [NSPasteboard.PasteboardType] = [.fileURL, .string] // .URL

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        registerForDraggedTypes(supportedTypes)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // We want any data which can be read
        return NSDragOperation.copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // As long as we only have one, we're gonna take it.
        if sender.draggingPasteboard.pasteboardItems?.count == 1 {
            return true
        }
        return false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let items = sender.draggingPasteboard.pasteboardItems,
           let type = items[0].types.first(where: { supportedTypes.contains($0) }),
           // Should probably do this elsewhere but whatever.
           let delegate = app.delegate as? AppDelegate
        {
            let pasteboardItem = items[0]
            switch type {
                // case .URL:
                //     print("got url")
                //     break
            case .string:
                if let data = pasteboardItem.data(forType: .string) {
                    delegate.upload(data as NSData, name: "file.txt", mime: "text/plain")
                }
                break
            case .fileURL:
                if let url = pasteboardItem.string(forType: .fileURL),
                   let fileurl = URL(string: url),
                   let data = NSData(contentsOf: fileurl)
                {
                    delegate.upload(data, name: fileurl.lastPathComponent, mime: fileurl.mimeType)
                }
                break
            default:
                // Will never get here
                break
            }
            return true
        }

        // We handle all the types which we register, so if we're
        // getting different pasteboard types from the events then
        // something is going wrong.
        fatalError()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!

    let backends = ["0x0"]
    var _backend: String = ""
    var backend: String {
        set {
            if backends.contains(newValue) {
                _backend = newValue
                UserDefaults.standard.set(newValue, forKey: "backend")
            }
        }
        get {
            return _backend
        }
    }

    @objc func setBackend(_ sender: NSMenuItem) {
        if sender.state == .on {
            return
        }
        if let menu = sender.menu {
            for menuitem in menu.items {
                if menuitem.title == sender.title {
                    self.backend = menuitem.title
                    menuitem.state = .on
                } else {
                    menuitem.state = .off
                }
            }
        }
    }

    func upload(_ data: NSData, name: String, mime: String) {
        print("Uploading \(name) (\(mime)) to \(backend)...")

        let boundary = NSUUID().uuidString
        var request = URLRequest(url: URL(string: "https://0x0.st")!)
        request.httpMethod = "POST"

        var postData = "--\(boundary)\r\n".data(using: .utf8)!
        postData += "Content-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\n".data(using: .utf8)!
        postData += "Content-Type: \(mime)\r\n".data(using: .utf8)!
        postData += "\r\n".data(using: .utf8)!
        postData += data
        postData += "\r\n".data(using: .utf8)!
        postData += "--\(boundary)--\r\n".data(using: .utf8)!

        let urlConfig = URLSessionConfiguration.default
        urlConfig.httpAdditionalHeaders = ["Content-Type": "multipart/form-data; boundary=\(boundary)"]

        let session = Foundation.URLSession(configuration: urlConfig)
        session.uploadTask(
          with: request,
          from: postData,
          completionHandler:
            {(data, response, error) in
                if let response = response as? HTTPURLResponse,
                   let d: Data = data,
                   error == nil
                {
                    let string1 = String(data: d, encoding: String.Encoding.utf8) ?? "Data could not be printed"
                    print(string1)
                    if response.statusCode == 200 {
                        let pbg = NSPasteboard.general
                        pbg.clearContents()
                        pbg.setString(string1, forType: .string)
                        print("Copied to clipboard!")
                    } else {
                        print(response.statusCode)
                    }
                }
            }).resume()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        app.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusBarItem.button {
            let drag = DragArea(frame: button.frame)
            button.image = NSImage(named: NSImage.shareTemplateName)
            button.addSubview(drag)
        }

        let statusBarMenu = NSMenu()

        let backendMenu = NSMenu()
        let backendMenuItem = NSMenuItem(title: "Backend", action: nil, keyEquivalent: "")

        self.backend = UserDefaults.standard.string(forKey: "backend") ?? backends[0]
        for backend in backends {
            let backendItem = NSMenuItem(title: backend, action: #selector(self.setBackend(_:)), keyEquivalent: "")
            if self.backend == backend {
                backendItem.state = .on
            }
            backendMenu.addItem(backendItem)
        }

        statusBarMenu.addItem(backendMenuItem)
        statusBarMenu.setSubmenu(backendMenu, for: backendMenuItem)

        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(
          withTitle: "Quit",
          action: #selector(NSApplication.terminate(_:)),
          keyEquivalent: "")

        statusBarItem.menu = statusBarMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
