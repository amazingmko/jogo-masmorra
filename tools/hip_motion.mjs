// Devolve o passo do quadril (X/Z) às animações de ataque de um herói já juntado pelo
// mixamo_merge (que trava o quadril no lugar). Sem isso, os pés "patinam" quando o golpe tem passos.
//   node tools/hip_motion.mjs <pasta dos .glb do Mixamo> game/art/herois/<heroi>.glb livre=golpe1:ataque1 raiz=golpe3:ataque3
//   livre=arquivo:animação  o quadril anda e volta sozinho (o golpe termina onde começou)
//   raiz=arquivo:animação   o golpe avança (termina longe): o quadril continua travado e o caminho
//                           vai para uma animação "raiz_<animação>", que o jogo usa para mover o herói.
import { NodeIO } from '@gltf-transform/core';
import path from 'node:path';

const [,, dir, glb, ...opts] = process.argv;
const io = new NodeIO();
const doc = await io.read(glb);
const root = doc.getRoot();
const buffer = root.listBuffers()[0];
const hips = root.listNodes().find(n => n.getName().endsWith('Hips'));
const rest = hips.getTranslation();

function hipTrack(anim) {
  return anim.listChannels().find(c => c.getTargetNode().getName().endsWith('Hips') && c.getTargetPath() === 'translation');
}

for (const o of opts) {
  const [mode, pair] = o.split('=');
  const [file, animName] = pair.split(':');
  const src = await io.read(path.join(dir, file + '.glb'));
  const srcHip = hipTrack(src.getRoot().listAnimations()[0]);
  const st = srcHip.getSampler().getInput().getArray();
  const sv = srcHip.getSampler().getOutput().getArray();
  const anim = root.listAnimations().find(a => a.getName() === animName);
  if (!anim) { console.log('animação não encontrada:', animName); continue; }
  const ch = hipTrack(anim);
  const t = ch.getSampler().getInput().getArray();
  const v = ch.getSampler().getOutput().getArray().slice();
  // amostra o original no tempo de cada quadro (o merge pode ter cortado o início)
  const at = (x, k) => {
    if (x <= st[0]) return sv[k];
    for (let i = 1; i < st.length; i++) if (st[i] >= x) {
      const a = (x - st[i - 1]) / Math.max(st[i] - st[i - 1], 1e-6);
      return sv[(i - 1) * 3 + k] + (sv[i * 3 + k] - sv[(i - 1) * 3 + k]) * a;
    }
    return sv[(st.length - 1) * 3 + k];
  };
  if (mode === 'livre') {
    for (let i = 0; i < t.length; i++) { v[i * 3] = at(t[i], 0); v[i * 3 + 2] = at(t[i], 2); }
    ch.getSampler().setOutput(doc.createAccessor().setType('VEC3').setArray(v).setBuffer(buffer));
    console.log(`${animName}: quadril livre (de ${file})`);
  } else if (mode === 'raiz') {
    const old = root.listAnimations().find(a => a.getName() === 'raiz_' + animName);
    if (old) old.dispose();
    const rv = new Float32Array(t.length * 3);
    for (let i = 0; i < t.length; i++) { rv[i * 3] = at(t[i], 0) - at(t[0], 0); rv[i * 3 + 1] = rest[1]; rv[i * 3 + 2] = at(t[i], 2) - at(t[0], 2); }
    const sampler = doc.createAnimationSampler().setInterpolation('LINEAR')
      .setInput(doc.createAccessor().setType('SCALAR').setArray(new Float32Array(t)).setBuffer(buffer))
      .setOutput(doc.createAccessor().setType('VEC3').setArray(rv).setBuffer(buffer));
    const ra = doc.createAnimation('raiz_' + animName);
    ra.addSampler(sampler).addChannel(doc.createAnimationChannel().setTargetNode(hips).setTargetPath('translation').setSampler(sampler));
    const n = t.length - 1;
    console.log(`raiz_${animName}: caminho de ${(Math.hypot(rv[n * 3], rv[n * 3 + 2]) * 100).toFixed(2)} m (x100) para o jogo mover o herói`);
  }
}
for (const a of root.listAccessors()) if (a.listParents().length <= 1) a.dispose();
await io.write(glb, doc);
