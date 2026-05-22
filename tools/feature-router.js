const fs = require("fs");
const path = require("path");

// ─── CONFIG ──────────────────────────────────────────────────────────────────

const CONFIG = {
  projectFileName: "default.project.json",
  sourceDirectory: "src",
  projectName: "fishing-minigame",
};

/**
 * When a folder named one of these keys is found anywhere under src/,
 * it gets routed to the corresponding Roblox service.
 */
const SEGMENT_ROUTES = {
  client: "ReplicatedStorage",
  shared: "ReplicatedStorage",
  server: "ServerScriptService",
};

/**
 * Static nodes always present in the output tree regardless of src/ contents.
 * Add packages, models, assets etc. here.
 */
const STATIC_NODES = {
  ReplicatedStorage: {
    Packages: { $path: "Packages" },
  },
  ServerScriptService: {},
};

// ─── HELPERS ─────────────────────────────────────────────────────────────────

const toPosix = (p) => p.split(path.sep).join("/");

/** Get or create a nested node, optionally stamping $className on creation. */
function getOrCreate(parent, key, className) {
  if (!parent[key]) {
    parent[key] = className ? { $className: className } : {};
  }
  return parent[key];
}

/**
 * Recursively walk dir looking for folders named client/shared/server.
 * Stops descending into a segment folder once found (Rojo owns its subtree).
 * Calls onSegment(segmentName, absolutePath) for each match.
 */
function findSegments(dir, onSegment) {
  if (!fs.existsSync(dir)) return;

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;

    const fullPath = path.join(dir, entry.name);
    const name = entry.name.toLowerCase();

    if (SEGMENT_ROUTES[name]) {
      // Found a segment folder — hand it off, don't descend into it
      onSegment(name, fullPath);
    } else {
      // Not a segment — keep looking deeper
      findSegments(fullPath, onSegment);
    }
  }
}

/** Remove $path entries whose paths don't exist on disk. */
function pruneTree(node) {
  for (const key of Object.keys(node)) {
    const val = node[key];
    if (typeof val !== "object" || val === null) continue;
    if (val.$path && !fs.existsSync(path.resolve(process.cwd(), val.$path))) {
      delete node[key];
    } else {
      pruneTree(val);
    }
  }
  return node;
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

async function main() {
  const srcRoot = path.resolve(process.cwd(), CONFIG.sourceDirectory);
  if (!fs.existsSync(srcRoot)) {
    throw new Error(`Source directory not found: ${srcRoot}`);
  }

  // Build initial tree from static nodes
  const tree = {
    name: CONFIG.projectName,
    emitLegacyScripts: false,
    tree: {
      $className: "DataModel",
    },
  };

  for (const [service, nodes] of Object.entries(STATIC_NODES)) {
    tree.tree[service] = structuredClone(nodes);
  }

  const mapped = [];

  findSegments(srcRoot, (segmentName, absolutePath) => {
    const service = SEGMENT_ROUTES[segmentName];

    // Path relative to project root, e.g. "src/features/inventory/client"
    const rojoPath = toPosix(path.relative(process.cwd(), absolutePath));

    // Parts between src/ and the segment folder, e.g. ["features", "inventory"]
    const relativeToSrc = path.relative(srcRoot, absolutePath);
    const parts = relativeToSrc.split(path.sep); // [...virtualFolders, segmentName]

    // Navigate/build the tree: service → "src" (Folder) → ...virtualFolders → segmentName
    let current = getOrCreate(tree.tree, service);
    current = getOrCreate(current, "src", "Folder");

    // All parts except the last (segmentName) are intermediate feature folders
    const virtualFolders = parts.slice(0, -1);
    for (const folder of virtualFolders) {
      current = getOrCreate(current, folder, "Folder");
    }

    // Final node is the segment itself — mapped directly to its path
    current[segmentName] = { $path: rojoPath };

    mapped.push(
      `  ${service}.src.${[...virtualFolders, segmentName].join(
        "."
      )}  →  ${rojoPath}`
    );
  });

  pruneTree(tree);

  const output = JSON.stringify(tree, null, 2);

  if (fs.existsSync(CONFIG.projectFileName)) {
    const existing = fs.readFileSync(CONFIG.projectFileName, "utf-8");
    if (existing === output) {
      console.log("No changes — project file is already up to date.");
      return;
    }
  }

  fs.writeFileSync(CONFIG.projectFileName, output);

  console.log(`\nSuccess! Generated "${CONFIG.projectFileName}"`);
  if (mapped.length > 0) {
    console.log(`\nMapped segments:`);
    for (const line of mapped) console.log(line);
  } else {
    console.log(
      `\nNo client/shared/server folders found under ${CONFIG.sourceDirectory}/`
    );
  }
  console.log();
}

main().catch((err) => {
  console.error(`\nFailed: ${err.message}\n`);
  process.exit(1);
});
