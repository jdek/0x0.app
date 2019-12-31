import Cocoa

extension URL {
    func mimeType() -> String {
        let pathExtension = self.pathExtension
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }
}

class DragArea: NSView {
    let supportedTypes: [NSPasteboard.PasteboardType] = [.fileURL] // [.fileURL, .string, .URL]

    func uploadFile(_ pasteboard: NSPasteboardItem) {
        let boundary = NSUUID().uuidString
        var request = URLRequest(url: URL(string: "https://0x0.st")!)
        request.httpMethod = "POST"

        if let url = pasteboard.string(forType: .fileURL) {
            let fileurl = URL(string: url)!
            let ext = fileurl.pathExtension
            print("Uploading file.\(ext) to 0x0.st...")

            var data = "--\(boundary)\r\n".data(using: .utf8)!
            data += "Content-Disposition: form-data; name=\"file\"; filename=\"file.\(ext)\"\r\n".data(using: .utf8)!
            data += "Content-Type: \(fileurl.mimeType())\r\n".data(using: .utf8)!
            data += "\r\n".data(using: .utf8)!
            data += NSData(contentsOf: fileurl)!
            data += "\r\n".data(using: .utf8)!
            data += "--\(boundary)--\r\n".data(using: .utf8)!

            let urlConfig = URLSessionConfiguration.default
            urlConfig.httpAdditionalHeaders = ["Content-Type": "multipart/form-data; boundary=\(boundary)"]

            let session = Foundation.URLSession(configuration: urlConfig)
            session.uploadTask(with: request, from: data, completionHandler: {(data, response, error) in
                if let response = response as? HTTPURLResponse, let d: Data = data, error == nil {
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
    }

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
         if let items = sender.draggingPasteboard.pasteboardItems {
            let item = items[0]
            if let type = item.types.first(where: { supportedTypes.contains($0) }) {
                DispatchQueue.main.async {
                    switch type {
                    // case .URL:
                    //     print("got url")
                    //     break
                    // case .string:
                    //     print("got string")
                    //     break
                    case .fileURL:
                        self.uploadFile(item)
                        break
                    default:
                        break
                    }
                }
            } else {
                // We handle all the types which we register, so if we're
                // getting different pasteboard types from the events then
                // something is going wrong.
                fatalError()
            }
            return true
        }
        return false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!

    func applicationWillFinishLaunching(_ notification: Notification) {
        app.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusBarItem.button {
            button.title = "0x0"
            let drag = DragArea(frame: button.frame)
            button.addSubview(drag)
        }

        let statusBarMenu = NSMenu()

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
