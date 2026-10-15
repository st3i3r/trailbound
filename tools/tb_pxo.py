"""Build a .pxo (Pixelorama 1.x project = zip) from PNG layers.

Usage:  python tools/tb_pxo.py out.pxo W H spec.json
spec.json: {"layers": [{"png": "path"|null, "name": str,
                        "opacity": 0-1, "visible": bool, "locked": bool}]}
Layer order: first entry = bottom layer.  Cels are raw RGBA8 bytes at
image_data/frames/1/layer_N (1-based); data.json schema per
Pixelorama 1.2 Project.gd/BaseLayer.gd/BaseCel.gd serialize().
"""
import io, json, sys, zipfile
import numpy as np
from PIL import Image


def rgba_bytes(img, w, h):
    img = img.convert("RGBA").resize((w, h), Image.NEAREST)
    return np.asarray(img, dtype=np.uint8).tobytes()


def build(out, w, h, layers):
    zf = zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED)
    layer_js, cels, blobs = [], [], []
    for i, L in enumerate(layers):
        layer_js.append({
            "name": L["name"], "visible": L.get("visible", True),
            "locked": L.get("locked", False), "blend_mode": 0,
            "clipping_mask": False, "opacity": float(L.get("opacity", 1.0)),
            "ui_color": "(0, 0, 0, 0)", "parent": -1, "effects": [],
            "animated_params": '{"opacity":{}}', "type": 0,
            "new_cels_linked": False, "metadata": {},
        })
        cels.append({"opacity": 1.0, "z_index": 0,
                     "ui_color": "(0, 0, 0, 0)", "metadata": {}})
        if L.get("png"):
            blob = rgba_bytes(Image.open(L["png"]), w, h)
        else:
            blob = bytes(w * h * 4)
        blobs.append(blob)
        zf.writestr(f"image_data/frames/1/layer_{i + 1}", blob)
        zf.writestr(f"image_data/frames/1/indices_layer_{i + 1}",
                    bytes(w * h * 4))
    data = {
        "pixelorama_version": "1.2", "pxo_version": 7,
        "size_x": w, "size_y": h, "color_mode": 0,
        "tile_mode_x_basis_x": 640, "tile_mode_x_basis_y": 0,
        "tile_mode_y_basis_x": 0, "tile_mode_y_basis_y": 384,
        "layers": layer_js, "tags": [], "guides": [],
        "symmetry_points": [0, 0],
        "frames": [{"cels": cels, "duration": 1.0, "metadata": {}}],
        "current_frame": 0,
        "current_layer": len(layers) - 1,
        "brushes": [], "palettes": [],
        "project_current_palette_name": "",
        "reference_images": [], "tilesets": [], "vanishing_points": [],
        "export_directory_path": "", "export_file_name": "",
        "export_file_format": 0, "fps": 6.0, "license": "",
        "user_data": "", "author_display_name": "",
        "author_real_name": "", "author_contact": "",
        "author_company": "", "metadata": {},
    }
    zf.writestr("data.json", json.dumps(data))
    zf.writestr("mimetype", "application/x-pixelorama")
    # preview thumbnail (blended visible layers)
    prev = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for L, blob in zip(layers, blobs):
        if not L.get("visible", True):
            continue
        im = Image.frombytes("RGBA", (w, h), blob)
        if L.get("opacity", 1.0) < 1.0:
            a = np.asarray(im, dtype=np.uint8).copy()
            a[..., 3] = (a[..., 3] * float(L["opacity"])).astype(np.uint8)
            im = Image.fromarray(a, "RGBA")
        prev.alpha_composite(im)
    prev.resize((256, int(256 * h / w)), Image.NEAREST)
    buf = io.BytesIO()
    prev.save(buf, "PNG")
    zf.writestr("preview.png", buf.getvalue())
    zf.close()
    print("wrote", out, f"({len(layers)} layers, {w}x{h})")


if __name__ == "__main__":
    out, w, h, spec = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), \
        json.load(open(sys.argv[4]))
    build(out, w, h, spec["layers"])
