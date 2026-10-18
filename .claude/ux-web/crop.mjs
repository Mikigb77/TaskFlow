// Cut screenfuls out of a UX web render, so part of a tall full-page PNG can be read at
// full size (image viewers shrink a whole page until its text is unreadable).
//
// Run it in WSL: sharp comes from the website's node_modules, which hold Linux binaries.
//   wsl -e bash -lc 'source ~/.nvm/nvm.sh && node /mnt/c/Users/mikig/Desktop/Custom/MikiHacks/TaskFlow/TaskFlow/.claude/ux-web/crop.mjs <render> <screen> [screens] [zoom]'
//     <render>   a full-page render or a demo card in TaskFlowWeb/artifacts/ux-web, by file
//                name or path, e.g. privacy.es.mobile.light.full.png or
//                voice-result-six.en.mobile.light.panel.png
//     <screen>   the screenful to start at; 1 is the first viewport
//     [screens]  how many screenfuls to include; default 1
//     [zoom]     enlargement; default 1 for desktop renders at 100%, 2 for the rest
//
// Writes TaskFlowWeb/artifacts/ux-web/crops/<render>.s<screen>[-<last>].png (ignored by git,
// cleared with the renders) and prints its Windows path.
import { createRequire } from "node:module";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const web = path.resolve(
  process.env.TASKFLOW_WEB || path.join(here, "..", "..", "..", "TaskFlowWeb"),
);
const renders = path.join(web, "artifacts", "ux-web");
// Screenful heights in CSS px, by the render's viewport (its third name part); keep them in
// step with the projects in playwright.config.ts and VARIANTS in tests/ux-renders.spec.ts.
const SCREEN = {
  desktop: 1000,
  mobile: 664,
  "desktop-text200": 1000,
  "mobile-text200": 664,
  "desktop-zoom200": 500,
  "mobile-w320": 568,
};

const [name, screenArg, countArg, zoomArg] = process.argv.slice(2);
if (!name || !screenArg) {
  console.error("usage: crop.mjs <render.png> <screen> [screens] [zoom]");
  process.exit(2);
}
const file = path.isAbsolute(name) ? name : path.join(renders, path.basename(name));
const base = path.basename(file, ".png");
if (!base.endsWith(".full") && !base.endsWith(".panel")) {
  console.error(
    `${base}.png isn't a full-page render or a demo card; fold and view renders are already one screen.`,
  );
  process.exit(2);
}
const viewport = base.split(".")[2];
const step = SCREEN[viewport];
if (!step) {
  console.error(`${base}.png: unknown viewport "${viewport}"; add it to SCREEN in crop.mjs.`);
  process.exit(2);
}
const screen = Number(screenArg);
const count = Number(countArg || 1);
const zoom = Number(zoomArg || (viewport === "desktop" || viewport === "desktop-text200" ? 1 : 2));

const sharp = createRequire(path.join(web, "package.json"))("sharp");
const { width, height } = await sharp(file).metadata();
const screens = Math.ceil(height / step);
if (!Number.isInteger(screen) || screen < 1 || screen > screens || !(count >= 1) || !(zoom > 0)) {
  console.error(`${base}.png has ${screens} screen(s) of ${step}px; ask for 1 to ${screens}.`);
  process.exit(2);
}
const top = (screen - 1) * step;
const last = Math.min(screen + count - 1, screens);
const out = path.join(
  renders,
  "crops",
  `${base}.s${screen}${last > screen ? `-${last}` : ""}.png`,
);
mkdirSync(path.dirname(out), { recursive: true });
await sharp(file)
  .extract({ left: 0, top, width, height: Math.min(last * step, height) - top })
  .resize({ width: Math.round(width * zoom), kernel: "lanczos3" })
  .toFile(out);

const drive = /^\/mnt\/([a-z])\/(.*)$/.exec(out);
console.log(
  `screen ${screen}${last > screen ? `-${last}` : ""} of ${screens}: ` +
    (drive ? `${drive[1].toUpperCase()}:\\${drive[2].replaceAll("/", "\\")}` : out),
);
