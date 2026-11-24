import Foundation

/// When each record last changed and when a record was deleted (since 3.0) — kept inside every data
/// file under "sync". Times are seconds since 1 Jan 2001, with fractions, so two changes a moment
/// apart still have an order.
public struct SyncMarks: Codable, Equatable, Sendable {
    /// The format this app writes. A file with a higher number comes from a newer app: it is read
    /// but never written over.
    public static let format = 1

    /// Record key (or "order/<list>") → when it last changed.
    public var changed: [String: Double] = [:]
    /// Record key → when it was deleted. Only this ever removes a record on another device.
    public var gone: [String: Double] = [:]
    public var format: Int = SyncMarks.format

    public init() {}

    enum CodingKeys: String, CodingKey { case changed, gone, format }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        changed = try c.decodeIfPresent([String: Double].self, forKey: .changed) ?? [:]
        gone = try c.decodeIfPresent([String: Double].self, forKey: .gone) ?? [:]
        format = try c.decodeIfPresent(Int.self, forKey: .format) ?? SyncMarks.format
    }
}

/// One data file taken apart for joining (since 3.0): every record on its own under a key
/// ("machine/<id>", "one/rests"), each list's order, and the marks.
///
/// The rules, all here:
/// - a record is only ever removed by a "deleted" mark — a record that is merely missing on one
///   side is kept;
/// - the same record changed on both sides: the newer change stays;
/// - a deleted mark newer than the record's last change removes it, an older one does not;
/// - joining is the same whichever side is "mine", and joining twice changes nothing.
public struct SyncDoc: Equatable, Sendable {
    public var records: [String: Data] = [:]
    /// List name → its record keys in order. A list's name is the part of its keys before the "/".
    public var orders: [String: [String]] = [:]
    public var marks = SyncMarks()

    public init() {}

    public static func orderKey(_ list: String) -> String { "order/" + list }

    // MARK: Data from before 3.0

    /// What a record that was never changed since sync began is marked with: a day in January 2001,
    /// later for the device that counts more — Mac 1, iPad 2, iPhone 3. So where two devices hold
    /// the same record from before 3.0, the iPhone's stays; and no old record is ever marked
    /// "changed now", which would beat a real change made elsewhere.
    public static func baseline(rank: Int) -> Double { Double(rank) * 86_400 }
    public static func isBaseline(_ stamp: Double) -> Bool { stamp >= 0 && stamp < 30 * 86_400 }
    /// 1, 2 or 3 for a baseline mark; nil for a real change.
    public static func rank(_ stamp: Double?) -> Int? {
        guard let stamp, isBaseline(stamp) else { return nil }
        return Int((stamp / 86_400).rounded(.down))
    }

    /// Marks every record and list that has no mark yet as "from before sync, on this kind of device".
    public func baselined(rank: Int) -> SyncDoc {
        var out = self
        let stamp = SyncDoc.baseline(rank: rank)
        for key in records.keys where out.marks.changed[key] == nil { out.marks.changed[key] = stamp }
        for list in orders.keys where out.marks.changed[SyncDoc.orderKey(list)] == nil {
            out.marks.changed[SyncDoc.orderKey(list)] = stamp
        }
        return out
    }

    // MARK: A change on this device

    /// This doc (the data as it is now) with the marks of `old` brought up to date: every record that
    /// is new or differs is marked changed at `now`, every record that is gone is marked deleted, a
    /// list whose order changed is marked. A mark never goes backwards, also when this device's
    /// clock is behind another's.
    public func stamped(after old: SyncDoc, now: Date = Date()) -> SyncDoc {
        var out = self
        var marks = old.marks
        let t = now.timeIntervalSinceReferenceDate
        for (key, data) in records where old.records[key] != data {
            marks.changed[key] = max(t, (marks.changed[key] ?? 0) + 0.001, (marks.gone[key] ?? 0) + 0.001)
        }
        for key in old.records.keys where records[key] == nil {
            marks.gone[key] = max(t, (marks.changed[key] ?? 0) + 0.001, (marks.gone[key] ?? 0) + 0.001)
            marks.changed[key] = nil
        }
        for (list, order) in orders {
            let before = old.orders[list] ?? []
            let now = Set(order), was = Set(before)
            // Only a real re-ordering counts — adding or removing a record does not.
            if before.filter(now.contains) != order.filter(was.contains) {
                let key = SyncDoc.orderKey(list)
                marks.changed[key] = max(t, (marks.changed[key] ?? 0) + 0.001)
            }
        }
        out.marks = marks
        return out
    }

    // MARK: Joining two copies

    public static func merged(_ a: SyncDoc, _ b: SyncDoc) -> SyncDoc {
        var out = SyncDoc()
        out.marks.format = max(a.marks.format, b.marks.format)
        out.marks.gone = a.marks.gone.merging(b.marks.gone) { max($0, $1) }
        for key in Set(a.records.keys).union(b.records.keys) {
            let best = newer((a.records[key], a.marks.changed[key]), (b.records[key], b.marks.changed[key]))
            guard let data = best.data else { continue }
            let stamp = best.stamp ?? -1
            if let gone = out.marks.gone[key], gone >= stamp { continue }
            out.records[key] = data
            if stamp >= 0 { out.marks.changed[key] = stamp }
        }
        for list in Set(a.orders.keys).union(b.orders.keys) {
            let key = orderKey(list)
            let sa = a.marks.changed[key], sb = b.marks.changed[key]
            let oa = a.orders[list] ?? [], ob = b.orders[list] ?? []
            let aWins: Bool
            if (sa ?? -1) != (sb ?? -1) { aWins = (sa ?? -1) > (sb ?? -1) }
            else if oa.count != ob.count { aWins = oa.count > ob.count }
            else { aWins = !oa.lexicographicallyPrecedes(ob) }
            var order = weave(aWins ? oa : ob, aWins ? ob : oa).filter { out.records[$0] != nil }
            // Every living record of the list has a place.
            let placed = Set(order)
            order += out.records.keys.filter { $0.hasPrefix(list + "/") && !placed.contains($0) }.sorted()
            out.orders[list] = order
            if let stamp = [sa, sb].compactMap({ $0 }).max() { out.marks.changed[key] = stamp }
        }
        return out
    }

    /// Several copies joined (the iCloud file, its conflict copies, this device's own).
    public static func merged(_ docs: [SyncDoc]) -> SyncDoc {
        guard var out = docs.first else { return SyncDoc() }
        // Joining with itself first tidies marks left over for records that are gone.
        out = merged(out, out)
        for d in docs.dropFirst() { out = merged(out, d) }
        return out
    }

    /// The same data with marks and orders in their tidy form — what joining it with itself gives.
    public var tidied: SyncDoc { SyncDoc.merged(self, self) }

    private static func newer(_ x: (data: Data?, stamp: Double?), _ y: (data: Data?, stamp: Double?)) -> (data: Data?, stamp: Double?) {
        guard let dx = x.data else { return y }
        guard let dy = y.data else { return x }
        let sx = x.stamp ?? -1, sy = y.stamp ?? -1
        if sx != sy { return sx > sy ? x : y }
        if dx == dy { return x }
        // The same moment, different words: the same choice on every device.
        if dx.count != dy.count { return dx.count > dy.count ? x : y }
        return dx.lexicographicallyPrecedes(dy) ? y : x
    }

    /// The winner's order, with the other side's extra records put in before the record they stood
    /// before there — so a record added at the end stays at the end, a copy stays beside its original.
    private static func weave(_ winner: [String], _ loser: [String]) -> [String] {
        var result = winner
        var have = Set(winner)
        var next: String?
        for key in loser.reversed() {
            if have.contains(key) { next = key; continue }
            let at = next.flatMap { result.firstIndex(of: $0) } ?? result.count
            result.insert(key, at: at)
            have.insert(key)
            next = key
        }
        return result
    }
}

/// JSON the same way on every device, so the same record gives the same bytes.
enum SyncJSON {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

/// A single value (the chosen gym, the rest times) as a record; nil is a value too.
struct One<T: Codable>: Codable {
    var v: T?
}

/// Takes typed data apart into a SyncDoc.
struct DocBuilder {
    var doc = SyncDoc()
    /// False when two records shared one key — then the doc does not hold everything and must not be used.
    var whole = true
    private let enc = SyncJSON.encoder()

    mutating func list<T: Encodable>(_ name: String, _ items: [T], id: (T) -> String) {
        var order: [String] = []
        for item in items {
            let key = name + "/" + id(item)
            guard doc.records[key] == nil, let data = try? enc.encode(item) else {
                whole = false
                continue
            }
            doc.records[key] = data
            order.append(key)
        }
        doc.orders[name] = order
    }

    mutating func one<T: Codable>(_ name: String, _ value: T?) {
        if let data = try? enc.encode(One(v: value)) { doc.records["one/" + name] = data } else { whole = false }
    }
}

/// Puts a SyncDoc back together as typed data.
struct DocReader {
    let doc: SyncDoc
    private let dec = SyncJSON.decoder()

    init(_ doc: SyncDoc) { self.doc = doc }

    func list<T: Decodable>(_ name: String, _ type: T.Type) -> [T] {
        (doc.orders[name] ?? []).compactMap { key in doc.records[key].flatMap { try? dec.decode(T.self, from: $0) } }
    }

    func one<T: Codable>(_ name: String, _ type: T.Type) -> T? {
        doc.records["one/" + name].flatMap { try? dec.decode(One<T>.self, from: $0) }?.v
    }
}
