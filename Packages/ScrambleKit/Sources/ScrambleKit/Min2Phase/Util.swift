// Ported from min2phase by Chen Shuang (https://github.com/cs0x7f/min2phase).

/// Move indices used throughout the solver: `face * 3 + (turns - 1)` with faces ordered U R F D L B.
enum Util {
    static let cnk: [[Int]] = {
        var c = Array(repeating: Array(repeating: 0, count: 13), count: 13)
        for i in 0..<13 {
            c[i][0] = 1
            c[i][i] = 1
            for j in stride(from: 1, to: i, by: 1) {
                c[i][j] = c[i - 1][j - 1] + c[i - 1][j]
            }
        }
        return c
    }()

    /// Phase 2 move index -> standard move index.
    static let ud2std = [0, 1, 2, 4, 7, 9, 10, 11, 13, 16, 3, 5, 6, 8, 12, 14, 15, 17]

    static let std2ud: [Int] = {
        var r = [Int](repeating: 0, count: 18)
        for i in 0..<18 {
            r[ud2std[i]] = i
        }
        return r
    }()

    /// For the last phase 2 move, a bitmask of phase 2 moves that must not follow it.
    static let ckmv2bit: [Int] = {
        var r = [Int](repeating: 0, count: 11)
        for i in 0..<10 {
            let ix = ud2std[i] / 3
            for j in 0..<10 {
                let jx = ud2std[j] / 3
                if ix == jx || (ix % 3 == jx % 3 && ix >= jx) {
                    r[i] |= 1 << j
                }
            }
        }
        return r
    }()

    static func getNParity(_ idx: Int, _ n: Int) -> Int {
        var idx = idx
        var p = 0
        for i in stride(from: n - 2, through: 0, by: -1) {
            p ^= idx % (n - i)
            idx /= (n - i)
        }
        return p & 1
    }

    static func setVal(_ val0: Int, _ val: Int, isEdge: Bool) -> Int {
        isEdge ? ((val << 1) | (val0 & 1)) : (val | (val0 & ~7))
    }

    static func getVal(_ val0: Int, isEdge: Bool) -> Int {
        isEdge ? (val0 >> 1) : (val0 & 7)
    }

    static func setNPerm(_ arr: inout [Int], _ idx: Int, _ n: Int, isEdge: Bool) {
        var idx = idx
        var val: UInt64 = 0xFEDC_BA98_7654_3210
        var extract: UInt64 = 0
        for p in 2...n {
            extract = (extract << 4) | UInt64(idx % p)
            idx /= p
        }
        for i in 0..<(n - 1) {
            let v = UInt64(extract & 0xf) << 2
            extract >>= 4
            arr[i] = setVal(arr[i], Int((val >> v) & 0xf), isEdge: isEdge)
            let m: UInt64 = (1 << v) &- 1
            val = (val & m) | ((val >> 4) & ~m)
        }
        arr[n - 1] = setVal(arr[n - 1], Int(val & 0xf), isEdge: isEdge)
    }

    static func getNPerm(_ arr: [Int], _ n: Int, isEdge: Bool) -> Int {
        var idx = 0
        var val: UInt64 = 0xFEDC_BA98_7654_3210
        for i in 0..<(n - 1) {
            let v = UInt64(getVal(arr[i], isEdge: isEdge) << 2)
            idx = (n - i) * idx + Int((val >> v) & 0xf)
            val = val &- (0x1111_1111_1111_1110 << v)
        }
        return idx
    }

    static func getComb(_ arr: [Int], mask: Int, isEdge: Bool) -> Int {
        var idxC = 0
        var r = 4
        for i in stride(from: arr.count - 1, through: 0, by: -1) {
            if (getVal(arr[i], isEdge: isEdge) & 0xc) == mask {
                idxC += cnk[i][r]
                r -= 1
            }
        }
        return idxC
    }

    static func setComb(_ arr: inout [Int], _ idxC: Int, mask: Int, isEdge: Bool) {
        var idxC = idxC
        var r = 4
        var fill = arr.count - 1
        for i in stride(from: arr.count - 1, through: 0, by: -1) {
            if idxC >= cnk[i][r] {
                idxC -= cnk[i][r]
                r -= 1
                arr[i] = setVal(arr[i], r | mask, isEdge: isEdge)
            } else {
                if (fill & 0xc) == mask {
                    fill -= 4
                }
                arr[i] = setVal(arr[i], fill, isEdge: isEdge)
                fill -= 1
            }
        }
    }
}

/// A solution under construction; merges consecutive moves on the same axis.
struct Solution {
    var length = 0
    var moves = [Int](repeating: 0, count: 31)
    let urfIdx: Int
    let inverse: Bool

    mutating func append(_ curMove: Int) {
        if length == 0 {
            moves[0] = curMove
            length = 1
            return
        }
        let axisCur = curMove / 3
        let axisLast = moves[length - 1] / 3
        if axisCur == axisLast {
            let pow = (curMove % 3 + moves[length - 1] % 3 + 1) % 4
            if pow == 3 {
                length -= 1
            } else {
                moves[length - 1] = axisCur * 3 + pow
            }
            return
        }
        if length > 1 && axisCur % 3 == axisLast % 3 && axisCur == moves[length - 2] / 3 {
            let pow = (curMove % 3 + moves[length - 2] % 3 + 1) % 4
            if pow == 3 {
                moves[length - 2] = moves[length - 1]
                length -= 1
            } else {
                moves[length - 2] = axisCur * 3 + pow
            }
            return
        }
        moves[length] = curMove
        length += 1
    }

    /// Standard move indices, undoing the URF conjugation (and inverting if requested).
    var standardMoves: [Int] {
        let urf = inverse ? (urfIdx + 3) % 6 : urfIdx
        let indices = urf < 3 ? Array(0..<length) : Array((0..<length).reversed())
        return indices.map { CubieCube.urfMove[urf][moves[$0]] }
    }
}
