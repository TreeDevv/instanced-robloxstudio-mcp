#!/usr/bin/env node

import { readFileSync, readdirSync, writeFileSync, existsSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join, basename } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = join(__dirname, "..");
const pluginDir = join(rootDir, "ambient-spawn-plugin");
const sourcePath = join(pluginDir, "plugin.server.lua");
const modulesDir = join(pluginDir, "src");
const outputPath = join(pluginDir, "AmbientSpawnPlugin.rbxmx");

function escapeCdata(source) {
	return source.replace(/\]\]>/g, "]]]]><![CDATA[>");
}

function isLuaFile(name) {
	return name.endsWith(".lua") || name.endsWith(".luau");
}

function findInitFile(dir) {
	for (const name of ["init.lua", "init.luau"]) {
		const fullPath = join(dir, name);
		if (existsSync(fullPath)) {
			return fullPath;
		}
	}
	return undefined;
}

const INIT_FILENAMES = new Set(["init.lua", "init.luau"]);

function dirHasLuaContent(dir) {
	const entries = readdirSync(dir, { withFileTypes: true });
	for (const entry of entries) {
		if (entry.isFile() && isLuaFile(entry.name)) {
			return true;
		}
		if (entry.isDirectory() && dirHasLuaContent(join(dir, entry.name))) {
			return true;
		}
	}
	return false;
}

let refId = 1;

function buildModuleItems(dir, depth = 0) {
	if (!existsSync(dir)) {
		return "";
	}

	let items = "";
	const entries = readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));

	for (const entry of entries) {
		const fullPath = join(dir, entry.name);

		if (entry.isDirectory()) {
			if (!dirHasLuaContent(fullPath)) {
				continue;
			}

			const initPath = findInitFile(fullPath);
			refId += 1;
			const currentRef = refId;
			const children = buildModuleItems(fullPath, depth + 1);

			if (initPath) {
				const moduleSource = readFileSync(initPath, "utf8");
				items += `
      ${"  ".repeat(depth)}<Item class="ModuleScript" referent="${currentRef}">
      ${"  ".repeat(depth)}  <Properties>
      ${"  ".repeat(depth)}    <string name="Name">${entry.name}</string>
      ${"  ".repeat(depth)}    <string name="Source"><![CDATA[${escapeCdata(moduleSource)}]]></string>
      ${"  ".repeat(depth)}  </Properties>${children}
      ${"  ".repeat(depth)}</Item>`;
			} else {
				items += `
      ${"  ".repeat(depth)}<Item class="Folder" referent="${currentRef}">
      ${"  ".repeat(depth)}  <Properties>
      ${"  ".repeat(depth)}    <string name="Name">${entry.name}</string>
      ${"  ".repeat(depth)}  </Properties>${children}
      ${"  ".repeat(depth)}</Item>`;
			}
		} else if (entry.isFile() && isLuaFile(entry.name) && !INIT_FILENAMES.has(entry.name)) {
			const extension = entry.name.endsWith(".luau") ? ".luau" : ".lua";
			const moduleName = basename(entry.name, extension);
			const moduleSource = readFileSync(fullPath, "utf8");
			refId += 1;

			items += `
      ${"  ".repeat(depth)}<Item class="ModuleScript" referent="${refId}">
      ${"  ".repeat(depth)}  <Properties>
      ${"  ".repeat(depth)}    <string name="Name">${moduleName}</string>
      ${"  ".repeat(depth)}    <string name="Source"><![CDATA[${escapeCdata(moduleSource)}]]></string>
      ${"  ".repeat(depth)}  </Properties>
      ${"  ".repeat(depth)}</Item>`;
		}
	}

	return items;
}

function countModules(dir) {
	if (!existsSync(dir)) {
		return 0;
	}

	let count = 0;
	const entries = readdirSync(dir, { withFileTypes: true });
	for (const entry of entries) {
		const fullPath = join(dir, entry.name);
		if (entry.isDirectory()) {
			count += countModules(fullPath);
			if (findInitFile(fullPath)) {
				count += 1;
			}
		} else if (entry.isFile() && isLuaFile(entry.name) && !INIT_FILENAMES.has(entry.name)) {
			count += 1;
		}
	}

	return count;
}

if (!existsSync(sourcePath)) {
	console.error(`Plugin source not found at ${sourcePath}`);
	process.exit(1);
}

const rootSource = readFileSync(sourcePath, "utf8");
const moduleItems = buildModuleItems(modulesDir);
const moduleCount = countModules(modulesDir);

const rbxmx = `<?xml version="1.0" encoding="utf-8"?>
<roblox version="4">
  <Item class="Script" referent="0">
    <Properties>
      <string name="Name">AmbientSpawnPlugin</string>
      <token name="RunContext">0</token>
      <string name="Source"><![CDATA[${escapeCdata(rootSource)}]]></string>
    </Properties>
    <Item class="Folder" referent="1">
      <Properties>
        <string name="Name">src</string>
      </Properties>${moduleItems}
    </Item>
  </Item>
</roblox>
`;

writeFileSync(outputPath, rbxmx, "utf8");
console.log(`Built ambient-spawn-plugin/AmbientSpawnPlugin.rbxmx (${moduleCount} modules)`);
