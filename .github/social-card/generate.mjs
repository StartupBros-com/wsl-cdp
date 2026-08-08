import satori from "satori";
import { Resvg } from "@resvg/resvg-js";
import { readFileSync, writeFileSync } from "node:fs";

const F = "/usr/share/fonts/truetype/dejavu/";
const fonts = [
  { name: "Sans", data: readFileSync(F + "DejaVuSans.ttf"), weight: 400, style: "normal" },
  { name: "Sans", data: readFileSync(F + "DejaVuSans-Bold.ttf"), weight: 700, style: "normal" },
  { name: "Mono", data: readFileSync(F + "DejaVuSansMono.ttf"), weight: 400, style: "normal" },
  { name: "Mono", data: readFileSync(F + "DejaVuSansMono-Bold.ttf"), weight: 700, style: "normal" },
];

const d = (style, ...children) => ({ type: "div", props: { style: { display: "flex", ...style }, children } });
const t = (style, text) => ({ type: "div", props: { style: { display: "flex", ...style }, children: text } });

const VIOLET = "#8b5cf6";
const GREEN = "#39ff14";
const INK = "#0a0a12";

// terminal panel (WSL side)
const term = d(
  { flexDirection: "column", width: 400, borderRadius: 14, background: "#12121c", border: "1px solid #2a2a3a", boxShadow: "0 18px 60px rgba(139,92,246,0.25)" },
  d({ alignItems: "center", gap: 8, padding: "12px 16px", borderBottom: "1px solid #22222f" },
    d({ width: 12, height: 12, borderRadius: 6, background: "#ff5f57" }),
    d({ width: 12, height: 12, borderRadius: 6, background: "#febc2e" }),
    d({ width: 12, height: 12, borderRadius: 6, background: "#28c840" }),
    t({ marginLeft: 10, fontFamily: "Mono", fontSize: 15, color: "#6b6b80" }, "will@wsl2 — ubuntu"),
  ),
  d({ flexDirection: "column", padding: "16px 20px", gap: 8 },
    d({ gap: 0 },
      t({ fontFamily: "Mono", fontSize: 19, color: VIOLET, fontWeight: 700, marginRight: 11 }, "$"),
      t({ fontFamily: "Mono", fontSize: 19, color: "#e8e8f0" }, "wsl-cdp up"),
    ),
    t({ fontFamily: "Mono", fontSize: 17, color: GREEN }, "bridge up: Chrome/151"),
    d({ gap: 0 },
      t({ fontFamily: "Mono", fontSize: 19, color: VIOLET, fontWeight: 700, marginRight: 11 }, "$"),
      t({ fontFamily: "Mono", fontSize: 19, color: "#e8e8f0" }, "wsl-cdp screenshot"),
    ),
    t({ fontFamily: "Mono", fontSize: 17, color: "#9d9db2" }, "1.2 MB — what the agent sees"),
  ),
);

// browser panel (Windows side)
const browser = d(
  { flexDirection: "column", width: 400, borderRadius: 14, background: "#15151f", border: "1px solid #2a2a3a", boxShadow: "0 18px 60px rgba(57,255,20,0.12)" },
  d({ alignItems: "center", gap: 10, padding: "12px 16px", borderBottom: "1px solid #22222f" },
    d({ width: 12, height: 12, borderRadius: 6, background: "#3a3a4c" }),
    d({ width: 12, height: 12, borderRadius: 6, background: "#3a3a4c" }),
    d({ flexGrow: 1, alignItems: "center", borderRadius: 8, background: "#0e0e16", padding: "6px 14px" },
      t({ fontFamily: "Mono", fontSize: 15, color: "#8f8fa6" }, "github.com/notifications"),
    ),
  ),
  d({ flexDirection: "column", padding: "18px 20px", gap: 10 },
    d({ gap: 10 },
      d({ width: 44, height: 44, borderRadius: 22, background: "#262637" }),
      d({ flexDirection: "column", gap: 8, paddingTop: 4 },
        d({ width: 210, height: 12, borderRadius: 6, background: "#30304a" }),
        d({ width: 150, height: 12, borderRadius: 6, background: "#232338" }),
      ),
    ),
    d({ width: 330, height: 12, borderRadius: 6, background: "#232338" }),
    d({ width: 280, height: 12, borderRadius: 6, background: "#1d1d30" }),
    d({ alignItems: "center", gap: 8, marginTop: 4 },
      d({ width: 10, height: 10, borderRadius: 5, background: GREEN }),
      t({ fontFamily: "Sans", fontSize: 15, color: "#7ee787", fontWeight: 700 }, "logged in — session persists"),
    ),
  ),
);

// bridge connector
const bridge = d(
  { flexDirection: "column", alignItems: "center", gap: 8, width: 150 },
  t({ fontFamily: "Mono", fontSize: 16, color: "#b9a5f5", fontWeight: 700 }, "CDP"),
  d({ alignItems: "center", width: 150 },
    d({ width: 14, height: 14, borderRadius: 7, background: VIOLET, boxShadow: "0 0 18px rgba(139,92,246,0.9)" }),
    d({ width: 122, height: 6, background: `linear-gradient(90deg, ${VIOLET} 0%, ${GREEN} 100%)`, boxShadow: "0 0 24px rgba(139,92,246,0.7)" }),
    d({ width: 14, height: 14, borderRadius: 7, background: GREEN, boxShadow: "0 0 18px rgba(57,255,20,0.8)" }),
  ),
  t({ fontFamily: "Mono", fontSize: 14, color: "#5c5c72" }, "9223 → 9224"),
);

const root = d(
  {
    width: 1280, height: 640, flexDirection: "column", alignItems: "center",
    background: `linear-gradient(145deg, ${INK} 0%, #0f1220 55%, ${INK} 100%)`,
    fontFamily: "Sans", position: "relative",
  },
  // orbs
  d({ position: "absolute", left: -140, top: -140, width: 520, height: 520, borderRadius: 260, background: "radial-gradient(circle, rgba(139,92,246,0.28) 0%, rgba(139,92,246,0) 70%)" }),
  d({ position: "absolute", right: -120, bottom: -160, width: 480, height: 480, borderRadius: 240, background: "radial-gradient(circle, rgba(57,255,20,0.10) 0%, rgba(57,255,20,0) 70%)" }),
  // title
  d({ flexDirection: "column", alignItems: "center", marginTop: 52, gap: 10 },
    t({ fontFamily: "Mono", fontWeight: 700, fontSize: 84, color: "#ffffff" }, "wsl-cdp"),
    t({ fontFamily: "Sans", fontSize: 30, color: "#b8b8cc" }, "your agents, your real Windows browser — from WSL2"),
  ),
  // diagram
  d({ alignItems: "center", gap: 24, marginTop: 44 },
    term, bridge, browser,
  ),
  // footer chips
  d({ alignItems: "center", gap: 14, marginTop: 46 },
    t({ fontFamily: "Mono", fontSize: 17, color: "#8f8fa6", padding: "8px 18px", borderRadius: 20, border: "1px solid #2a2a3a", background: "#12121c" }, "MIT"),
    t({ fontFamily: "Mono", fontSize: 17, color: "#8f8fa6", padding: "8px 18px", borderRadius: 20, border: "1px solid #2a2a3a", background: "#12121c" }, "Chrome · Edge · Brave"),
    t({ fontFamily: "Mono", fontSize: 17, color: "#c4b5fd", padding: "8px 18px", borderRadius: 20, border: "1px solid #4c3a80", background: "#191430" }, "sessions, never passwords"),
  ),
  t({ fontFamily: "Mono", fontSize: 18, color: "#5c5c72", marginTop: 30 }, "github.com/StartupBros-com/wsl-cdp"),
);

const svg = await satori(root, { width: 1280, height: 640, fonts });
const png = new Resvg(svg, { fitTo: { mode: "width", value: 1280 } }).render().asPng();
writeFileSync("/home/will/.claude/jobs/94eb1530/tmp/ogcard/out/wsl-cdp-social.png", png);
console.log("wrote", png.length, "bytes");
