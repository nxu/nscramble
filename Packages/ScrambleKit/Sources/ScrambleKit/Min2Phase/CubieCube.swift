// Ported from min2phase by Chen Shuang (https://github.com/cs0x7f/min2phase).

/// Cube state at the piece level.
///
/// Corners: `ca[slot] = orientation << 3 | piece` (orientation 0-2, or 3-5 for mirrored symmetries).
/// Edges: `ea[slot] = piece << 1 | orientation`.
struct CubieCube: Equatable, Sendable {
    var ca = [0, 1, 2, 3, 4, 5, 6, 7]
    var ea = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]

    init() {}

    init(cperm: Int, twist: Int, eperm: Int, flip: Int) {
        setCPerm(cperm)
        setTwist(twist)
        Util.setNPerm(&ea, eperm, 12, isEdge: true)
        setFlip(flip)
    }

    static let solved = CubieCube()

    static let urf1 = CubieCube(cperm: 2531, twist: 1373, eperm: 67_026_819, flip: 1367)
    static let urf2 = CubieCube(cperm: 2089, twist: 1906, eperm: 322_752_913, flip: 2040)
    static let urfMove: [[Int]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
        [6, 7, 8, 0, 1, 2, 3, 4, 5, 15, 16, 17, 9, 10, 11, 12, 13, 14],
        [3, 4, 5, 6, 7, 8, 0, 1, 2, 12, 13, 14, 15, 16, 17, 9, 10, 11],
        [2, 1, 0, 5, 4, 3, 8, 7, 6, 11, 10, 9, 14, 13, 12, 17, 16, 15],
        [8, 7, 6, 2, 1, 0, 5, 4, 3, 17, 16, 15, 11, 10, 9, 14, 13, 12],
        [5, 4, 3, 8, 7, 6, 2, 1, 0, 14, 13, 12, 17, 16, 15, 11, 10, 9],
    ]

    /// The 18 face turns, indexed `face * 3 + (turns - 1)` with faces U R F D L B.
    static let moveCube: [CubieCube] = {
        var mc = [CubieCube](repeating: CubieCube(), count: 18)
        mc[0] = CubieCube(cperm: 15120, twist: 0, eperm: 119_750_400, flip: 0)
        mc[3] = CubieCube(cperm: 21021, twist: 1494, eperm: 323_403_417, flip: 0)
        mc[6] = CubieCube(cperm: 8064, twist: 1236, eperm: 29_441_808, flip: 550)
        mc[9] = CubieCube(cperm: 9, twist: 0, eperm: 5880, flip: 0)
        mc[12] = CubieCube(cperm: 1230, twist: 412, eperm: 2_949_660, flip: 0)
        mc[15] = CubieCube(cperm: 224, twist: 137, eperm: 328_552, flip: 137)
        for a in stride(from: 0, to: 18, by: 3) {
            for p in 0..<2 {
                var c = CubieCube()
                edgeMult(mc[a + p], mc[a], &c)
                cornMult(mc[a + p], mc[a], &c)
                mc[a + p + 1] = c
            }
        }
        return mc
    }()

    /// Returns the state after applying `move` (a standard move index).
    func applying(_ move: Int) -> CubieCube {
        var r = CubieCube()
        Self.cornMult(self, Self.moveCube[move], &r)
        Self.edgeMult(self, Self.moveCube[move], &r)
        return r
    }

    func applying(_ scramble: Scramble) -> CubieCube {
        scramble.moves.reduce(self) { $0.applying($1.index) }
    }

    mutating func invert() {
        var temps = CubieCube()
        for edge in 0..<12 {
            temps.ea[ea[edge] >> 1] = (edge << 1) | (ea[edge] & 1)
        }
        for corn in 0..<8 {
            temps.ca[ca[corn] & 7] = corn | ((0x20 >> (ca[corn] >> 3)) & 0x18)
        }
        self = temps
    }

    /// prod = a * b, corners only.
    static func cornMult(_ a: CubieCube, _ b: CubieCube, _ prod: inout CubieCube) {
        for corn in 0..<8 {
            let oriA = a.ca[b.ca[corn] & 7] >> 3
            let oriB = b.ca[corn] >> 3
            prod.ca[corn] = (a.ca[b.ca[corn] & 7] & 7) | (((oriA + oriB) % 3) << 3)
        }
    }

    /// prod = a * b, corners only, with mirrored cases considered.
    static func cornMultFull(_ a: CubieCube, _ b: CubieCube, _ prod: inout CubieCube) {
        for corn in 0..<8 {
            let oriA = a.ca[b.ca[corn] & 7] >> 3
            let oriB = b.ca[corn] >> 3
            var ori = oriA + (oriA < 3 ? oriB : 6 - oriB)
            ori = ori % 3 + ((oriA < 3) == (oriB < 3) ? 0 : 3)
            prod.ca[corn] = (a.ca[b.ca[corn] & 7] & 7) | (ori << 3)
        }
    }

    /// prod = a * b, edges only.
    static func edgeMult(_ a: CubieCube, _ b: CubieCube, _ prod: inout CubieCube) {
        for ed in 0..<12 {
            prod.ea[ed] = a.ea[b.ea[ed] >> 1] ^ (b.ea[ed] & 1)
        }
    }

    /// b = sinv * a * s, corners only.
    static func cornConjugate(_ a: CubieCube, s: CubieCube, sinv: CubieCube, _ b: inout CubieCube) {
        for corn in 0..<8 {
            let oriA = sinv.ca[a.ca[s.ca[corn] & 7] & 7] >> 3
            let oriB = a.ca[s.ca[corn] & 7] >> 3
            let ori = oriA < 3 ? oriB : (3 - oriB) % 3
            b.ca[corn] = (sinv.ca[a.ca[s.ca[corn] & 7] & 7] & 7) | (ori << 3)
        }
    }

    /// b = sinv * a * s, edges only.
    static func edgeConjugate(_ a: CubieCube, s: CubieCube, sinv: CubieCube, _ b: inout CubieCube) {
        for ed in 0..<12 {
            b.ea[ed] = sinv.ea[a.ea[s.ea[ed] >> 1] >> 1] ^ (a.ea[s.ea[ed] >> 1] & 1) ^ (s.ea[ed] & 1)
        }
    }

    /// self = S_urf^-1 * self * S_urf.
    mutating func urfConjugate() {
        var temps = CubieCube()
        Self.cornMult(Self.urf2, self, &temps)
        Self.cornMult(temps, Self.urf1, &self)
        Self.edgeMult(Self.urf2, self, &temps)
        Self.edgeMult(temps, Self.urf1, &self)
    }

    // MARK: Phase 1 coordinates

    /// Orientation of 12 edges, [0, 2048).
    var flip: Int {
        var idx = 0
        for i in 0..<11 {
            idx = (idx << 1) | (ea[i] & 1)
        }
        return idx
    }

    mutating func setFlip(_ idx: Int) {
        var idx = idx
        var parity = 0
        for i in stride(from: 10, through: 0, by: -1) {
            let val = idx & 1
            parity ^= val
            ea[i] = (ea[i] & ~1) | val
            idx >>= 1
        }
        ea[11] = (ea[11] & ~1) | parity
    }

    /// Orientation of 8 corners, [0, 2187).
    var twist: Int {
        var idx = 0
        for i in 0..<7 {
            idx = idx * 3 + (ca[i] >> 3)
        }
        return idx
    }

    mutating func setTwist(_ idx: Int) {
        var idx = idx
        var twst = 15
        for i in stride(from: 6, through: 0, by: -1) {
            let val = idx % 3
            twst -= val
            ca[i] = (ca[i] & 7) | (val << 3)
            idx /= 3
        }
        ca[7] = (ca[7] & 7) | ((twst % 3) << 3)
    }

    /// Positions of the 4 UD-slice edges, order ignored, [0, 495).
    var udSlice: Int { 494 - Util.getComb(ea, mask: 8, isEdge: true) }

    mutating func setUDSlice(_ idx: Int) {
        Util.setComb(&ea, 494 - idx, mask: 8, isEdge: true)
    }

    // MARK: Phase 2 coordinates

    /// Permutation of 8 corners, [0, 40320).
    var cperm: Int { Util.getNPerm(ca, 8, isEdge: false) }

    mutating func setCPerm(_ idx: Int) {
        Util.setNPerm(&ca, idx, 8, isEdge: false)
    }

    /// Permutation of 8 UD edges, [0, 40320).
    var eperm: Int { Util.getNPerm(ea, 8, isEdge: true) }

    mutating func setEPerm(_ idx: Int) {
        Util.setNPerm(&ea, idx, 8, isEdge: true)
    }

    /// Permutation of 4 UD-slice edges, [0, 24).
    var mperm: Int { Util.getNPerm(ea, 12, isEdge: true) % 24 }

    mutating func setMPerm(_ idx: Int) {
        Util.setNPerm(&ea, idx, 12, isEdge: true)
    }

    var ccomb: Int { Util.getComb(ca, mask: 0, isEdge: false) }

    mutating func setCComb(_ idx: Int) {
        Util.setComb(&ca, idx, mask: 0, isEdge: false)
    }

    /// Whether this is a reachable cube state.
    var isSolvable: Bool {
        var edgeMask = 0
        var sum = 0
        for e in ea {
            edgeMask |= 1 << (e >> 1)
            sum ^= e & 1
        }
        guard edgeMask == 0xfff, sum == 0 else { return false }
        var cornMask = 0
        sum = 0
        for c in ca {
            cornMask |= 1 << (c & 7)
            sum += c >> 3
        }
        guard cornMask == 0xff, sum % 3 == 0 else { return false }
        return Util.getNParity(Util.getNPerm(ea, 12, isEdge: true), 12) == Util.getNParity(cperm, 8)
    }

    /// A uniformly random reachable state.
    static func random<G: RandomNumberGenerator>(using generator: inout G) -> CubieCube {
        let cperm = Int.random(in: 0..<40320, using: &generator)
        let parity = Util.getNParity(cperm, 8)
        var eperm: Int
        repeat {
            eperm = Int.random(in: 0..<479_001_600, using: &generator)
        } while Util.getNParity(eperm, 12) != parity
        return CubieCube(
            cperm: cperm,
            twist: Int.random(in: 0..<2187, using: &generator),
            eperm: eperm,
            flip: Int.random(in: 0..<2048, using: &generator)
        )
    }
}

// MARK: Facelets

extension CubieCube {
    // Facelet indices: U 0-8, R 9-17, F 18-26, D 27-35, L 36-44, B 45-53.
    static let cornerFacelet: [[Int]] = [
        [8, 9, 20], [6, 18, 38], [0, 36, 47], [2, 45, 11],
        [29, 26, 15], [27, 44, 24], [33, 53, 42], [35, 17, 51],
    ]
    static let edgeFacelet: [[Int]] = [
        [5, 10], [7, 19], [3, 37], [1, 46], [32, 16], [28, 25],
        [30, 43], [34, 52], [23, 12], [21, 41], [50, 39], [48, 14],
    ]

    /// 54-character facelet string in URFDLB order, as used by min2phase and Kociemba's solver.
    var facelets: String {
        let names: [Character] = ["U", "R", "F", "D", "L", "B"]
        var f = (0..<54).map { names[$0 / 9] }
        for c in 0..<8 {
            let j = ca[c] & 7
            let ori = ca[c] >> 3
            for n in 0..<3 {
                f[Self.cornerFacelet[c][(n + ori) % 3]] = names[Self.cornerFacelet[j][n] / 9]
            }
        }
        for e in 0..<12 {
            let j = ea[e] >> 1
            let ori = ea[e] & 1
            for n in 0..<2 {
                f[Self.edgeFacelet[e][(n + ori) % 2]] = names[Self.edgeFacelet[j][n] / 9]
            }
        }
        return String(f)
    }
}
