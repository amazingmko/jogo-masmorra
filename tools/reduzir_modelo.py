"""Reduz um modelo do Tripo (GLB de ~2 milhões de triângulos e textura 2K) para o celular.

    python3 tools/reduzir_modelo.py arte/bruto/ambiente/pedra_musgo.glb game/art/ambiente/pedra_musgo.glb 1200 512

Argumentos: entrada, saída, triângulos desejados, tamanho da textura (lado, em px).
Mantém só a cor (sem normal map nem metal/rugosidade: o jogo usa material fosco).
Grava as normais suaves (sem elas o Godot calcula normais "de faceta" e as folhas ficam escuras).
Folhagem (moita, samambaia, árvore, palmeira, bromélia): normais apontando para fora da copa e
material dos dois lados, como se faz com plantas em jogo: a planta inteira recebe luz por igual.

Só refazer as normais de um modelo já reduzido:
    python3 tools/reduzir_modelo.py --normais game/art/ambiente/moita.glb
Requer: pip install trimesh pymeshlab pillow
"""
import os
import sys
import tempfile

import numpy as np
import pymeshlab
import trimesh
from PIL import Image


FOLHAGEM = {"moita", "samambaia", "arvore_borda", "palmeira", "bromelia", "taboca"}


def finish(mesh: trimesh.Trimesh, name: str, texture: Image.Image, dst: str) -> None:
    """Normais + material fosco, e grava o GLB."""
    foliage = name in FOLHAGEM
    if foliage:
        lo, hi = mesh.bounds
        center = (lo + hi) * 0.5
        center[1] = lo[1] + (hi[1] - lo[1]) * 0.35
        d = (mesh.vertices - center) * np.array([1.0, 0.6, 1.0]) + np.array([0.0, (hi[1] - lo[1]) * 0.3, 0.0])
        normals = d / np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-6)
    else:
        normals = mesh.vertex_normals
    material = trimesh.visual.material.PBRMaterial(
        baseColorTexture=texture, metallicFactor=0.0, roughnessFactor=1.0, doubleSided=foliage, name=name)
    uv = mesh.visual.uv if hasattr(mesh.visual, "uv") and mesh.visual.uv is not None else np.zeros((len(mesh.vertices), 2))
    out = trimesh.Trimesh(vertices=mesh.vertices, faces=mesh.faces, vertex_normals=normals, process=False)
    out.visual = trimesh.visual.TextureVisuals(uv=uv, material=material)
    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    out.export(dst, include_normals=True)


def main() -> None:
    if sys.argv[1] == "--normais":
        for path in sys.argv[2:]:
            mesh = trimesh.load(path, force="mesh", process=False)
            tex = mesh.visual.material.baseColorTexture
            finish(mesh, os.path.splitext(os.path.basename(path))[0], tex.convert("RGB"), path)
            print("normais:", path)
        return
    src, dst, target, tex_size = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    scene = trimesh.load(src, force="scene")
    meshes = list(scene.dump(concatenate=False))
    mesh = meshes[0] if len(meshes) == 1 else trimesh.util.concatenate(meshes)
    texture = mesh.visual.material.baseColorTexture
    print(f"{os.path.basename(src)}: {len(mesh.faces)} triângulos, textura {texture.size}")

    with tempfile.TemporaryDirectory() as tmp:
        hi = os.path.join(tmp, "hi.obj")
        lo = os.path.join(tmp, "lo.obj")
        mesh.export(hi, include_texture=True)  # com as coordenadas de textura (UV)
        ms = pymeshlab.MeshSet()
        ms.load_new_mesh(hi)
        if not ms.current_mesh().has_wedge_tex_coord() and ms.current_mesh().has_vertex_tex_coord():
            ms.compute_texcoord_transfer_vertex_to_wedge()
        ms.meshing_merge_close_vertices(threshold=pymeshlab.PercentageValue(0.001))
        # Primeiro um corte rápido (sem olhar a textura) até ~20x o alvo, depois o fino que respeita a UV.
        if ms.current_mesh().face_number() > target * 20:
            ms.meshing_decimation_quadric_edge_collapse_with_texture(
                targetfacenum=target * 20, qualitythr=0.3, extratcoordw=1.0, preserveboundary=True)
        ms.meshing_decimation_quadric_edge_collapse_with_texture(
            targetfacenum=target, qualitythr=0.5, extratcoordw=1.0, preserveboundary=True,
            boundaryweight=1.0, optimalplacement=True, preservenormal=True, planarquadric=True)
        ms.save_current_mesh(lo, save_wedge_texcoord=True, save_textures=False)
        low = trimesh.load(lo, force="mesh", process=False)

    img = texture.convert("RGB").resize((tex_size, tex_size), Image.LANCZOS)
    finish(low, os.path.splitext(os.path.basename(dst))[0], img, dst)
    print(f"  -> {dst}: {len(low.faces)} triângulos, textura {tex_size}px, {os.path.getsize(dst) // 1024} KB")


if __name__ == "__main__":
    main()
