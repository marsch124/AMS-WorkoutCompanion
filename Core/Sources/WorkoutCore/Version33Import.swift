import Foundation

/// One machine found on a web page (3.3, "Import from a web page").
public struct ImportCandidate: Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let imageURL: URL?
    public let alreadyThere: Bool

    public init(id: String, name: String, imageURL: URL?, alreadyThere: Bool) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.alreadyThere = alreadyThere
    }
}

public enum MachineImport {
    static let maxCount = 200
    static let junk = try! NSRegularExpression(
        pattern: "\\b(logo|icon|banner|avatar|arrow|cookie|cookies|flag|payment|instagram|facebook|youtube)\\b|app store|google play",
        options: [.caseInsensitive])

    /// Reads a page and returns the machines it seems to show, in page order.
    public static func candidates(html: String, base: URL, existing: [String]) -> [ImportCandidate] {
        let ns = html as NSString
        let full = NSRange(location: 0, length: ns.length)
        var found: [(pos: Int, name: String, image: URL?)] = []

        // Figures: the caption wins over the alt text.
        var figureRanges: [NSRange] = []
        for m in regex("<figure\\b[^>]*>(.*?)</figure>").matches(in: html, range: full) {
            figureRanges.append(m.range)
            let inner = ns.substring(with: m.range(at: 1))
            let img = firstMatch("<img\\b[^>]*>", in: inner)
            let caption = firstGroup("<figcaption\\b[^>]*>(.*?)</figcaption>", in: inner).map(stripTags)
            let alt = img.flatMap { attribute("alt", in: $0) ?? attribute("title", in: $0) }
            let name = [caption, alt].compactMap { $0 }.map(clean).first { !$0.isEmpty } ?? ""
            found.append((m.range.location, name, img.flatMap { imageURL(in: $0, base: base) }))
        }

        // Plain images outside figures.
        for m in regex("<img\\b[^>]*>").matches(in: html, range: full) {
            if figureRanges.contains(where: { NSLocationInRange(m.range.location, $0) }) { continue }
            let tag = ns.substring(with: m.range)
            let text = attribute("alt", in: tag) ?? attribute("title", in: tag) ?? ""
            found.append((m.range.location, clean(text), imageURL(in: tag, base: base)))
        }

        // JSON-LD.
        let ld = regex("<script\\b[^>]*application/ld\\+json[^>]*>(.*?)</script>")
        for m in ld.matches(in: html, range: full) {
            let body = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            var out: [(String, URL?)] = []
            walk(json, base: base, into: &out)
            for (n, u) in out { found.append((m.range.location, clean(n), u)) }
        }

        found.sort { $0.pos < $1.pos }
        let have = Set(existing.map(key))
        var seen = Set<String>()
        var result: [ImportCandidate] = []
        for item in found {
            let name = item.name
            guard (3...60).contains(name.count), !isJunk(name) else { continue }
            let k = key(name)
            guard seen.insert(k).inserted else { continue }
            result.append(ImportCandidate(id: k, name: name, imageURL: item.image, alreadyThere: have.contains(k)))
            if result.count >= maxCount { break }
        }
        return result
    }

    /// A typed link as a web address: "https://" is added when missing; only http and https.
    public static func normalised(_ typed: String) -> URL? {
        var s = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.contains(" ") else { return nil }
        if !s.contains("://") { s = "https://" + s }
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, host.contains(".") else { return nil }
        return url
    }

    // MARK: - Helpers

    static func key(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    static func isJunk(_ name: String) -> Bool {
        junk.firstMatch(in: name, range: NSRange(location: 0, length: (name as NSString).length)) != nil
    }

    static func regex(_ p: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: p, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }

    static func firstMatch(_ p: String, in s: String) -> String? {
        guard let m = regex(p).firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) else { return nil }
        return (s as NSString).substring(with: m.range)
    }

    static func firstGroup(_ p: String, in s: String) -> String? {
        guard let m = regex(p).firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)),
              m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound else { return nil }
        return (s as NSString).substring(with: m.range(at: 1))
    }

    static func attribute(_ name: String, in tag: String) -> String? {
        let p = "(?<=\\s)" + NSRegularExpression.escapedPattern(for: name) + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>\"']+))"
        guard let m = regex(p).firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)) else { return nil }
        for i in 1...3 where m.range(at: i).location != NSNotFound {
            return (tag as NSString).substring(with: m.range(at: i))
        }
        return nil
    }

    static func imageURL(in tag: String, base: URL) -> URL? {
        var raw = attribute("src", in: tag)
        if raw == nil || raw!.hasPrefix("data:") || raw!.isEmpty { raw = attribute("data-src", in: tag) ?? raw }
        if raw == nil || raw!.hasPrefix("data:") || raw!.isEmpty { raw = attribute("data-lazy-src", in: tag) ?? raw }
        if raw == nil || raw!.hasPrefix("data:") || raw!.isEmpty,
           let set = attribute("srcset", in: tag) ?? attribute("data-srcset", in: tag) {
            raw = set.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) }?
                .split(separator: " ").first.map(String.init)
        }
        guard let r = raw else { return nil }
        return resolve(decodeEntities(r), base: base)
    }

    static func resolve(_ raw: String, base: URL) -> URL? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.lowercased().hasPrefix("data:") else { return nil }
        guard let url = URL(string: s, relativeTo: base)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        if url.pathExtension.lowercased() == "svg" { return nil }
        return url
    }

    static func walk(_ node: Any, base: URL, into out: inout [(String, URL?)]) {
        if let arr = node as? [Any] { for x in arr { walk(x, base: base, into: &out) }; return }
        guard let dict = node as? [String: Any] else { return }
        let types: [String]
        if let t = dict["@type"] as? String { types = [t] } else { types = (dict["@type"] as? [String]) ?? [] }
        if !Set(types).isDisjoint(with: ["Product", "ExerciseEquipment", "ListItem"]),
           let name = dict["name"] as? String {
            out.append((name, imageValue(dict["image"], base: base)))
        }
        for (_, v) in dict where v is [String: Any] || v is [Any] { walk(v, base: base, into: &out) }
    }

    static func imageValue(_ v: Any?, base: URL) -> URL? {
        if let s = v as? String { return resolve(s, base: base) }
        if let d = v as? [String: Any] { return imageValue(d["url"] ?? d["contentUrl"], base: base) }
        if let a = v as? [Any] { return a.lazy.compactMap { imageValue($0, base: base) }.first }
        return nil
    }

    static func stripTags(_ s: String) -> String {
        regex("<[^>]*>").stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: " ")
    }

    static func clean(_ s: String) -> String {
        let decoded = decodeEntities(s).replacingOccurrences(of: "\u{00A0}", with: " ")
        return decoded.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
                     "ndash": "–", "mdash": "—", "rsquo": "’", "lsquo": "‘", "eacute": "é"]
        let re = try! NSRegularExpression(pattern: "&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);")
        let ns = s as NSString
        var out = ""
        var last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let body = ns.substring(with: m.range(at: 1))
            var rep: String?
            if body.hasPrefix("#x") || body.hasPrefix("#X") {
                rep = UInt32(body.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
            } else if body.hasPrefix("#") {
                rep = UInt32(body.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
            } else {
                rep = named[body]
            }
            out += rep ?? ns.substring(with: m.range)
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }

    /// A small invented page for tests and the launch argument `-importdemo`.
    public static let demoHTML: String = """
    <html><head><title>Demo Gym machines</title></head><body>
    <img src="https://example.com/img/logo.png" alt="Demo Gym logo">
    <img src="https://example.com/img/cookie.png" alt="Cookie banner">
    <img src="https://example.com/img/leg-press.jpg" alt="Leg press">
    <img src="https://example.com/img/chest-press.jpg" alt="Chest press">
    <figure><img src="https://example.com/img/lat.jpg" alt="photo 1"><figcaption>Lat pulldown</figcaption></figure>
    <img data-src="https://example.com/img/rowing.jpg" alt="Rowing machine">
    <img srcset="https://example.com/img/treadmill.jpg 1x, https://example.com/img/treadmill2.jpg 2x" alt="Treadmill">
    <img src="https://example.com/img/leg-curl.jpg" alt="Seated leg curl">
    </body></html>
    """
}
