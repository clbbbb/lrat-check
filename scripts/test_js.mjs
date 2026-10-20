import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const artifact = resolve(process.argv[2] ?? '_build/js/release/build/bindings/bindings.js');
const { verify_json, convert_json } = await import(pathToFileURL(artifact));
const encode = text => new TextEncoder().encode(text);
const cnf = 'p cnf 1 2\n1 0\n-1 0\n';
for (const [format, proof] of [
  ['lrat', encode('3 0 1 2 0\n')],
  ['lrat-binary', Uint8Array.of(97, 6, 0, 2, 4, 0)],
  ['drat', encode('0\n')],
  ['drat-binary', Uint8Array.of(97, 0)],
]) {
  assert.equal(JSON.parse(verify_json(cnf, proof, format)).ok, true);
  const result = JSON.parse(convert_json(cnf, proof, format));
  assert.equal(result.ok, true);
  assert.equal(JSON.parse(verify_json(cnf, encode(result.lrat), 'lrat')).ok, true);
}
assert.equal(JSON.parse(verify_json('p cnf 1 1\n1 0\n', encode('0\n'), 'drat')).ok, false);
assert.equal(JSON.parse(verify_json(cnf, Uint8Array.of(97, 128), 'lrat-binary')).ok, false);
assert.equal(JSON.parse(verify_json(cnf, encode('0\n'), 'unknown')).ok, false);
const paper = await readFile('examples/paper.cnf', 'utf8');
const drat = await readFile('examples/paper.drat');
const rat = JSON.parse(verify_json(paper, drat, 'drat'));
assert.equal(rat.ok, true);
assert.equal(rat.rat, 1);
console.log('JavaScript bindings: all four formats, conversions, RAT and negative cases passed.');
