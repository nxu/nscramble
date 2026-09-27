// Ported from min2phase by Chen Shuang (https://github.com/cs0x7f/min2phase).
//
// Only the regular (non-optimal) search is ported; `next()`/`isRec` continuation is not needed.

/// Phase 1 search node.
struct CoordCube {
    var twist = 0
    var tsym = 0
    var flip = 0
    var fsym = 0
    var slice = 0
    var prun = 0
    var twistc = 0
    var flipc = 0
}

extension Tables {
    func setWithPrun(_ node: inout CoordCube, _ cc: CubieCube, _ depth: Int) -> Bool {
        var twist = twistSym(cc)
        var flip = flipSym(cc)
        let tsym = twist & 7
        twist >>= 3

        var prun = getPruning(twistFlipPrun, (twist << 11) | flipS2RF[flip ^ tsym])
        node.twist = twist
        node.tsym = tsym
        node.prun = prun
        if prun > depth {
            return false
        }

        let fsym = flip & 7
        flip >>= 3
        node.flip = flip
        node.fsym = fsym

        let slice = cc.udSlice
        node.slice = slice
        prun = max(
            prun,
            getPruning(udSliceTwistPrun, twist * nSlice + udSliceConj[slice * 8 + tsym]),
            getPruning(udSliceFlipPrun, flip * nSlice + udSliceConj[slice * 8 + fsym])
        )
        node.prun = prun
        if prun > depth {
            return false
        }

        var pc = CubieCube()
        sym.cornConjugate(cc, 1, &pc)
        sym.edgeConjugate(cc, 1, &pc)
        node.twistc = twistSym(pc)
        node.flipc = flipSym(pc)
        prun = max(prun, getPruning(twistFlipPrun, ((node.twistc >> 3) << 11) | flipS2RF[node.flipc ^ (node.twistc & 7)]))
        node.prun = prun
        return prun <= depth
    }

    /// Sets `node` to `cc` after move `m` and returns its pruning value.
    func doMovePrun(_ node: inout CoordCube, _ cc: CoordCube, _ m: Int) -> Int {
        node.slice = udSliceMove[cc.slice * 18 + m]

        let flip = flipMove[cc.flip * 18 + sym8Move[(m << 3) | cc.fsym]]
        node.fsym = (flip & 7) ^ cc.fsym
        node.flip = flip >> 3

        let twist = twistMove[cc.twist * 18 + sym8Move[(m << 3) | cc.tsym]]
        node.tsym = (twist & 7) ^ cc.tsym
        node.twist = twist >> 3

        node.prun = max(
            getPruning(udSliceTwistPrun, node.twist * nSlice + udSliceConj[node.slice * 8 + node.tsym]),
            getPruning(udSliceFlipPrun, node.flip * nSlice + udSliceConj[node.slice * 8 + node.fsym]),
            getPruning(twistFlipPrun, (node.twist << 11) | flipS2RF[(node.flip << 3) | (node.fsym ^ node.tsym)])
        )
        return node.prun
    }

    /// Updates the conjugated coordinates of `node` and returns their pruning value.
    func doMovePrunConj(_ node: inout CoordCube, _ cc: CoordCube, _ m: Int) -> Int {
        let m = symMove[3 * 18 + m]
        node.flipc = flipMove[(cc.flipc >> 3) * 18 + sym8Move[(m << 3) | (cc.flipc & 7)]] ^ (cc.flipc & 7)
        node.twistc = twistMove[(cc.twistc >> 3) * 18 + sym8Move[(m << 3) | (cc.twistc & 7)]] ^ (cc.twistc & 7)
        return getPruning(twistFlipPrun, ((node.twistc >> 3) << 11) | flipS2RF[node.flipc ^ (node.twistc & 7)])
    }
}

/// Two-phase solver. Not thread-safe; create one per solve (the shared tables are immutable).
final class Search {
    static let maxPreMoves = 20
    static let minP1LengthPre = 7
    static let maxDepth2 = 12

    let t: Tables

    var move = [Int](repeating: 0, count: 31)
    var nodeUD = [CoordCube](repeating: CoordCube(), count: 21)

    var selfSym: UInt64 = 0
    var conjMask = 0
    var urfIdx = 0
    var length1 = 0
    var depth1 = 0
    var maxDep2 = 0
    var solLen = 0
    var solution: Solution?
    var probe = 0
    var probeMax = 0
    var probeMin = 0
    var inverse = false
    var valid1 = 0
    var allowShorter = false
    var urfCubieCube = [CubieCube](repeating: CubieCube(), count: 6)
    var phase1Cubie = [CubieCube](repeating: CubieCube(), count: 21)

    var preMoves = [Int](repeating: 0, count: maxPreMoves)
    var preMoveLen = 0
    var maxPreMoves = 0

    init(tables: Tables = .shared) {
        t = tables
    }

    /// Finds a sequence of standard move indices that solves `cube` (or generates it, if `inverse`).
    ///
    /// Returns nil for unsolvable states or when no solution is found within the limits.
    func solution(
        _ cube: CubieCube,
        maxDepth: Int = 21,
        probeMax: Int = 100_000_000,
        probeMin: Int = 0,
        inverse: Bool = false
    ) -> [Int]? {
        guard cube.isSolvable else { return nil }
        solLen = maxDepth + 1
        probe = 0
        self.probeMax = probeMax
        self.probeMin = min(probeMin, probeMax)
        self.inverse = inverse
        solution = nil

        initSearch(cube)
        return search()?.standardMoves
    }

    private func initSearch(_ cube: CubieCube) {
        var cc = cube
        conjMask = 0
        selfSym = t.sym.selfSymmetry(cc)
        conjMask |= (selfSym >> 16) & 0xffff != 0 ? 0x12 : 0
        conjMask |= (selfSym >> 32) & 0xffff != 0 ? 0x24 : 0
        conjMask |= (selfSym >> 48) & 0xffff != 0 ? 0x38 : 0
        selfSym &= 0xffff_ffff_ffff
        maxPreMoves = conjMask > 7 ? 0 : Self.maxPreMoves

        for i in 0..<6 {
            urfCubieCube[i] = cc
            cc.urfConjugate()
            if i % 3 == 2 {
                cc.invert()
            }
        }
    }

    private func search() -> Solution? {
        length1 = 0
        while length1 < solLen {
            maxDep2 = min(Self.maxDepth2, solLen - length1 - 1)
            for i in 0..<6 {
                urfIdx = i
                if conjMask & (1 << i) != 0 {
                    continue
                }
                if phase1PreMoves(maxPreMoves, -30, urfCubieCube[i], Int(selfSym & 0xffff)) == 0 {
                    return solution
                }
            }
            length1 += 1
        }
        return solution
    }

    private func phase1PreMoves(_ maxl: Int, _ lm: Int, _ cc: CubieCube, _ ssym: Int) -> Int {
        preMoveLen = maxPreMoves - maxl
        if preMoveLen == 0 || (0x36FB7 >> lm) & 1 == 0 {
            depth1 = length1 - preMoveLen
            phase1Cubie[0] = cc
            allowShorter = depth1 == Self.minP1LengthPre && preMoveLen != 0

            if t.setWithPrun(&nodeUD[depth1 + 1], cc, depth1)
                && phase1(nodeUD[depth1 + 1], ssym, depth1, -1) == 0
            {
                return 0
            }
        }

        if maxl == 0 || preMoveLen + Self.minP1LengthPre >= length1 {
            return 1
        }

        var skipMoves = t.getSkipMoves(ssym)
        if maxl == 1 || preMoveLen + 1 + Self.minP1LengthPre >= length1 {
            skipMoves |= 0x36FB7
        }

        let lm = lm / 3 * 3
        var m = 0
        while m < 18 {
            if m == lm || m == lm - 9 || m == lm + 9 {
                m += 3
                continue
            }
            if skipMoves & (1 << m) != 0 {
                m += 1
                continue
            }
            var pc = CubieCube()
            CubieCube.cornMult(CubieCube.moveCube[m], cc, &pc)
            CubieCube.edgeMult(CubieCube.moveCube[m], cc, &pc)
            preMoves[maxPreMoves - maxl] = m
            let ret = phase1PreMoves(maxl - 1, m, pc, ssym & Int(truncatingIfNeeded: t.moveCubeSym[m]))
            if ret == 0 {
                return 0
            }
            m += 1
        }
        return 1
    }

    /// 0: found or probe limit exceeded; 1: at least 1 + maxDep2 moves away (try next power);
    /// 2: at least 2 + maxDep2 moves away (try next axis).
    private func initPhase2Pre() -> Int {
        if probe >= (solution == nil ? probeMax : probeMin) {
            return 0
        }
        probe += 1

        var i = valid1
        while i < depth1 {
            phase1Cubie[i + 1] = phase1Cubie[i].applying(move[i])
            i += 1
        }
        valid1 = depth1

        let cube = phase1Cubie[depth1]
        var p2corn = t.cPermSym(cube)
        var p2csym = p2corn & 0xf
        p2corn >>= 4
        var p2edge = t.ePermSym(cube)
        var p2esym = p2edge & 0xf
        p2edge >>= 4
        var p2mid = cube.mperm
        var edgei = t.getPermSymInv(p2edge, p2esym, isCorner: false)
        var corni = t.getPermSymInv(p2corn, p2csym, isCorner: true)

        let lastMove = depth1 == 0 ? -1 : move[depth1 - 1]
        let lastPre = preMoveLen == 0 ? -1 : preMoves[preMoveLen - 1]

        var ret = 0
        let p2switchMax = (preMoveLen == 0 ? 1 : 2) * (depth1 == 0 ? 1 : 2)
        var p2switchMask = (1 << p2switchMax) - 1
        for p2switch in 0..<p2switchMax {
            // 0 normal; 1 lastmove; 2 lastmove + premove; 3 premove
            if (p2switchMask >> p2switch) & 1 != 0 {
                p2switchMask &= ~(1 << p2switch)
                ret = initPhase2(p2corn, p2csym, p2edge, p2esym, p2mid, edgei, corni)
                if ret == 0 || ret > 2 {
                    break
                } else if ret == 2 {
                    p2switchMask &= 0x4 << p2switch
                }
            }
            if p2switchMask == 0 {
                break
            }
            if p2switch & 1 == 0 && depth1 > 0 {
                let m = Util.std2ud[lastMove / 3 * 3 + 1]
                move[depth1 - 1] = Util.ud2std[m] * 2 - move[depth1 - 1]

                p2mid = t.mPermMove[p2mid * 10 + m]
                p2corn = t.cPermMove[p2corn * 10 + t.symMoveUD[p2csym * 18 + m]]
                p2csym = t.symMult[(p2corn & 0xf) * 16 + p2csym]
                p2corn >>= 4
                p2edge = t.ePermMove[p2edge * 10 + t.symMoveUD[p2esym * 18 + m]]
                p2esym = t.symMult[(p2edge & 0xf) * 16 + p2esym]
                p2edge >>= 4
                corni = t.getPermSymInv(p2corn, p2csym, isCorner: true)
                edgei = t.getPermSymInv(p2edge, p2esym, isCorner: false)
            } else if preMoveLen > 0 {
                let m = Util.std2ud[lastPre / 3 * 3 + 1]
                preMoves[preMoveLen - 1] = Util.ud2std[m] * 2 - preMoves[preMoveLen - 1]

                p2mid = t.mPermInv[t.mPermMove[t.mPermInv[p2mid] * 10 + m]]
                p2corn = t.cPermMove[(corni >> 4) * 10 + t.symMoveUD[(corni & 0xf) * 18 + m]]
                corni = (p2corn & ~0xf) | t.symMult[(p2corn & 0xf) * 16 + (corni & 0xf)]
                p2corn = t.getPermSymInv(corni >> 4, corni & 0xf, isCorner: true)
                p2csym = p2corn & 0xf
                p2corn >>= 4
                p2edge = t.ePermMove[(edgei >> 4) * 10 + t.symMoveUD[(edgei & 0xf) * 18 + m]]
                edgei = (p2edge & ~0xf) | t.symMult[(p2edge & 0xf) * 16 + (edgei & 0xf)]
                p2edge = t.getPermSymInv(edgei >> 4, edgei & 0xf, isCorner: false)
                p2esym = p2edge & 0xf
                p2edge >>= 4
            }
        }
        if depth1 > 0 {
            move[depth1 - 1] = lastMove
        }
        if preMoveLen > 0 {
            preMoves[preMoveLen - 1] = lastPre
        }
        return ret == 0 ? 0 : 2
    }

    private func initPhase2(
        _ p2corn: Int, _ p2csym: Int, _ p2edge: Int, _ p2esym: Int, _ p2mid: Int, _ edgei: Int, _ corni: Int
    ) -> Int {
        let prun = max(
            getPruning(
                t.ePermCCombPPrun,
                (edgei >> 4) * nComb
                    + t.cCombPConj[t.perm2CombP[corni >> 4] * 16 + t.symMultInv[(edgei & 0xf) * 16 + (corni & 0xf)]]),
            getPruning(
                t.ePermCCombPPrun,
                p2edge * nComb + t.cCombPConj[t.perm2CombP[p2corn] * 16 + t.symMultInv[p2esym * 16 + p2csym]]),
            getPruning(t.mcPermPrun, p2corn * nMPerm + t.mPermConj[p2mid * 16 + p2csym])
        )

        if prun > maxDep2 {
            return prun - maxDep2
        }

        var depth2 = maxDep2
        while depth2 >= prun {
            let ret = phase2(p2edge, p2esym, p2corn, p2csym, p2mid, depth2, depth1, 10)
            if ret < 0 {
                break
            }
            depth2 -= ret
            var sol = Solution(urfIdx: urfIdx, inverse: inverse)
            for i in 0..<(depth1 + depth2) {
                sol.append(move[i])
            }
            for i in stride(from: preMoveLen - 1, through: 0, by: -1) {
                sol.append(preMoves[i])
            }
            solution = sol
            solLen = sol.length
            depth2 -= 1
        }

        if depth2 != maxDep2 {  // At least one solution has been found.
            maxDep2 = min(Self.maxDepth2, solLen - length1 - 1)
            return probe >= probeMin ? 0 : 1
        }
        return 1
    }

    /// 0: found or probe limit exceeded; 1: try next power; 2: try next axis.
    private func phase1(_ node: CoordCube, _ ssym: Int, _ maxl: Int, _ lm: Int) -> Int {
        if node.prun == 0 && maxl < 5 {
            if allowShorter || maxl == 0 {
                depth1 -= maxl
                let ret = initPhase2Pre()
                depth1 += maxl
                return ret
            }
            return 1
        }

        let skipMoves = t.getSkipMoves(ssym)

        for axis in stride(from: 0, to: 18, by: 3) {
            if axis == lm || axis == lm - 9 {
                continue
            }
            for power in 0..<3 {
                let m = axis + power

                if skipMoves != 0 && skipMoves & (1 << m) != 0 {
                    continue
                }

                var prun = t.doMovePrun(&nodeUD[maxl], node, m)
                if prun > maxl {
                    break
                } else if prun == maxl {
                    continue
                }

                prun = t.doMovePrunConj(&nodeUD[maxl], node, m)
                if prun > maxl {
                    break
                } else if prun == maxl {
                    continue
                }

                move[depth1 - maxl] = m
                valid1 = min(valid1, depth1 - maxl)
                let ret = phase1(nodeUD[maxl], ssym & Int(truncatingIfNeeded: t.moveCubeSym[m]), maxl - 1, axis)
                if ret == 0 {
                    return 0
                } else if ret >= 2 {
                    break
                }
            }
        }
        return 1
    }

    /// -1: no solution found; X >= 0: solution found, X moves shorter than `maxl`.
    private func phase2(
        _ edge: Int, _ esym: Int, _ corn: Int, _ csym: Int, _ mid: Int, _ maxl: Int, _ depth: Int, _ lm: Int
    ) -> Int {
        if edge == 0 && corn == 0 && mid == 0 {
            return maxl
        }
        let moveMask = Util.ckmv2bit[lm]
        var m = 0
        while m < 10 {
            if (moveMask >> m) & 1 != 0 {
                m += ((0x42 >> m) & 3) + 1
                continue
            }
            let midx = t.mPermMove[mid * 10 + m]
            var cornx = t.cPermMove[corn * 10 + t.symMoveUD[csym * 18 + m]]
            let csymx = t.symMult[(cornx & 0xf) * 16 + csym]
            cornx >>= 4
            var edgex = t.ePermMove[edge * 10 + t.symMoveUD[esym * 18 + m]]
            let esymx = t.symMult[(edgex & 0xf) * 16 + esym]
            edgex >>= 4
            let edgei = t.getPermSymInv(edgex, esymx, isCorner: false)
            let corni = t.getPermSymInv(cornx, csymx, isCorner: true)

            var prun = getPruning(
                t.ePermCCombPPrun,
                (edgei >> 4) * nComb
                    + t.cCombPConj[t.perm2CombP[corni >> 4] * 16 + t.symMultInv[(edgei & 0xf) * 16 + (corni & 0xf)]])
            if prun > maxl + 1 {
                return maxl - prun + 1
            } else if prun >= maxl {
                m += ((0x42 >> m) & 3 & (maxl - prun)) + 1
                continue
            }
            prun = max(
                getPruning(t.mcPermPrun, cornx * nMPerm + t.mPermConj[midx * 16 + csymx]),
                getPruning(
                    t.ePermCCombPPrun,
                    edgex * nComb + t.cCombPConj[t.perm2CombP[cornx] * 16 + t.symMultInv[esymx * 16 + csymx]])
            )
            if prun >= maxl {
                m += ((0x42 >> m) & 3 & (maxl - prun)) + 1
                continue
            }
            let ret = phase2(edgex, esymx, cornx, csymx, midx, maxl - 1, depth + 1, m)
            if ret >= 0 {
                move[depth] = Util.ud2std[m]
                return ret
            }
            if ret < -2 {
                break
            }
            if ret < -1 {
                m += (0x42 >> m) & 3
            }
            m += 1
        }
        return -1
    }
}
