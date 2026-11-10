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
    #expect(try read(["--plain"]).source == .clipboard)
    #expect(try read(["-"]).source == .standardInput)
    #expect(try read(["notes.txt"]).source == .file("notes.txt"))
    // After "--" a leading dash is a file name, but "-" still means stdin, as in cat.
    #expect(try read(["--", "-notes.txt"]).source == .file("-notes.txt"))
    #expect(try read(["--", "-"]).source == .standardInput)
    #expect(try read(["--", "--plain"]).mode == .markdown)
}

@Test func markdownUnlessPlain() throws {
    #expect(try read([]).mode == .markdown)
    #expect(try read(["-"]).mode == .markdown)
    #expect(try read(["notes.txt"]).mode == .markdown)
    #expect(try read(["--plain"]).mode == .plain)
    #expect(try read(["a.md", "--plain"]).mode == .plain)
}

@Test func fontIsParsed() throws {
    #expect(try read(["--font", "Charter"]).fontName == "Charter")
    #expect(try read([]).fontName == nil)
}

@Test func helpWinsOverLaterErrors() throws {
    #expect(try Options.parse(["-h", "--bogus"]) == .help)
    #expect(try Options.parse(["a.txt", "--help"]) == .help)
}

@Test(arguments: [
    (["a", "b"], "only one file may be given"),
    (["-", "a"], "only one file may be given"),
    (["--", "a", "b"], "only one file may be given"),
    (["--font"], "--font requires a value"),
    (["-x"], "unknown option -x"),
])
func invalidArgumentsAreRejected(_ args: [String], _ message: String) {
    #expect(usageError(args) == message)
}
