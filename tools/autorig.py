"""Esqueleto e pesos de pele por código, para os bichos da Tripo (malha parada, sem ossos).

  python3 tools/autorig.py quadrupede <modelo.glb> <saida.glb> --base game/art/inimigos/animados/queixada.glb
      Quadrúpede (onça): copia o esqueleto da queixada do Anything World, encaixa cada osso no corpo
      do bicho novo (pernas achadas pelos grupos de vértices no chão) e copia as animações de
      parado/andar/correr (os ossos têm as mesmas rotações de descanso, então as curvas servem).
  python3 tools/autorig.py artropode <modelo.glb> <saida.glb> --pernas 8
      Aranha/formiga: corpo (abdômen, tórax, cabeça) e cada perna com 3 ossos; a animação é feita
      no jogo (ArthroPose).
  python3 tools/autorig.py serpente <modelo.glb> <saida.glb>
      Cobra: uma corrente de ossos ao longo do corpo (da cabeça ao rabo); o rastejar é feito no
      jogo (SerpentPose).

Opções: --frente x|-x|z|-z (para onde a cabeça aponta no modelo; padrão x).
Requer: pip install pygltflib numpy
"""
import sys, argparse, struct
import numpy as np
import pygltflib
from pygltflib import GLTF2, Node, Skin, Accessor, BufferView, Animation, AnimationChannel, \
    AnimationChannelTarget, AnimationSampler, Scene

# ---------------------------------------------------------------- utilidades de glTF


def read_acc(g, i):
    a = g.accessors[i]
    bv = g.bufferViews[a.bufferView]
    comp = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a.componentType]
    nc = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a.type]
    off = (bv.byteOffset or 0) + (a.byteOffset or 0)
    blob = g.binary_blob()
    stride = bv.byteStride
    item = np.dtype(comp).itemsize * nc
    if stride and stride != item:
        raw = np.frombuffer(blob, np.uint8, a.count * stride, off).reshape(a.count, stride)[:, :item]
        arr = np.frombuffer(raw.tobytes(), comp)
    else:
        arr = np.frombuffer(blob, comp, a.count * nc, off)
    arr = arr.reshape(-1, nc) if nc > 1 else arr.copy()
    return np.array(arr)


def quat_mul(a, b):  # (x, y, z, w)
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw * bx + ax * bw + ay * bz - az * by,
                     aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw,
                     aw * bw - ax * bx - ay * by - az * bz])


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mat_quat(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        return np.array([(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s])
    i = int(np.argmax([m[0, 0], m[1, 1], m[2, 2]]))
    if i == 0:
        s = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        return np.array([0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s])
    if i == 1:
        s = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        return np.array([(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s])
    s = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
    return np.array([(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s])


def look_rot(direction, up=(0, 1, 0)):
    """Rotação cujo eixo Y local aponta em `direction` (convenção de osso do glTF/Blender)."""
    y = np.asarray(direction, float)
    y = y / (np.linalg.norm(y) + 1e-9)
    upv = np.asarray(up, float)
    if abs(np.dot(y, upv)) > 0.95:
        upv = np.array([0, 0, 1.0])
    x = np.cross(y, upv)
    x /= np.linalg.norm(x) + 1e-9
    z = np.cross(x, y)
    return np.stack([x, y, z], axis=1)


class Writer:
    """Monta um GLB novo: malha (posição, normal, uv, ossos, pesos), textura, esqueleto e animações."""

    def __init__(self):
        self.g = GLTF2()
        self.g.asset = pygltflib.Asset(version='2.0', generator='jogo-masmorra autorig')
        self.blob = bytearray()

    def add(self, arr, target=None, kind=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        while len(self.blob) % 4:
            self.blob.append(0)
        off = len(self.blob)
        self.blob += arr.tobytes()
        bv = BufferView(buffer=0, byteOffset=off, byteLength=arr.nbytes, target=target)
        self.g.bufferViews.append(bv)
        comp = {np.dtype(np.float32): 5126, np.dtype(np.uint32): 5125, np.dtype(np.uint16): 5123,
                np.dtype(np.uint8): 5121}[arr.dtype]
        nc = arr.shape[1] if arr.ndim > 1 else 1
        if kind is None:
            kind = {1: 'SCALAR', 2: 'VEC2', 3: 'VEC3', 4: 'VEC4', 16: 'MAT4'}[nc]
        acc = Accessor(bufferView=len(self.g.bufferViews) - 1, componentType=comp, count=len(arr), type=kind)
        if minmax:
            flat = arr.reshape(len(arr), -1)
            acc.min = flat.min(0).astype(float).tolist()
            acc.max = flat.max(0).astype(float).tolist()
        self.g.accessors.append(acc)
        return len(self.g.accessors) - 1

    def save(self, path):
        self.g.buffers = [pygltflib.Buffer(byteLength=len(self.blob))]
        self.g.set_binary_blob(bytes(self.blob))
        self.g.save_binary(path)


def load_mesh(path):
    g = GLTF2().load(path)
    p = g.meshes[0].primitives[0]
    pos = read_acc(g, p.attributes.POSITION).astype(np.float32)
    nrm = read_acc(g, p.attributes.NORMAL).astype(np.float32) if p.attributes.NORMAL is not None else None
    uv = read_acc(g, p.attributes.TEXCOORD_0).astype(np.float32)
    idx = read_acc(g, p.indices).astype(np.uint32)
    img = None
    if g.images:
        im = g.images[0]
        bv = g.bufferViews[im.bufferView]
        img = (g.binary_blob()[(bv.byteOffset or 0):(bv.byteOffset or 0) + bv.byteLength], im.mimeType)
    return pos, nrm, uv, idx, img


def to_forward_z(v, front):
    """Gira o modelo para a cabeça apontar para +Z (Y para cima)."""
    x, y, z = v[:, 0], v[:, 1], v[:, 2]
    if front == 'x':
        return np.stack([-z, y, x], 1)
    if front == '-x':
        return np.stack([z, y, -x], 1)
    if front == '-z':
        return np.stack([-x, y, -z], 1)
    return v.copy()


def skin_weights(verts, seg_a, seg_b, allowed=None, power=4.0, top=3):
    """Pesos pela distância de cada vértice a cada osso (segmento). allowed[v] = lista de ossos possíveis."""
    n, m = len(verts), len(seg_a)
    ab = seg_b - seg_a
    ab2 = np.maximum((ab * ab).sum(1), 1e-9)
    joints = np.zeros((n, 4), np.uint16)
    weights = np.zeros((n, 4), np.float32)
    for i, p in enumerate(verts):
        t = np.clip(((p - seg_a) * ab).sum(1) / ab2, 0, 1)
        d = np.linalg.norm(seg_a + ab * t[:, None] - p, axis=1) + 1e-4
        if allowed is not None:
            mask = np.full(m, np.inf)
            mask[allowed[i]] = 0
            d = d + mask
        order = np.argsort(d)[:top]
        w = 1.0 / d[order] ** power
        w = np.where(np.isfinite(w), w, 0)
        w /= w.sum()
        joints[i, :len(order)] = order
        weights[i, :len(order)] = w
    return joints, weights


def write_rigged(out, verts, nrm, uv, idx, img, bones, joints, weights, root_rot=None, anims=None, name='bicho'):
    """bones: lista de dicts {name, parent, t (local), r (quat local)}; verts no espaço do pai do esqueleto."""
    w = Writer()
    g = w.g
    if nrm is None:
        nrm = np.zeros_like(verts)
        tri = verts[idx.reshape(-1, 3)]
        fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        for k in range(3):
            np.add.at(nrm, idx.reshape(-1, 3)[:, k], fn)
        nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
    a_pos = w.add(verts.astype(np.float32), 34962, minmax=True)
    a_nrm = w.add(nrm.astype(np.float32), 34962)
    a_uv = w.add(uv.astype(np.float32), 34962)
    a_j = w.add(joints.astype(np.uint16), 34962)
    a_w = w.add(weights.astype(np.float32), 34962)
    a_i = w.add(idx.astype(np.uint32), 34963)
    mat = pygltflib.Material(name=name, doubleSided=True,
                             pbrMetallicRoughness=pygltflib.PbrMetallicRoughness(metallicFactor=0.0, roughnessFactor=1.0))
    if img is not None:
        data, mime = img
        while len(w.blob) % 4:
            w.blob.append(0)
        off = len(w.blob)
        w.blob += data
        g.bufferViews.append(BufferView(buffer=0, byteOffset=off, byteLength=len(data)))
        g.images.append(pygltflib.Image(bufferView=len(g.bufferViews) - 1, mimeType=mime or 'image/png'))
        g.samplers.append(pygltflib.Sampler())
        g.textures.append(pygltflib.Texture(source=0, sampler=0))
        mat.pbrMetallicRoughness.baseColorTexture = pygltflib.TextureInfo(index=0)
    g.materials.append(mat)
    prim = pygltflib.Primitive(attributes=pygltflib.Attributes(POSITION=a_pos, NORMAL=a_nrm, TEXCOORD_0=a_uv,
                                                               JOINTS_0=a_j, WEIGHTS_0=a_w), indices=a_i, material=0)
    g.meshes.append(pygltflib.Mesh(name=name, primitives=[prim]))
    # nós dos ossos
    base = len(g.nodes)
    for b in bones:
        g.nodes.append(Node(name=b['name'], translation=[float(x) for x in b['t']], rotation=[float(x) for x in b['r']]))
    for i, b in enumerate(bones):
        if b['parent'] >= 0:
            g.nodes[base + b['parent']].children.append(base + i)
    # matrizes inversas de encaixe (pose de descanso)
    glob = []
    for b in bones:
        m = np.eye(4)
        m[:3, :3] = quat_mat(b['r'])
        m[:3, 3] = b['t']
        if b['parent'] >= 0:
            m = glob[b['parent']] @ m
        glob.append(m)
    ibm = np.stack([np.linalg.inv(m).T.reshape(16) for m in glob]).astype(np.float32)
    a_ibm = w.add(ibm, kind='MAT4')
    roots = [base + i for i, b in enumerate(bones) if b['parent'] < 0]
    g.skins.append(Skin(joints=[base + i for i in range(len(bones))], inverseBindMatrices=a_ibm, skeleton=roots[0]))
    mesh_node = len(g.nodes)
    g.nodes.append(Node(name=name, mesh=0, skin=0))
    rig = len(g.nodes)
    g.nodes.append(Node(name='rig', children=[mesh_node] + roots,
                        rotation=[float(x) for x in root_rot] if root_rot is not None else None))
    g.scenes.append(Scene(nodes=[rig]))
    g.scene = 0
    for an in anims or []:
        anim = Animation(name=an['name'])
        for ch in an['channels']:
            ti = w.add(ch['t'].astype(np.float32), minmax=True)
            vi = w.add(ch['v'].astype(np.float32))
            anim.samplers.append(AnimationSampler(input=ti, output=vi, interpolation='LINEAR'))
            anim.channels.append(AnimationChannel(sampler=len(anim.samplers) - 1,
                                                  target=AnimationChannelTarget(node=base + ch['bone'], path=ch['path'])))
        g.animations.append(anim)
    w.save(out)


# ---------------------------------------------------------------- quadrúpede (a partir da queixada)

def quadruped(args):
    tg = GLTF2().load(args.base)
    tnodes = tg.nodes
    rig_i = next(i for i, n in enumerate(tnodes) if n.name == 'rig')
    rig_rot = np.array(tnodes[rig_i].rotation)
    R_rig = quat_mat(rig_rot)
    joint_ids = tg.skins[0].joints
    names = [tnodes[j].name for j in joint_ids]
    parent_of = {}
    for i, n in enumerate(tnodes):
        for c in n.children or []:
            parent_of[c] = i
    bones = []
    for j in joint_ids:
        p = parent_of.get(j)
        bones.append({'name': tnodes[j].name, 'parent': joint_ids.index(p) if p in joint_ids else -1,
                      't': np.array(tnodes[j].translation or [0, 0, 0], float),
                      'r': np.array(tnodes[j].rotation or [0, 0, 0, 1], float)})
    # posição de descanso de cada osso no espaço do rig (S) e no mundo (Y para cima, +Z frente)
    G = []
    for b in bones:
        m = np.eye(4)
        m[:3, :3] = quat_mat(b['r'])
        m[:3, 3] = b['t']
        if b['parent'] >= 0:
            m = G[b['parent']] @ m
        G.append(m)
    S = np.array([m[:3, 3] for m in G])
    W = S @ R_rig.T
    idx = {n: i for i, n in enumerate(names)}
    legs = {k: [idx[f'leg_{k}_{s}'] for s in ('top0', 'top1', 'bot0', 'bot1', 'bot2')]
            for k in ('front_left', 'front_right', 'hind_left', 'hind_right')}
    leg_bones = {i for v in legs.values() for i in v}
    ground_t = W[[v[-1] for v in legs.values()], 1].min()

    # modelo novo, cabeça para +Z
    pos, nrm, uv, tri, img = load_mesh(args.modelo)
    V = to_forward_z(pos, args.frente)
    Nm = to_forward_z(nrm, args.frente) if nrm is not None else None
    ground = V[:, 1].min()
    H = V[:, 1].max() - ground
    # escala: o comprimento do tronco (pernas da frente às de trás) igual ao da queixada
    low = V[V[:, 1] < ground + 0.18 * H]
    # patas da frente x de trás: o maior vão no eixo Z entre os vértices rentes ao chão
    zs_sorted = np.sort(low[:, 2])
    gaps = np.diff(zs_sorted)
    mid = (zs_sorted > np.percentile(zs_sorted, 15))[:-1] & (zs_sorted < np.percentile(zs_sorted, 85))[:-1]
    gi = np.argmax(np.where(mid, gaps, 0))
    zc = (zs_sorted[gi] + zs_sorted[gi + 1]) * 0.5
    feet = {}
    for k, (zs, xs) in {'front_left': (1, 1), 'front_right': (1, -1), 'hind_left': (-1, 1), 'hind_right': (-1, -1)}.items():
        sel = low[(np.sign(low[:, 2] - zc) == zs) & (np.sign(low[:, 0]) == xs)]
        # o rabo caído pode encostar no chão atrás: fica só com o grupo perto das patas
        if zs < 0:
            zmax = sel[:, 2].max()
            sel = sel[sel[:, 2] > zmax - 0.12 * (V[:, 2].max() - V[:, 2].min())]
        feet[k] = np.array([sel[:, 0].mean(), ground, sel[:, 2].mean()])
    span_t = np.mean([W[legs['front_left'][-1], 2], W[legs['front_right'][-1], 2]]) - \
        np.mean([W[legs['hind_left'][-1], 2], W[legs['hind_right'][-1], 2]])
    span_n = np.mean([feet['front_left'][2], feet['front_right'][2]]) - np.mean([feet['hind_left'][2], feet['hind_right'][2]])
    s = span_t / span_n
    V = (V - np.array([0, ground, 0])) * s
    for k in feet:
        feet[k] = (feet[k] - np.array([0, ground, 0])) * s
    H *= s
    # alturas: a queixada tem o dorso na altura `back_t`; o bicho novo, na mediana do topo do tronco
    torso = V[(V[:, 2] > min(f[2] for f in feet.values())) & (V[:, 2] < max(f[2] for f in feet.values()))]
    back_n = np.percentile(torso[:, 1], 97)
    belly_n = np.percentile(torso[:, 1], 30)
    spine_ids = [i for i in range(len(bones)) if i not in leg_bones]
    back_t = W[spine_ids, 1].max()
    ky = (back_n * 0.82) / (back_t - ground_t)
    zf_t = np.mean([W[legs['front_left'][-1], 2], W[legs['front_right'][-1], 2]])
    zh_t = np.mean([W[legs['hind_left'][-1], 2], W[legs['hind_right'][-1], 2]])
    zf_n = np.mean([feet['front_left'][2], feet['front_right'][2]])
    zh_n = np.mean([feet['hind_left'][2], feet['hind_right'][2]])
    kz = (zf_n - zh_n) / (zf_t - zh_t)
    width_n = np.percentile(np.abs(torso[:, 0]), 95)
    width_t = np.abs(W[[legs['front_left'][0], legs['front_right'][0]], 0]).max()
    kx = width_n * 0.8 / max(width_t, 1e-6)

    def map_body(p):
        return np.array([p[0] * kx, (p[1] - ground_t) * ky, zh_n + (p[2] - zh_t) * kz])

    target = np.zeros_like(W)
    for i in range(len(bones)):
        if i not in leg_bones:
            target[i] = map_body(W[i])
    # cabeça: entre o pescoço e o focinho, na altura da cabeça do bicho novo
    head_i, neck_i = idx['head0'], idx['neck0']
    front = V[V[:, 2] > zf_n]
    nose_v = front[np.argmax(front[:, 2])]
    head_zone = front[front[:, 2] > nose_v[2] - 0.3 * (nose_v[2] - zf_n)]
    nose = np.array([0.0, np.median(head_zone[:, 1]), nose_v[2]])
    neck_p = target[neck_i]
    target[neck_i] = np.array([0.0, max(neck_p[1], nose[1] * 0.95), neck_p[2]])
    target[head_i] = target[neck_i] + (nose - target[neck_i]) * 0.45
    # rabo: aponta para onde o rabo do modelo vai
    back = V[V[:, 2] < zh_n]
    tail_tip = back[np.argmin(back[:, 2])]
    pelvis_i, tail_i = idx['pelvis'], idx['tail0']
    for k, chain in legs.items():
        top = map_body(W[chain[0]])
        foot = feet[k]
        foot_t = W[chain[-1]]
        top_t = W[chain[0]]
        for j, b in enumerate(chain):
            # fração da altura (descanso da queixada) e o "desvio" horizontal relativo à linha topo-casco
            f = (W[b, 1] - foot_t[1]) / max(top_t[1] - foot_t[1], 1e-6)
            line_t = foot_t + (top_t - foot_t) * f
            off = (W[b] - line_t) * np.array([kx, 0, kz])
            line_n = foot + (top - foot) * f
            target[b] = line_n + off
        target[chain[-1]][1] = max(target[chain[-1]][1], 0.01 * H)
    # rabo comprido (onça): mais ossos depois de tail0, seguindo a malha
    extra = []
    if np.linalg.norm(tail_tip - target[tail_i]) > 0.35 * (zf_n - zh_n):
        base_p = target[tail_i]
        tail_pts = back[back[:, 2] < base_p[2]]
        n_extra = 3
        last = tail_i
        for e in range(n_extra):
            frac = (e + 1) / (n_extra + 0.3)
            zz = base_p[2] + (tail_tip[2] - base_p[2]) * frac
            near = tail_pts[np.abs(tail_pts[:, 2] - zz) < 0.06 * (zf_n - zh_n) + 1e-3]
            p = near.mean(0) if len(near) else base_p + (tail_tip - base_p) * frac
            extra.append(p)
    # converte as posições-alvo (mundo) para o espaço do rig e monta as translações locais com as
    # MESMAS rotações de descanso da queixada (assim as curvas de animação servem como estão)
    R_inv = R_rig.T
    targetS = target @ R_inv.T
    Grot = []
    new_bones = []
    for i, b in enumerate(bones):
        if b['parent'] < 0:
            gr = quat_mat(b['r'])
            t_local = targetS[i]
        else:
            pr = Grot[b['parent']]
            gr = pr @ quat_mat(b['r'])
            t_local = pr.T @ (targetS[i] - targetS[b['parent']])
        Grot.append(gr)
        new_bones.append({'name': b['name'], 'parent': b['parent'], 't': t_local, 'r': b['r']})
    prev, prevS = tail_i, targetS[tail_i]
    for e, p in enumerate(extra):
        pS = p @ R_inv.T
        pr = Grot[prev]
        new_bones.append({'name': f'tail{e + 1}', 'parent': prev, 't': pr.T @ (pS - prevS), 'r': np.array([0, 0, 0, 1.0])})
        Grot.append(pr)
        prev, prevS = len(new_bones) - 1, pS
    # pesos: perna pega só a sua perna (+ ombro), o resto pega o tronco
    allW = np.vstack([target] + ([np.array(extra)] if extra else []))
    nb = len(new_bones)
    seg_a = np.zeros((nb, 3))
    seg_b = np.zeros((nb, 3))
    children = {i: [c for c in range(nb) if new_bones[c]['parent'] == i] for i in range(nb)}
    for i in range(nb):
        seg_a[i] = allW[i]
        kids = [c for c in children[i] if c not in leg_bones] or children[i]
        if kids:
            seg_b[i] = allW[kids[0]]
        elif i == head_i:
            seg_b[i] = nose
        elif new_bones[i]['name'].startswith('tail'):
            seg_b[i] = tail_tip
        else:
            par = new_bones[i]['parent']
            seg_b[i] = allW[i] + (allW[i] - allW[par]) * 0.5
    body_set = [i for i in range(nb) if i not in leg_bones]
    allowed = []
    belly = belly_n
    for v in V:
        if v[1] < belly:
            best = min(legs, key=lambda k: np.hypot(v[0] - feet[k][0], v[2] - feet[k][2]))
            if np.hypot(v[0] - feet[best][0], v[2] - feet[best][2]) < 0.35 * (zf_n - zh_n) and \
                    (v[2] > zh_n - 0.25 * (zf_n - zh_n)):
                allowed.append(legs[best])
                continue
        allowed.append(body_set + [legs[k][0] for k in legs])
    joints, weights = skin_weights(V, seg_a, seg_b, allowed)
    # animações da queixada: rotações iguais; a translação do osso raiz vira a nova (+ o balanço escalado)
    anims = []
    for an in tg.animations:
        chans = []
        for ch in an.channels:
            node = ch.target.node
            if node not in joint_ids:
                continue
            bi = joint_ids.index(node)
            smp = an.samplers[ch.sampler]
            t = read_acc(tg, smp.input).reshape(-1)
            v = read_acc(tg, smp.output)
            if ch.target.path == 'translation':
                rest = bones[bi]['t']
                v = new_bones[bi]['t'] + (v - rest) * np.array([kx, kz, ky])
            elif ch.target.path != 'rotation':
                continue
            chans.append({'bone': bi, 'path': ch.target.path, 't': t, 'v': v})
        anims.append({'name': an.name, 'channels': chans})
    VS = V @ R_inv.T
    NS = (Nm @ R_inv.T) if Nm is not None else None
    write_rigged(args.saida, VS, NS, uv, tri, img, new_bones, joints, weights, rig_rot, anims, 'onca')
    print('ossos', nb, 'vértices', len(V), 'escala', round(s, 3), 'rabo extra', len(extra))


# ---------------------------------------------------------------- comum aos ossos "livres"

def free_bones(points, parents, names, tips=None):
    """Ossos com o eixo Y apontando para o filho (ou para `tips[i]` se não tiver filho).
    points: posições globais (já no espaço do rig = mundo, sem rotação do rig)."""
    n = len(points)
    kids = {i: [c for c in range(n) if parents[c] == i] for i in range(n)}
    rots = []
    for i in range(n):
        if kids[i]:
            d = points[kids[i][0]] - points[i]
        elif tips is not None and tips.get(i) is not None:
            d = tips[i] - points[i]
        else:
            d = points[i] - points[parents[i]] if parents[i] >= 0 else np.array([0, 0, 1.0])
        rots.append(look_rot(d))
    bones = []
    for i in range(n):
        if parents[i] < 0:
            t, r = points[i], rots[i]
        else:
            pr = rots[parents[i]]
            t, r = pr.T @ (points[i] - points[parents[i]]), pr.T @ rots[i]
        bones.append({'name': names[i], 'parent': parents[i], 't': t, 'r': mat_quat(r)})
    return bones


def seg_ends(points, parents, tips=None):
    n = len(points)
    b = np.zeros_like(points)
    for i in range(n):
        kids = [c for c in range(n) if parents[c] == i]
        if kids:
            b[i] = points[kids[0]]
        elif tips is not None and tips.get(i) is not None:
            b[i] = tips[i]
        else:
            b[i] = points[i] + (points[i] - points[parents[i]]) * 0.5
    return b


# ---------------------------------------------------------------- aranha, formiga

def arthropod(args):
    from sklearn.cluster import KMeans
    pos, nrm, uv, tri, img = load_mesh(args.modelo)
    V = to_forward_z(pos, args.frente)
    Nm = to_forward_z(nrm, args.frente) if nrm is not None else None
    V[:, 1] -= V[:, 1].min()
    size = np.ptp(V[:, 2])
    xmax = np.abs(V[:, 0]).max()
    body_y = np.percentile(V[np.abs(V[:, 0]) < 0.12 * xmax * 2, 1], 50)
    # corpo: a faixa do meio; patas e antenas: o que sai para os lados
    T = 0.33 * xmax
    out = np.abs(V[:, 0]) > T
    legs_total = args.pernas + args.antenas
    labels = np.full(len(V), -1)
    clusters = []
    for side in (1, -1):
        sel = np.where(out & (np.sign(V[:, 0]) == side))[0]
        ang = np.arctan2(V[sel, 2], np.abs(V[sel, 0]))[:, None]
        k = legs_total // 2
        km = KMeans(n_clusters=k, n_init=10, random_state=0).fit(ang)
        order = np.argsort(km.cluster_centers_[:, 0])[::-1]   # da frente para trás
        for rank, c in enumerate(order):
            idxs = sel[km.labels_ == c]
            clusters.append((side, rank, idxs))
    # cada apêndice: raiz na borda do corpo, joelho no ponto mais alto, ponta no mais longe
    names, points, parents, tips = [], [], [], {}
    core = V[~out]
    zc_front = np.percentile(core[:, 2], 95)
    zc_back = np.percentile(core[:, 2], 3)
    roots = []
    info = []
    for side, rank, idxs in clusters:
        P = V[idxs]
        r = np.abs(P[:, 0])
        near = P[r < np.percentile(r, 12)]
        far_d = np.linalg.norm(P[:, [0, 2]] - near.mean(0)[[0, 2]], axis=1)
        tip = P[far_d > np.percentile(far_d, 94)].mean(0)
        knee = P[np.argmax(P[:, 1] - 0.15 * far_d)]
        root = near.mean(0)
        root = np.array([side * T * 0.75, max(body_y, root[1]), root[2]])
        mid_target = (knee + tip) * 0.5
        mid = P[np.argmin(np.linalg.norm(P - mid_target, axis=1))]
        info.append((side, rank, idxs, root, knee, mid, tip))
        roots.append(root[2])
    # quais são antenas: as mais à frente (raiz mais adiante), se houver
    order_front = sorted(range(len(info)), key=lambda i: -info[i][3][2])
    antenna = set(order_front[:args.antenas]) if args.antenas else set()
    # corpo: tórax no meio das raízes das patas; abdômen para trás; cabeça para a frente
    leg_roots_z = [info[i][3][2] for i in range(len(info)) if i not in antenna]
    thorax = np.array([0, body_y, float(np.mean(leg_roots_z))])
    head = np.array([0, body_y, max(leg_roots_z) + 0.25 * (zc_front - max(leg_roots_z))])
    abdomen = np.array([0, body_y, min(leg_roots_z) - 0.1 * (min(leg_roots_z) - zc_back)])
    names += ['torax', 'cabeca', 'abdomen']
    points += [thorax, head, abdomen]
    parents += [-1, 0, 0]
    tips[1] = np.array([0, body_y, zc_front])
    tips[2] = np.array([0, body_y, zc_back])
    leg_bones = {}
    leg_count = {1: 0, -1: 0}
    for i, (side, rank, idxs, root, knee, mid, tip) in enumerate(info):
        lado = 'e' if side > 0 else 'd'
        if i in antenna:
            nm = f'antena_{lado}'
        else:
            leg_count[side] += 1
            nm = f'pata{leg_count[side]}_{lado}'
        parent = 1 if i in antenna else 0
        base = len(points)
        names += [nm + '_0', nm + '_1', nm + '_2']
        points += [root, knee, mid]
        parents += [parent, base, base + 1]
        tips[base + 2] = tip
        leg_bones[i] = [base, base + 1, base + 2]
    points = np.array(points)
    bones = free_bones(points, parents, names, tips)
    ends = seg_ends(points, parents, tips)
    allowed = []
    label_of = np.full(len(V), -1)
    for i, (_, _, idxs, *_r) in enumerate(info):
        label_of[idxs] = i
    body_set = [0, 1, 2]
    for vi in range(len(V)):
        li = label_of[vi]
        if li >= 0:
            allowed.append(leg_bones[li])
        else:
            allowed.append(body_set + [leg_bones[i][0] for i in leg_bones])
    joints, weights = skin_weights(V, points, ends, allowed)
    write_rigged(args.saida, V, Nm, uv, tri, img, bones, joints, weights, None, None, args.nome)
    print('ossos', len(bones), 'apêndices', len(info), 'antenas', len(antenna))


# ---------------------------------------------------------------- cobra

def serpent(args):
    import heapq
    from scipy.spatial import cKDTree
    pos, nrm, uv, tri, img = load_mesh(args.modelo)
    V = to_forward_z(pos, args.frente)
    Nm = to_forward_z(nrm, args.frente) if nrm is not None else None
    V[:, 1] -= V[:, 1].min()
    # distância "ao longo do corpo" a partir da ponta do focinho, andando pelas arestas dos
    # triângulos (um atalho pelo ar entre duas voltas do "S" estragaria a conta)
    from collections import defaultdict
    adj = defaultdict(list)
    T3 = tri.reshape(-1, 3)
    for a_, b_ in ((0, 1), (1, 2), (2, 0)):
        for u, v in zip(T3[:, a_], T3[:, b_]):
            d = float(np.linalg.norm(V[u] - V[v]))
            adj[int(u)].append((d, int(v)))
            adj[int(v)].append((d, int(u)))
    # vértices repetidos (costura da textura) no mesmo lugar: liga-os com distância zero
    tree = cKDTree(V)
    for u, v in tree.query_pairs(1e-5):
        adj[u].append((0.0, v))
        adj[v].append((0.0, u))
    start = int(np.argmax(V[:, 2]))
    D = np.full(len(V), np.inf)
    D[start] = 0
    heap = [(0.0, start)]
    while heap:
        d, u = heapq.heappop(heap)
        if d > D[u]:
            continue
        for dd, v in adj[u]:
            nd = d + dd
            if nd < D[v]:
                D[v] = nd
                heapq.heappush(heap, (nd, v))
    if not np.isfinite(D).all():
        # pedaço solto da malha: herda a distância do vértice ligado mais perto
        ok = np.where(np.isfinite(D))[0]
        t2 = cKDTree(V[ok])
        bad = np.where(~np.isfinite(D))[0]
        D[bad] = D[ok[t2.query(V[bad])[1]]]
    D[~np.isfinite(D)] = D[np.isfinite(D)].max()
    n = args.ossos
    L = D.max()
    edges = np.linspace(0, L, n + 1)
    pts = []
    for i in range(n + 1):
        lo, hi = edges[max(i - 1, 0)], edges[min(i + 1, n)]
        sel = V[(D >= lo) & (D <= hi)] if i not in (0, n) else V[np.abs(D - edges[i]) < L / n * 0.6]
        pts.append(sel.mean(0))
    pts = np.array(pts)
    pts[:, 1] = np.maximum(pts[:, 1], 0.02 * L)
    names = [f'coluna{i}' for i in range(n)]
    parents = [-1] + list(range(n - 1))
    tips = {n - 1: pts[n]}
    bones = free_bones(pts[:n], parents, names, tips)
    # pesos pela posição ao longo do corpo: mistura dos dois ossos mais próximos
    joints = np.zeros((len(V), 4), np.uint16)
    weights = np.zeros((len(V), 4), np.float32)
    f = np.clip(D / L * n - 0.5, 0, n - 1)
    a = np.floor(f).astype(int)
    b = np.minimum(a + 1, n - 1)
    t = f - a
    joints[:, 0] = a
    joints[:, 1] = b
    weights[:, 0] = 1 - t
    weights[:, 1] = t
    write_rigged(args.saida, V, Nm, uv, tri, img, bones, joints, weights, None, None, args.nome)
    print('ossos', n, 'comprimento', round(L, 3))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('modo')
    ap.add_argument('modelo')
    ap.add_argument('saida')
    ap.add_argument('--base', default='game/art/inimigos/animados/queixada.glb')
    ap.add_argument('--frente', default='x')
    ap.add_argument('--pernas', type=int, default=8)
    ap.add_argument('--antenas', type=int, default=0)
    ap.add_argument('--ossos', type=int, default=14)
    ap.add_argument('--nome', default='bicho')
    args = ap.parse_args()
    {'quadrupede': quadruped, 'artropode': arthropod, 'serpente': serpent}[args.modo](args)


if __name__ == '__main__':
    main()
