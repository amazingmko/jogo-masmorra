"""Reduz um modelo do Tripo (GLB de ~2 milhões de triângulos e textura 2K) para o celular.

    python3 tools/reduzir_modelo.py arte/bruto/ambiente/pedra_musgo.glb game/art/ambiente/pedra_musgo.glb 1200 512

Argumentos: entrada, saída, triângulos desejados, tamanho da textura (lado, em px).
Mantém só a cor (sem normal map nem metal/rugosidade: o jogo usa material fosco).
Requer: pip install trimesh pymeshlab pillow
"""
import os
import sys
import tempfile

import numpy as np
import pymeshlab
import trimesh
from PIL import Image


def main() -> None:
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
    material = trimesh.visual.material.PBRMaterial(
        baseColorTexture=img, metallicFactor=0.0, roughnessFactor=1.0, name=os.path.splitext(os.path.basename(dst))[0])
    uv = low.visual.uv if hasattr(low.visual, "uv") and low.visual.uv is not None else np.zeros((len(low.vertices), 2))
    low.visual = trimesh.visual.TextureVisuals(uv=uv, material=material)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    low.export(dst)
    print(f"  -> {dst}: {len(low.faces)} triângulos, textura {tex_size}px, {os.path.getsize(dst) // 1024} KB")


if __name__ == "__main__":
    main()
