// Generates Packages/ScrambleKit/Tests/ScrambleKitTests/Fixtures/cubingjs.json:
// scrambles from cubing.js plus the resulting cube state (min2phase facelet string, URFDLB order),
// computed by cubing.js. Run with `just cubingjs-fixture`.
import { Alg } from "cubing/alg";
import { cube3x3x3 } from "cubing/puzzles";
import { randomScrambleForEvent } from "cubing/scramble";
import type { KPattern } from "cubing/kpuzzle";

// Same conversion as cubing.js src/cubing/search/inside/solve/puzzles/3x3x3/convert.ts.
const reidEdgeOrder = "UF UR UB UL DF DR DB DL FR FL BR BL".split(" ");
const reidCornerOrder = "UFR URB UBL ULF DRF DFL DLB DBR".split(" ");
const centerOrder = "U L F R B D".split(" ");
const map: [number, number, number][] = [
  [1, 2, 0], [0, 2, 0], [1, 1, 0], [0, 3, 0], [2, 0, 0], [0, 1, 0], [1, 3, 0], [0, 0, 0], [1, 0, 0],
  [1, 0, 2], [0, 1, 1], [1, 1, 1], [0, 8, 1], [2, 3, 0], [0, 10, 1], [1, 4, 1], [0, 5, 1], [1, 7, 2],
  [1, 3, 2], [0, 0, 1], [1, 0, 1], [0, 9, 0], [2, 2, 0], [0, 8, 0], [1, 5, 1], [0, 4, 1], [1, 4, 2],
  [1, 5, 0], [0, 4, 0], [1, 4, 0], [0, 7, 0], [2, 5, 0], [0, 5, 0], [1, 6, 0], [0, 6, 0], [1, 7, 0],
  [1, 2, 2], [0, 3, 1], [1, 3, 1], [0, 11, 1], [2, 1, 0], [0, 9, 1], [1, 6, 1], [0, 7, 1], [1, 5, 2],
  [1, 1, 2], [0, 2, 1], [1, 2, 1], [0, 10, 0], [2, 4, 0], [0, 11, 0], [1, 7, 1], [0, 6, 1], [1, 6, 2],
];
const rotateLeft = (s: string, i: number) => s.slice(i) + s.slice(0, i);

function facelets(pattern: KPattern): string {
  const d = pattern.patternData;
  const reid = [
    d.EDGES.pieces.map((p, i) => rotateLeft(reidEdgeOrder[p], d.EDGES.orientation[i])),
    d.CORNERS.pieces.map((p, i) => rotateLeft(reidCornerOrder[p], d.CORNERS.orientation[i])),
    centerOrder,
  ];
  return map.map(([orbit, perm, ori]) => reid[orbit][perm][ori]).join("");
}

const kpuzzle = await cube3x3x3.kpuzzle();
const cases: { scramble: string; facelets: string }[] = [];
for (let i = 0; i < 50; i++) {
  const scramble = (await randomScrambleForEvent("333")).toString();
  cases.push({ scramble, facelets: facelets(kpuzzle.defaultPattern().applyAlg(Alg.fromString(scramble))) });
}
// Every face turn on its own, to pin down move definitions.
for (const face of "URFDLB") {
  for (const suffix of ["", "2", "'"]) {
    const scramble = face + suffix;
    cases.push({ scramble, facelets: facelets(kpuzzle.defaultPattern().applyAlg(Alg.fromString(scramble))) });
  }
}

const out = new URL("../../Packages/ScrambleKit/Tests/ScrambleKitTests/Fixtures/cubingjs.json", import.meta.url);
await Bun.write(out, JSON.stringify(cases, null, 2) + "\n");
console.log(`wrote ${cases.length} cases`);
process.exit(0);
