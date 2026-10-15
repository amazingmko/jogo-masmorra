// Junta as animações do Mixamo (convertidas de FBX para GLB) num único GLB para o jogo.
//   node tools/mixamo_merge.mjs <pasta com os .glb> <saida.glb> [arquivo=inicio:fim ...]
// Cortes opcionais (segundos), para animações longas: ex. armadilha=0.9:2.9
// Cada arquivo vira uma animação com o nome do jogo (tabela NOMES). O primeiro da lista
// ("parada") fornece o modelo e o esqueleto; os outros entram só com a animação.
// Também: escala de centímetros (Mixamo) para metros e quadril sem deslocamento no chão
// (o jogo é quem move o herói; o quadril só sobe e desce).
// Conversão FBX -> GLB antes: FBX2glTF -b -i arquivo.fbx -o arquivo   (npm i fbx2gltf)
// Requer: npm i @gltf-transform/core
import { NodeIO } from '@gltf-transform/core';
import fs from 'node:fs';
import path from 'node:path';

const [,, dir, dst, ...cuts] = process.argv;
const TRIM = Object.fromEntries(cuts.map(c => { const [k, r] = c.split('='); return [k, r.split(':').map(Number)]; }));
const NOMES = {
  parada: 'idle', andar: 'walk', corrida: 'run',
  golpe1: 'ataque1', golpe2: 'ataque2', golpe3: 'ataque3', golpe4: 'ataque4',
  impacto: 'dano', bloquear: 'bloqueio', morte: 'morte',
  provocar: 'provocar', muralha: 'muralha', armadilha: 'armadilha', harpia: 'harpia',  // poderes da classe
};
const SCALE = 100;
const io = new NodeIO();
const base = await io.read(path.join(dir, 'parada.glb'));
const root = base.getRoot();
const buffer = root.listBuffers()[0];
const byName = new Map(root.listNodes().map(n => [n.getName(), n]));
const sceneRoot = root.listScenes()[0].listChildren()[0];
sceneRoot.setScale([SCALE, SCALE, SCALE]);
const hips = root.listNodes().find(n => n.getName().endsWith('Hips'));
const rest = hips.getTranslation();

for (const a of root.listAnimations()) a.dispose();
// O FBX chega com material 'Phong' convertido em metal brilhante: volta para fosco, sem metal.
for (const m of root.listMaterials()) m.setMetallicFactor(0).setRoughnessFactor(1).setBaseColorFactor([1, 1, 1, 1]);

for (const file of fs.readdirSync(dir).filter(f => f.endsWith('.glb')).sort()) {
  const key = path.basename(file, '.glb');
  if (!(key in NOMES)) { console.log('ignorado:', file); continue; }
  const src = await io.read(path.join(dir, file));
  const srcAnim = src.getRoot().listAnimations()[0];
  const anim = base.createAnimation(NOMES[key]);
  for (const ch of srcAnim.listChannels()) {
    const node = byName.get(ch.getTargetNode().getName());
    if (!node) continue;
    const s = ch.getSampler();
    let t = s.getInput().getArray().slice();
    let v = s.getOutput().getArray().slice();
    if (node === hips && ch.getTargetPath() === 'translation') {
      for (let k = 0; k < v.length; k += 3) { v[k] = rest[0]; v[k + 2] = rest[2]; }
    }
    if (TRIM[key]) [t, v] = trim(t, v, s.getOutput().getElementSize(), TRIM[key]);
    const sampler = base.createAnimationSampler()
      .setInterpolation(s.getInterpolation())
      .setInput(base.createAccessor().setType('SCALAR').setArray(t).setBuffer(buffer))
      .setOutput(base.createAccessor().setType(s.getOutput().getType()).setArray(v).setBuffer(buffer));
    anim.addSampler(sampler).addChannel(
      base.createAnimationChannel().setTargetNode(node).setTargetPath(ch.getTargetPath()).setSampler(sampler));
  }
  console.log(`${file} -> ${NOMES[key]}${TRIM[key] ? ` (cortada ${TRIM[key].join('-')} s)` : ''}`);
}
for (const a of root.listAccessors()) if (a.listParents().length <= 1) a.dispose();

// Recorta [ini, fim] de uma trilha, com valores interpolados nas bordas (rotações renormalizadas).
function trim(t, v, n, [ini, fim]) {
  const at = (x) => {
    if (x <= t[0]) return Array.from(v.slice(0, n));
    for (let k = 1; k < t.length; k++) if (t[k] >= x) {
      const a = (x - t[k - 1]) / Math.max(t[k] - t[k - 1], 1e-6);
      const r = Array.from(v.slice((k - 1) * n, k * n)).map((p, i) => p + (v[k * n + i] - p) * a);
      if (n === 4) { const m = Math.hypot(...r) || 1; return r.map(q => q / m); }
      return r;
    }
    return Array.from(v.slice((t.length - 1) * n, t.length * n));
  };
  const inner = [];
  for (let k = 0; k < t.length; k++) if (t[k] > ini + 1e-4 && t[k] < fim - 1e-4) inner.push(k);
  const nt = [0, ...inner.map(k => t[k] - ini), fim - ini];
  const nv = [...at(ini), ...inner.flatMap(k => Array.from(v.slice(k * n, k * n + n))), ...at(fim)];
  return [new Float32Array(nt), new Float32Array(nv)];
}
await io.write(dst, base);
