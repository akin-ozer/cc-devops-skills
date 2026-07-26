#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const skillsRoot = path.join(repoRoot, "devops-skills-plugin", "skills");
const requiredSections = [
  "Purpose",
  "Workflow",
  "Resources",
  "Safety and gotchas",
  "Validation",
  "Output",
];
const errors = [];

function fail(file, message) {
  errors.push(`${path.relative(repoRoot, file)}: ${message}`);
}

function markdownFiles(directory) {
  const result = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === ".git") continue;
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...markdownFiles(entryPath));
    else if (entry.name.endsWith(".md")) result.push(entryPath);
  }
  return result;
}

const skillDirs = fs
  .readdirSync(skillsRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => path.join(skillsRoot, entry.name))
  .filter((directory) => fs.existsSync(path.join(directory, "SKILL.md")))
  .sort();

if (skillDirs.length !== 31) {
  errors.push(`expected 31 skills, found ${skillDirs.length}`);
}

for (const skillDir of skillDirs) {
  const skillName = path.basename(skillDir);
  const skillFile = path.join(skillDir, "SKILL.md");
  const guideFile = path.join(skillDir, "references", "extended-guide.md");
  const content = fs.readFileSync(skillFile, "utf8");
  const lines = content.split(/\r?\n/);
  const frontmatter = content.match(
    /^---\r?\nname:\s*([^\r\n]+)\r?\ndescription:\s*"?([^\r\n"]+)"?\r?\n---\r?\n/,
  );

  if (!frontmatter) {
    fail(skillFile, "frontmatter must contain only name and description first");
  } else {
    if (frontmatter[1].trim() !== skillName) {
      fail(skillFile, `frontmatter name must equal directory name "${skillName}"`);
    }
    const description = frontmatter[2].trim();
    if (!description.startsWith("Use when ")) {
      fail(skillFile, 'description must be trigger-oriented and start with "Use when "');
    }
    if (description.length > 220) {
      fail(skillFile, `description is ${description.length} characters; maximum is 220`);
    }
  }

  if (lines.length > 80) {
    fail(skillFile, `entry point is ${lines.length} lines; maximum is 80`);
  }
  for (const section of requiredSections) {
    if (!content.includes(`\n## ${section}\n`)) {
      fail(skillFile, `missing "## ${section}" section`);
    }
  }
  if (!content.includes("references/extended-guide.md")) {
    fail(skillFile, "must route detailed cases to references/extended-guide.md");
  }
  if (!fs.existsSync(guideFile)) {
    fail(skillFile, "referenced extended guide does not exist");
  } else {
    const guide = fs.readFileSync(guideFile, "utf8");
    if (guide.startsWith("---\n")) {
      fail(guideFile, "supporting guides must not contain skill frontmatter");
    }
    if (!guide.includes("> Use this guide selectively.")) {
      fail(guideFile, "must explain that detailed guidance is loaded selectively");
    }
  }
  if (/\/Users\/[^/\s]+/.test(content)) {
    fail(skillFile, "contains a machine-specific absolute path");
  }
}

const markdownLink = /!?\[[^\]]*]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)/g;
for (const file of markdownFiles(repoRoot)) {
  const content = fs.readFileSync(file, "utf8");
  for (const match of content.matchAll(markdownLink)) {
    const target = match[1];
    if (
      target.startsWith("#") ||
      target.startsWith("[") ||
      /^[a-z][a-z0-9+.-]*:/i.test(target) ||
      target.includes("{")
    ) {
      continue;
    }
    const decodedTarget = decodeURIComponent(target.split("#", 1)[0]);
    const resolved = path.resolve(path.dirname(file), decodedTarget);
    if (!fs.existsSync(resolved)) {
      fail(file, `broken local Markdown link: ${target}`);
    }
  }
}

if (errors.length > 0) {
  console.error(`Skill validation failed with ${errors.length} error(s):`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(
  `Validated ${skillDirs.length} skills: frontmatter, modern sections, progressive disclosure, and local Markdown links.`,
);
