// Prepara um GLB animado do Tripo para o jogo: altura de 1,70 m, sem deslocamento do quadril
// (o jogo move o herói), renomeia as animações e corta só o golpe do ataque.
//   node tools/prep_anim.mjs arte/bruto/icamiaba_animado.glb game/art/herois/icamiaba.glb
// Requer: npm i @gltf-transform/core
import { NodeIO } from '@gltf-transform/core';
const [,, src, dst] = process.argv;
const io = new NodeIO();
const doc = await io.read(src);
const root = doc.getRoot();
const HEIGHT = 1.7;
const arm = root.listNodes().find(n => n.getName() === 'Armature');
arm.setScale([HEIGHT, HEIGHT, HEIGHT]);
const hips = root.listNodes().find(n => n.getName() === 'mixamorig:Hips');
const rest = hips.getTranslation();
// O 'slash' e o 'chop' do Tripo são iguais (dois golpes seguidos): cada um vira um golpe do combo.
const RENAME = { idle: 'idle', walk: 'walk', run: 'run', hit_to_body_01: 'dano', fall: 'morte', slash: 'ataque1', chop: 'ataque2' };
const TRIM = { ataque1: [0.3, 1.6], ataque2: [1.6, 2.75] };
for (const anim of root.listAnimations()) {
  const old = anim.getName();
  if (!(old in RENAME)) { anim.dispose(); continue; }
  const name = RENAME[old];
  anim.setName(name);
  const win = TRIM[name];
  for (const ch of anim.listChannels()) {
    const s = ch.getSampler();
    let t = Array.from(s.getInput().getArray());
    let v = Array.from(s.getOutput().getArray());
    const n = s.getOutput().getElementSize();
    // sem deslocamento: o quadril fica no lugar (X/Z), só sobe e desce (Y)
    if (ch.getTargetNode() === hips && ch.getTargetPath() === 'translation') {
      for (let k = 0; k < t.length; k++) { v[k*3] = rest[0]; v[k*3+2] = rest[2]; }
    }
    if (win) {
      // valor em qualquer instante (interpolação linear; rotações renormalizadas)
      const at = (x) => {
        if (x <= t[0]) return v.slice(0, n);
        for (let k = 1; k < t.length; k++) if (t[k] >= x) {
          const a = (x - t[k-1]) / Math.max(t[k] - t[k-1], 1e-6);
          const r = v.slice((k-1)*n, k*n).map((p, i) => p + (v[k*n+i] - p) * a);
          if (n === 4) { const m = Math.hypot(...r) || 1; return r.map(q => q / m); }
          return r;
        }
        return v.slice((t.length-1)*n, t.length*n);
      };
      const inner = t.map((x, k) => x > win[0] + 1e-4 && x < win[1] - 1e-4 ? k : -1).filter(k => k >= 0);
      const nt = [0, ...inner.map(k => t[k] - win[0]), win[1] - win[0]];
      const nv = [...at(win[0]), ...inner.flatMap(k => v.slice(k*n, k*n+n)), ...at(win[1])];
      t = nt; v = nv;
    }
    s.setInput(doc.createAccessor().setType('SCALAR').setArray(new Float32Array(t)).setBuffer(root.listBuffers()[0]));
    s.setOutput(doc.createAccessor().setType(s.getOutput().getType()).setArray(new Float32Array(v)).setBuffer(root.listBuffers()[0]));
  }
}
// Algumas animações do Tripo começam com o corpo virado para o lado: gira o quadril
// para que o primeiro quadro olhe para o mesmo lado da 'idle'.
const ALIGN = ['morte'];
// e outras vêm giradas no eixo vertical: corrige com um giro fixo (graus)
const YAW = { dano: Number(process.env.DANO_YAW ?? 45) };
const qmul = (a, b) => [
  a[3]*b[0] + a[0]*b[3] + a[1]*b[2] - a[2]*b[1],
  a[3]*b[1] - a[0]*b[2] + a[1]*b[3] + a[2]*b[0],
  a[3]*b[2] + a[0]*b[1] - a[1]*b[0] + a[2]*b[3],
  a[3]*b[3] - a[0]*b[0] - a[1]*b[1] - a[2]*b[2]];
const qinv = (q) => [-q[0], -q[1], -q[2], q[3]];
const hipsRot = (anim) => anim.listChannels().find(c => c.getTargetNode() === hips && c.getTargetPath() === 'rotation');
const idle = root.listAnimations().find(a => a.getName() === 'idle');
const ref = Array.from(hipsRot(idle).getSampler().getOutput().getArray().slice(0, 4));
for (const anim of root.listAnimations()) {
  if (!ALIGN.includes(anim.getName())) continue;
  const out = hipsRot(anim).getSampler().getOutput();
  const v = out.getArray();
  const fix = qmul(ref, qinv(Array.from(v.slice(0, 4))));
  for (let k = 0; k < v.length; k += 4) v.set(qmul(fix, Array.from(v.slice(k, k + 4))), k);
  out.setArray(v);
  console.log('alinhada:', anim.getName());
}
for (const anim of root.listAnimations()) {
  const deg = YAW[anim.getName()];
  if (!deg) continue;
  const h = deg * Math.PI / 360;
  const fix = [0, Math.sin(h), 0, Math.cos(h)];
  const out = hipsRot(anim).getSampler().getOutput();
  const v = out.getArray();
  for (let k = 0; k < v.length; k += 4) v.set(qmul(fix, Array.from(v.slice(k, k + 4))), k);
  out.setArray(v);
  console.log('girada:', anim.getName(), deg);
}
// limpa acessores sem uso
for (const a of root.listAccessors()) if (a.listParents().length <= 1) a.dispose();
await io.write(dst, doc);
console.log(root.listAnimations().map(a => a.getName()).join(', '));
