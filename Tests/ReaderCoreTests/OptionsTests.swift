import ReaderCore
import Testing

private struct HelpInvocation: Error {}

/// The parsed options; throws (failing the test) for a usage error or help.
private func read(_ args: [String]) throws -> Options {
    guard case .read(let options) = try Options.parse(args) else { throw HelpInvocation() }
    return options
}

private func usageError(_ args: [String]) -> String? {
    do {
        _ = try Options.parse(args)
        return nil
    } catch {
        return error.description
    }
}

@Test func sourceComesFromFileStdinOrClipboard() throws {
    #expect(try read([]).source == .clipboard)
    #expect(try read(["--size", "18"]).source == .clipboard)
    #expect(try read(["-"]).source == .standardInput)
    #expect(try read(["notes.txt"]).source == .file("notes.txt"))
    // After "--" a leading dash is a file name, but "-" still means stdin, as in cat.
    #expect(try read(["--", "-notes.txt"]).source == .file("-notes.txt"))
    #expect(try read(["--", "-"]).source == .standardInput)
    #expect(try read(["--", "--plain"]).mode == .plain(reflow: true))
}

@Test func modeFollowsExtensionOnlyForFiles() throws {
    #expect(try read(["a.MD"]).mode == .markdown)
    #expect(try read(["a.md.txt"]).mode == .plain(reflow: true))
    #expect(try read(["--plain", "a.md"]).mode == .plain(reflow: true))
    #expect(try read([]).mode == .plain(reflow: true))
    #expect(try read(["-"]).mode == .plain(reflow: true))
    #expect(try read(["--markdown"]).mode == .markdown)
    #expect(try read(["--no-reflow"]).mode == .plain(reflow: false))
    #expect(try read(["--no-reflow", "a.md"]).mode == .markdown)
}

@Test func valuesAreParsed() throws {
    let o = try read(["--font", "Charter", "--size", "22.5", "--opacity", "0", "--no-blur"])
    #expect(o.fontName == "Charter")
    #expect(o.fontSize == 22.5)
    #expect(o.opacity == 0)
    #expect(!o.blur)
}

@Test func helpWinsOverLaterErrors() throws {
    #expect(try Options.parse(["-h", "--bogus"]) == .help)
    #expect(try Options.parse(["a.txt", "--help"]) == .help)
}

@Test(arguments: [
    (["a", "b"], "only one file may be given"),
    (["-", "a"], "only one file may be given"),
    (["--", "a", "b"], "only one file may be given"),
    (["--markdown", "--plain"], "--markdown and --plain are mutually exclusive"),
    (["--size", "inf"], "--size requires a positive number"),
    (["--size", "0"], "--size requires a positive number"),
    (["--size"], "--size requires a positive number"),
    (["--opacity", "1.5"], "--opacity requires a number between 0 and 1"),
    (["--font"], "--font requires a value"),
    (["-x"], "unknown option -x"),
])
func invalidArgumentsAreRejected(_ args: [String], _ message: String) {
    #expect(usageError(args) == message)
}
