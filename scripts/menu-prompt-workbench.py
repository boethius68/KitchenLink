#!/usr/bin/env python3
"""
Menu Prompt Workbench – lokaler Test-Server für Gemma-4-Menü-Extraktion.

Start:  python3 scripts/menu-prompt-workbench.py
Dann:   http://localhost:8080

Workflow:
1. Menü-Seite auswählen (linke Spalte)
2. System-Prompt bearbeiten (mittlere Spalte)
3. „Run“ klicken → ruft Ollama/Gemma 4 auf
4. Ergebnis als JSON + gerendertes Menü sehen
5. Kurzes Feedback eingeben → wird geloggt
6. Ich passe Prompt an → Repeat
"""

import http.server
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

PORT = 8080
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "gemma4:latest"  # 8B mit Vision; 12B-Vision-Support folgt

# ---- Pfade ----
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
DEMO_MENUS_DIR = PROJECT_DIR / "kitchenlink" / "Resources" / "DemoMenus"
LOGS_DIR = PROJECT_DIR / "scripts" / "workbench_logs"

os.makedirs(LOGS_DIR, exist_ok=True)

# ---- Menü-Metadaten ----
MENUS = [
    {"id": "scheune-berlin",   "name": "Scheune Berlin",   "pages": 3},
    {"id": "lichtburg-berlin", "name": "Lichtburg Berlin", "pages": 7},
    {"id": "alexxanders-chemnitz", "name": "Alexxanders Chemnitz", "pages": 4},
    {"id": "kitchenlink-pruefkueche", "name": "KitchenLink Prüfküche", "pages": 3},
]

# ---- Default System-Prompt (DE) ----
DEFAULT_SYSTEM_PROMPT = """Du extrahierst die Struktur einer deutschen Speisekarte aus einem Foto. Gib NUR valides JSON zurück im folgenden Schema:

{
  "sections": [
    {
      "name": "Kategoriename",
      "items": [
        {
          "name": "Gerichtname",
          "description": "Kurzbeschreibung (optional)",
          "price_cents": 1234,
          "allergen_codes": ["A", "B", "C"],
          "options": [
            {"name": "Portionsgröße / Variante", "price_cents": 0}
          ]
        }
      ]
    }
  ]
}

REGELN:
- price_cents immer in Cent (12,34€ → 1234)
- allergen_codes als Array von Großbuchstaben (A, B, C, D, E, F, G, H, L, M, N, P, R)
- options nur wenn es mehrere Varianten gibt (z.B. "klein/8,50€", "groß/14€")
- Deutsche Anführungszeichen („...") escaped korrekt im JSON
- Ignoriere Fußnoten, AGB, Öffnungszeiten, Impressum
- Extrahiere NUR Speisen und Getränke mit Preis
- Gib ein leeres sections-Array wenn nichts gefunden wurde"""

FEEDBACK_TEMPLATE = """## Feedback-Runde

### Was war gut?
- 

### Was war falsch?
- 

### Welche konkreten Fehler (Items/Prices/Codes)?
- 

### Prompt-Idee zur Verbesserung:
- 
"""


# =============================================================
#  SERVER
# =============================================================

class MenuWorkbenchHandler(http.server.BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        pass  # less noise

    def _send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html, status=200):
        body = html.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_file(self, path, mime):
        try:
            with open(path, "rb") as f:
                data = f.read()
            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.wfile.write(data)
        except FileNotFoundError:
            self._send_json({"error": "not found"}, 404)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(length).decode("utf-8") if length else ""

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/":
            self._send_html(HTML_PAGE)
        elif path.startswith("/menu-image/"):
            menu_id = path[len("/menu-image/"):]
            fpath = DEMO_MENUS_DIR / menu_id
            self._serve_file(str(fpath), "image/png")
        elif path == "/api/menus":
            self._send_json(MENUS)
        elif path == "/api/default-prompt":
            self._send_json({"prompt": DEFAULT_SYSTEM_PROMPT})
        elif path.startswith("/api/logs/"):
            log_name = path[len("/api/logs/"):]
            fpath = LOGS_DIR / log_name
            if fpath.exists():
                with open(fpath) as f:
                    self._send_json({"content": f.read()})
            else:
                self._send_json({"content": ""})
        else:
            self._send_json({"error": "not found"}, 404)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/run":
            self._handle_run()
        elif path == "/api/feedback":
            self._handle_feedback()
        else:
            self._send_json({"error": "not found"}, 404)

    def _handle_run(self):
        body = json.loads(self._read_body())
        image_path = body.get("image", "")
        system_prompt = body.get("system_prompt", DEFAULT_SYSTEM_PROMPT)
        user_prompt = body.get("user_prompt", "Extrahiere alle Speisen und Getränke aus dieser Speisekarte als JSON.")

        fpath = DEMO_MENUS_DIR / image_path
        if not fpath.exists():
            self._send_json({"error": f"Image not found: {image_path}"}, 404)
            return

        # Encode image as base64
        import base64
        with open(fpath, "rb") as f:
            img_b64 = base64.b64encode(f.read()).decode("ascii")

        ollama_payload = {
            "model": MODEL,
            "prompt": f"{system_prompt}\n\n{user_prompt}",
            "images": [img_b64],
            "stream": False,
            "options": {
                "temperature": 0.1,
                "num_predict": 4096,
            }
        }

        req = urllib.request.Request(
            OLLAMA_URL,
            data=json.dumps(ollama_payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        try:
            t0 = time.time()
            with urllib.request.urlopen(req, timeout=300) as resp:
                result = json.loads(resp.read().decode("utf-8"))
            elapsed = time.time() - t0

            raw_text = result.get("response", "")

            # Try to extract JSON from response
            parsed_json = None
            json_error = None
            try:
                # Find JSON block in response
                text = raw_text.strip()
                if text.startswith("```"):
                    lines = text.split("\n")
                    text = "\n".join(l for l in lines if not l.startswith("```"))
                # Find first { and last }
                start = text.find("{")
                end = text.rfind("}")
                if start >= 0 and end > start:
                    text = text[start:end+1]
                parsed_json = json.loads(text)
            except Exception as e:
                json_error = str(e)

            self._send_json({
                "raw": raw_text,
                "parsed": parsed_json,
                "json_error": json_error,
                "elapsed_s": round(elapsed, 1),
                "model": MODEL,
                "image": image_path,
            })

        except urllib.error.HTTPError as e:
            self._send_json({
                "error": f"Ollama HTTP {e.code}: {e.read().decode()[:500]}",
                "image": image_path,
            }, 502)
        except Exception as e:
            self._send_json({
                "error": str(e),
                "image": image_path,
            }, 502)

    def _handle_feedback(self):
        body = json.loads(self._read_body())
        feedback = body.get("feedback", "")
        prompt = body.get("prompt", "")
        result = body.get("result", "")
        image = body.get("image", "")

        timestamp = time.strftime("%Y%m%d_%H%M%S")
        fpath = LOGS_DIR / f"feedback_{timestamp}.md"
        content = f"## Feedback {timestamp}\n\n"
        content += f"**Model:** {MODEL}\n"
        content += f"**Image:** {image}\n\n"
        content += "### Prompt\n```\n{prompt}\n```\n\n"
        content += "### Result\n```json\n{result}\n```\n\n"
        content += "### User Feedback\n{feedback}\n"
        content += "\n---\n"

        with open(fpath, "w") as f:
            f.write(content)

        self._send_json({"ok": True, "file": str(fpath)})


# =============================================================
#  HTML PAGE
# =============================================================

HTML_PAGE = r"""<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Menu Prompt Workbench</title>
<style>
  :root {
    --bg: #0d1117;
    --surface: #161b22;
    --border: #30363d;
    --text: #c9d1d9;
    --text-dim: #8b949e;
    --accent: #58a6ff;
    --green: #3fb950;
    --red: #f85149;
    --orange: #d29922;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
         background: var(--bg); color: var(--text); padding: 16px; font-size: 14px; }
  .layout { display: grid; grid-template-columns: 320px 1fr 1fr; gap: 16px; height: calc(100vh - 100px); }
  .panel { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 12px; overflow-y: auto; }
  .panel h3 { font-size: 13px; text-transform: uppercase; color: var(--text-dim); margin-bottom: 10px; letter-spacing: 0.5px; }
  h1 { font-size: 20px; margin-bottom: 8px; }
  .subtitle { color: var(--text-dim); font-size: 13px; margin-bottom: 16px; }
  button { background: var(--accent); color: #fff; border: none; padding: 8px 16px; border-radius: 6px;
           cursor: pointer; font-size: 13px; font-weight: 600; }
  button:disabled { opacity: 0.5; cursor: wait; }
  button:hover:not(:disabled) { filter: brightness(1.2); }
  textarea { width: 100%; background: #0d1117; color: var(--text); border: 1px solid var(--border);
             border-radius: 6px; padding: 10px; font-family: 'SF Mono', 'Menlo', monospace; font-size: 12px; resize: vertical; }
  textarea:focus { outline: none; border-color: var(--accent); }
  select { width: 100%; background: #0d1117; color: var(--text); border: 1px solid var(--border);
           border-radius: 6px; padding: 8px; font-size: 13px; margin-bottom: 8px; }
  select:focus { outline: none; border-color: var(--accent); }
  .menu-item { cursor: pointer; padding: 8px; border-radius: 6px; margin-bottom: 4px; }
  .menu-item:hover { background: #1c2128; }
  .menu-item.active { background: #1c2128; border-left: 3px solid var(--accent); }
  .menu-item .name { font-weight: 600; }
  .menu-item .badge { display: inline-block; background: #21262d; color: var(--text-dim); font-size: 11px;
                       border-radius: 10px; padding: 1px 6px; }
  .menu-image { width: 100%; border-radius: 6px; border: 1px solid var(--border); }
  .result-area { white-space: pre-wrap; font-family: 'SF Mono', 'Menlo', monospace; font-size: 12px;
                 line-height: 1.5; background: #0d1117; border-radius: 6px; padding: 12px; margin-top: 8px;
                 max-height: 60vh; overflow-y: auto; }
  .error { color: var(--red); }
  .success { color: var(--green); }
  .meta { color: var(--text-dim); font-size: 12px; margin: 8px 0; }
  .rendered-item { padding: 6px 0; border-bottom: 1px solid var(--border); }
  .rendered-item:last-child { border-bottom: none; }
  .rendered-item .item-name { font-weight: 600; }
  .rendered-item .item-price { color: var(--green); float: right; }
  .rendered-item .item-desc { color: var(--text-dim); font-size: 12px; }
  .rendered-item .item-codes { font-size: 11px; color: var(--orange); }
  .section-header { font-size: 15px; font-weight: 700; color: var(--accent); margin: 12px 0 6px; padding-bottom: 4px; border-bottom: 1px solid var(--border); }
  .toolbar { display: flex; gap: 8px; align-items: center; margin: 8px 0; flex-wrap: wrap; }
  .feedback-area { margin-top: 12px; }
  .tabs { display: flex; gap: 4px; margin-bottom: 8px; }
  .tab { padding: 6px 12px; border-radius: 6px; cursor: pointer; font-size: 12px; background: transparent; color: var(--text-dim); border: 1px solid transparent; }
  .tab.active { background: #1c2128; border-color: var(--border); color: var(--text); }
  .spinner { display: inline-block; width: 16px; height: 16px; border: 2px solid var(--border);
             border-top-color: var(--accent); border-radius: 50%; animation: spin 0.8s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  #feedbackSaved { color: var(--green); font-size: 12px; display: none; }
  .badge-model { font-size: 11px; background: #21262d; padding: 2px 6px; border-radius: 4px; color: var(--text-dim); }
</style>
</head>
<body>

<h1>Menu Prompt Workbench</h1>
<div class="subtitle">
  Modell: <span class="badge-model">{{MODEL}}</span>
  &middot; Ollama <code>localhost:11434</code>
  &middot; <span id="elapsed"></span>
</div>

<div class="layout">
  <!-- LEFT: Image Browser -->
  <div class="panel">
    <h3>Menu-Seite wahlen</h3>
    <div id="menuList"></div>
    <div style="margin-top:12px">
      <img id="previewImage" class="menu-image" src="" alt="Vorschau">
    </div>
  </div>

  <!-- CENTER: Prompt Editor -->
  <div class="panel">
    <h3>System Prompt</h3>
    <textarea id="systemPrompt" rows="18"></textarea>
    <div class="toolbar">
      <button id="runBtn" onclick="runInference()">Run on {{MODEL}}</button>
      <span id="runSpinner" class="spinner" style="display:none"></span>
    </div>
    <div style="margin-top:8px">
      <h3>User Prompt (optional)</h3>
      <textarea id="userPrompt" rows="2" placeholder="Extrahiere alle Speisen und Getranke aus dieser Speisekarte als JSON."></textarea>
    </div>
    <div class="feedback-area">
      <h3>Dein Feedback</h3>
      <textarea id="feedbackText" rows="4" placeholder="Was ist falsch? Welche Items/Prices/Codes stimmen nicht?"></textarea>
      <div class="toolbar">
        <button onclick="submitFeedback()">Feedback senden</button>
        <span id="feedbackSaved">Gespeichert</span>
      </div>
    </div>
  </div>

  <!-- RIGHT: Result -->
  <div class="panel">
    <div class="tabs">
      <div class="tab active" data-tab="rendered" onclick="switchTab('rendered')">Vorschau</div>
      <div class="tab" data-tab="json" onclick="switchTab('json')">JSON</div>
      <div class="tab" data-tab="raw" onclick="switchTab('raw')">Raw</div>
    </div>
    <div id="resultRendered"><div style="color:var(--text-dim);padding:20px;text-align:center">Noch nichts geladen.<br>&rarr; Menu-Seite wahlen und &quot;Run&quot; klicken</div></div>
    <div id="resultJson" class="result-area" style="display:none"></div>
    <div id="resultRaw" class="result-area" style="display:none"></div>
  </div>
</div>

<script>
// ---- State ----
let currentMenu = null;
let currentPage = 0;
let lastResult = null;
let lastPrompt = "";
var menus = {{MENUS_JSON}};
var defaultPrompt = {{DEFAULT_PROMPT_JSON}};

// ---- Init ----
renderMenuList();
document.getElementById("systemPrompt").value = defaultPrompt;

function renderMenuList() {
  const container = document.getElementById("menuList");
  container.innerHTML = "";
  menus.forEach(function(menu) {
    for (var p = 0; p < menu.pages; p++) {
      var pageNum = p + 1;
      var div = document.createElement("div");
      div.className = "menu-item";
      div.dataset.menuId = menu.id;
      div.dataset.page = p;
      div.innerHTML = '<span class="name">' + menu.name + '</span> <span class="badge">S. ' + pageNum + '/' + menu.pages + '</span>';
      div.onclick = (function(mid, pg) {
        return function() { selectMenu(mid, pg, this); };
      })(menu.id, p);
      container.appendChild(div);
    }
  });
  var first = container.querySelector(".menu-item");
  if (first) first.click();
}

function selectMenu(menuId, page, el) {
  document.querySelectorAll(".menu-item").forEach(function(e) { e.classList.remove("active"); });
  if (el) el.classList.add("active");
  currentMenu = menuId;
  currentPage = page;
  document.getElementById("previewImage").src = "/menu-image/" + menuId + "-" + (page + 1) + ".png";
}

function switchTab(tab) {
  document.querySelectorAll(".tab").forEach(function(t) { t.classList.remove("active"); });
  document.querySelector(".tab[data-tab=" + tab + "]").classList.add("active");
  var tabs = ["rendered", "json", "raw"];
  for (var i = 0; i < tabs.length; i++) {
    var t = tabs[i];
    var el = document.getElementById("result" + t.charAt(0).toUpperCase() + t.slice(1));
    el.style.display = (t === tab) ? "block" : "none";
  }
}

async function runInference() {
  var filename = currentMenu + "-" + (currentPage + 1) + ".png";
  var systemPrompt = document.getElementById("systemPrompt").value;
  var userPrompt = document.getElementById("userPrompt").value;

  document.getElementById("runBtn").disabled = true;
  document.getElementById("runSpinner").style.display = "inline-block";
  document.getElementById("elapsed").textContent = "";
  document.getElementById("resultRendered").innerHTML = '<div style="padding:20px;text-align:center"><div class="spinner" style="margin:0 auto"></div><br><span style="color:var(--text-dim)">Gemma 4 denkt nach...</span></div>';
  document.getElementById("resultJson").textContent = "";
  document.getElementById("resultRaw").textContent = "";
  switchTab("rendered");

  lastPrompt = systemPrompt;

  try {
    var resp = await fetch("/api/run", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({image: filename, system_prompt: systemPrompt, user_prompt: userPrompt})
    });
    var data = await resp.json();
    lastResult = data;

    if (data.error) {
      document.getElementById("resultRendered").innerHTML = '<div class="error">Fehler: ' + data.error + '</div>';
      document.getElementById("elapsed").textContent = "Fehler";
      return;
    }

    document.getElementById("elapsed").textContent = data.elapsed_s + 's . ' + data.model;
    document.getElementById("resultRaw").textContent = data.raw;
    document.getElementById("resultJson").textContent = JSON.stringify(data.parsed || data.json_error, null, 2);

    if (data.parsed) {
      renderMenuPreview(data.parsed);
    } else if (data.json_error) {
      document.getElementById("resultRendered").innerHTML = '<div class="error">JSON-Fehler: ' + data.json_error + '</div><pre style="margin-top:8px;font-size:11px">' + data.raw.slice(0, 2000) + '</pre>';
    }

  } catch (e) {
    document.getElementById("resultRendered").innerHTML = '<div class="error">Fehler: ' + e.message + '</div>';
  } finally {
    document.getElementById("runBtn").disabled = false;
    document.getElementById("runSpinner").style.display = "none";
  }
}

function renderMenuPreview(data) {
  if (!data || !data.sections || data.sections.length === 0) {
    document.getElementById("resultRendered").innerHTML = '<div style="color:var(--orange)">Keine Sektionen gefunden (leeres Menu)</div>';
    return;
  }
  var html = "";
  var totalItems = 0;
  for (var si = 0; si < data.sections.length; si++) {
    var section = data.sections[si];
    totalItems += (section.items || []).length;
    html += '<div class="section-header">' + (section.name || 'Unbenannt') + '</div>';
    for (var ii = 0; ii < (section.items || []).length; ii++) {
      var item = section.items[ii];
      var price = (item.price_cents != null) ? 'EUR ' + (item.price_cents / 100).toFixed(2) : '--';
      var codes = (item.allergen_codes || []).join(", ");
      var options = "";
      for (var oi = 0; oi < (item.options || []).length; oi++) {
        var o = item.options[oi];
        var op = (o.price_cents != null) ? 'EUR ' + (o.price_cents / 100).toFixed(2) : "";
        options += '<div style="margin-left:16px;font-size:12px;color:var(--text-dim)"> ' + o.name + ': ' + op + '</div>';
      }
      html += '<div class="rendered-item">';
      html += '<div><span class="item-name">' + (item.name || '???') + '</span> <span class="item-price">' + price + '</span></div>';
      if (item.description) { html += '<div class="item-desc">' + item.description + '</div>'; }
      if (codes) { html += '<div class="item-codes">Allergene: ' + codes + '</div>'; }
      html += options;
      html += '</div>';
    }
  }
  html = '<div style="color:var(--text-dim);font-size:12px;margin-bottom:8px">' + data.sections.length + ' Sektionen . ' + totalItems + ' Items</div>' + html;
  document.getElementById("resultRendered").innerHTML = html;
}

async function submitFeedback() {
  var text = document.getElementById("feedbackText").value.trim();
  if (!text) { alert("Bitte Feedback eingeben."); return; }

  var payload = {
    feedback: text,
    prompt: lastPrompt,
    result: JSON.stringify(lastResult || {}),
    image: currentMenu + "-" + (currentPage + 1) + ".png"
  };

  try {
    var resp = await fetch("/api/feedback", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload)
    });
    var data = await resp.json();
    if (data.ok) {
      document.getElementById("feedbackSaved").style.display = "inline";
      document.getElementById("feedbackText").value = "";
      setTimeout(function() { document.getElementById("feedbackSaved").style.display = "none"; }, 3000);
    }
  } catch (e) {
    alert("Fehler: " + e.message);
  }
}
</script>
</body>
</html>"""


if __name__ == "__main__":
    # Resolve HTML placeholders before starting server
    import __main__
    __main__.HTML_PAGE = HTML_PAGE.replace("{{MODEL}}", MODEL)
    __main__.HTML_PAGE = __main__.HTML_PAGE.replace("{{MENUS_JSON}}", json.dumps(MENUS, ensure_ascii=False))
    __main__.HTML_PAGE = __main__.HTML_PAGE.replace("{{DEFAULT_PROMPT_JSON}}", json.dumps(DEFAULT_SYSTEM_PROMPT, ensure_ascii=False))

    addr = ("0.0.0.0", PORT)
    server = http.server.HTTPServer(addr, MenuWorkbenchHandler)
    print(f"\n  Menu Prompt Workbench gestartet")
    print(f"  {'─' * 40}")
    print(f"  http://localhost:{PORT}")
    print(f"  Modell: {MODEL}")
    print(f"  {len(MENUS)} Menus · {sum(m['pages'] for m in MENUS)} Seiten")
    print(f"  Feedback → scripts/workbench_logs/\n")
    server.serve_forever()
