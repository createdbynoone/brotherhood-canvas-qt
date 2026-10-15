#!/usr/bin/env python3
"""Builds a small, deterministic test vault (no private data): python3 tools/make_fixture.py <folder>
Node ids start with readable prefixes (txtA, txtB, note1, ttl01, img01...) so drive scripts can address them."""
import json, os, struct, sys, zlib

def png(path, w, h, seed):
    rows = b""
    for y in range(h):
        rows += b"\x00" + b"".join(bytes([(x * 255 // w + seed * 40) % 256, (y * 255 // h) % 256, (120 + seed * 30) % 256]) for x in range(w))
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))

root = sys.argv[1]
os.makedirs(root + "/boards", exist_ok=True)
os.makedirs(root + "/attachments", exist_ok=True)
json.dump({"version": "1.0", "name": "Fixture", "createdAt": "2026-01-01T00:00:00.000Z"}, open(root + "/vault.json", "w"))
nodes = []
def node(i, t, x, y, w, h, data):
    nodes.append({"id": i, "type": t, "position": {"x": x, "y": y}, "width": w, "height": h, "data": data})
node("ttl01-0000", "title", 0, -140, 500, 80, {"content": "FIXTURE BOARD", "fontSize": 40})
node("txtA-0000", "text", 0, 0, 260, 180, {"content": "# Card A\n\nFirst **text** card\n- one\n- two"})
node("txtB-0000", "text", 420, 0, 260, 180, {"content": "# Card B\n\nSecond card", "nodeStyle": {"backgroundColor": "#1D1530", "borderColor": "#4B8EFF", "borderWidth": 2}})
node("note1-0000", "note", 840, 0, 220, 180, {"content": "# Note\n\nA note", "noteColor": "#F54F1B"})
for n in range(3):
    f = "00000000000000%02d.png" % n
    png(root + "/attachments/" + f, 320, 220 + n * 60, n)
    node("img%02d-0000" % n, "image", n * 380, 300, 320, 220 + n * 60, {"filePath": "attachments/" + f, "fileName": f, "mimeType": "image/png", "fileSize": 1000, "content": ""})
edges = [
    {"id": "e1", "source": "txtA-0000", "target": "txtB-0000", "sourceHandle": "right", "targetHandle": "left"},
    {"id": "e2", "source": "txtB-0000", "target": "note1-0000", "sourceHandle": "right", "targetHandle": "left"},
]
board = {"id": "fixture-board-0001", "name": "Fixture", "createdAt": "2026-01-01T00:00:00.000Z", "updatedAt": "2026-01-01T00:00:00.000Z",
         "nodeCount": len(nodes), "nodes": nodes, "edges": edges, "viewport": {"x": 200, "y": 200, "zoom": 0.8}, "background": "dots"}
json.dump(board, open(root + "/boards/fixture-board-0001.json", "w"), indent=2)
json.dump({"boards": [{k: board[k] for k in ("id", "name", "createdAt", "updatedAt", "nodeCount")}]}, open(root + "/boards/index.json", "w"), indent=2)
print("fixture vault in", root)
