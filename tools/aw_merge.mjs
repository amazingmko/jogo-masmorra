// Junta as animações do Anything World (idle, walk, run em arquivos separados) num único GLB.
//   node tools/aw_merge.mjs <pasta "animations" do zip> <saida.glb>
// O primeiro (idle) fornece o modelo e o esqueleto; walk e run entram só com a animação.
// O nó raiz ("rig") não anda no chão: o jogo é quem move o bicho.
// Requer: npm i @gltf-transform/core
import { NodeIO } from '@gltf-transform/core';
import fs from 'node:fs';
import path from 'node:path';

const [,, dir, dst] = process.argv;
const find = (anim) => {
  const sub = path.join(dir, anim);
  const f = fs.existsSync(sub) ? fs.readdirSync(sub).find(n => n.endsWith('.glb')) : null;
  return f ? path.join(sub, f) : null;
};
const io = new NodeIO();
const base = await io.read(find('idle'));
const root = base.getRoot();
const buffer = root.listBuffers()[0];
const byName = new Map(root.listNodes().map(n => [n.getName(), n]));
for (const a of root.listAnimations()) a.dispose();
for (const m of root.listMaterials()) m.setMetallicFactor(0).setRoughnessFactor(1);

for (const name of ['idle', 'walk', 'run']) {
  const file = find(name);
  if (!file) { console.log('sem', name); continue; }
  const src = await io.read(file);
  const srcAnim = src.getRoot().listAnimations()[0];
  const anim = base.createAnimation(name);
  for (const ch of srcAnim.listChannels()) {
    const node = byName.get(ch.getTargetNode().getName());
    if (!node) continue;
    const s = ch.getSampler();
    const t = s.getInput().getArray().slice();
    const v = s.getOutput().getArray().slice();
    if (node.getName() === 'rig' && ch.getTargetPath() === 'translation') {
      for (let k = 0; k < v.length; k += 3) { v[k] = v[0]; v[k + 2] = v[2]; }
    }
    const sampler = base.createAnimationSampler()
      .setInterpolation(s.getInterpolation())
      .setInput(base.createAccessor().setType('SCALAR').setArray(t).setBuffer(buffer))
      .setOutput(base.createAccessor().setType(s.getOutput().getType()).setArray(v).setBuffer(buffer));
    anim.addSampler(sampler).addChannel(
      base.createAnimationChannel().setTargetNode(node).setTargetPath(ch.getTargetPath()).setSampler(sampler));
  }
  console.log(`${path.basename(file)} -> ${name}`);
}
await io.write(dst, base);
console.log('gravado', dst);
