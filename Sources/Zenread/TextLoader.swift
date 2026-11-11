import AppKit
import ReaderCore

/// Reads the text to display from a file, standard input or the clipboard,
/// detecting the encoding of file and stdin bytes where it can.
enum TextLoader {
    enum LoadError: Error, CustomStringConvertible {
        case unreadable(String, reason: String)
        case undecodable(String)
        case emptyClipboard

        var description: String {
            switch self {
            case .unreadable(let p, let reason): return "cannot read \(p): \(reason)"
            case .undecodable(let p): return "cannot decode \(p) as text"
            case .emptyClipboard: return "the clipboard holds no text"
            }
        }
    }

    @MainActor
    static func load(_ source: Source) throws -> String {
        switch source {
        case .file(let path):
            do {
                return try decode(Data(contentsOf: URL(fileURLWithPath: path)), name: path)
            } catch let error as CocoaError {
                throw LoadError.unreadable(path, reason: reason(error))
            }
        case .standardInput:
            return try decode(
                FileHandle.standardInput.readDataToEndOfFile(), name: "standard input")
        case .clipboard:
            // Text flavours only: a copied file or image has no string and is reported as empty.
            guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
                throw LoadError.emptyClipboard
            }
            return text
        }
    }

    /// The POSIX reason ("No such file or directory") rather than Foundation's sentence,
    /// to match how other command-line tools report it.
    private static func reason(_ error: CocoaError) -> String {
        if let posix = error.userInfo[NSUnderlyingErrorKey] as? NSError,
            posix.domain == NSPOSIXErrorDomain
        {
            return String(cString: strerror(Int32(posix.code)))
        }
        return error.localizedDescription
    }

    private static func decode(_ data: Data, name: String) throws -> String {
        // UTF-8 first (the overwhelmingly common case), then let Foundation
        // sniff for BOMs / legacy encodings, then a lossy Latin-1 fallback so
        // we always show *something* rather than failing on a stray byte.
        if let s = String(data: data, encoding: .utf8) { return s }
        var converted: NSString?
        var usedLossy: ObjCBool = false
        let rc = NSString.stringEncoding(
            for: data, encodingOptions: nil, convertedString: &converted,
            usedLossyConversion: &usedLossy)
        if rc != 0, let converted { return converted as String }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        throw LoadError.undecodable(name)
    }
}
