// Junta as animações do Mixamo (convertidas de FBX para GLB) num único GLB para o jogo.
//   node tools/mixamo_merge.mjs <pasta com os .glb> <saida.glb>
// Cada arquivo vira uma animação com o nome do jogo (tabela NOMES). O primeiro da lista
// ("parada") fornece o modelo e o esqueleto; os outros entram só com a animação.
// Também: escala de centímetros (Mixamo) para metros e quadril sem deslocamento no chão
// (o jogo é quem move o herói; o quadril só sobe e desce).
// Conversão FBX -> GLB antes: FBX2glTF -b -i arquivo.fbx -o arquivo   (npm i fbx2gltf)
// Requer: npm i @gltf-transform/core
import { NodeIO } from '@gltf-transform/core';
import fs from 'node:fs';
import path from 'node:path';

const [,, dir, dst] = process.argv;
const NOMES = {
  parada: 'idle', andar: 'walk', corrida: 'run',
  golpe1: 'ataque1', golpe2: 'ataque2', golpe3: 'ataque3', golpe4: 'ataque4',
  impacto: 'dano', bloquear: 'bloqueio', morte: 'morte',
  provocar: 'provocar', muralha: 'muralha',  // poderes da classe
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
    const t = s.getInput().getArray().slice();
    const v = s.getOutput().getArray().slice();
    if (node === hips && ch.getTargetPath() === 'translation') {
      for (let k = 0; k < v.length; k += 3) { v[k] = rest[0]; v[k + 2] = rest[2]; }
    }
    const sampler = base.createAnimationSampler()
      .setInterpolation(s.getInterpolation())
      .setInput(base.createAccessor().setType('SCALAR').setArray(t).setBuffer(buffer))
      .setOutput(base.createAccessor().setType(s.getOutput().getType()).setArray(v).setBuffer(buffer));
    anim.addSampler(sampler).addChannel(
      base.createAnimationChannel().setTargetNode(node).setTargetPath(ch.getTargetPath()).setSampler(sampler));
  }
  console.log(`${file} -> ${NOMES[key]}`);
}
for (const a of root.listAccessors()) if (a.listParents().length <= 1) a.dispose();
await io.write(dst, base);
