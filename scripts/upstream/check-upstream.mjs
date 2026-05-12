#!/usr/bin/env node
import { promises as fs } from 'fs';
import path from 'path';

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run') || process.env.DRY_RUN === 'true';
const jsonOutput = args.has('--json') || process.env.JSON_OUTPUT === 'true';
const shouldWriteIssue = !dryRun && !args.has('--no-issue');

const upstreamRepo = process.env.UPSTREAM_REPO || 'openclaw/Peekaboo';
const upstreamBranch = process.env.UPSTREAM_BRANCH || 'main';
const targetRepo = process.env.GITHUB_REPOSITORY || process.env.TARGET_REPO || '';
const issueTitle = process.env.UPSTREAM_WATCH_ISSUE_TITLE || 'Upstream Peekaboo changes available';
const lastReviewedPath = process.env.UPSTREAM_LAST_REVIEWED_PATH ||
  'docs/upstream/last-reviewed-upstream.txt';
const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN || '';

function parseRepo(repo) {
  const [owner, name] = repo.split('/');
  if (!owner || !name) {
    throw new Error(`Repository must be in owner/name form: ${repo}`);
  }
  return { owner, name };
}

async function readLastReviewedSha() {
  if (process.env.UPSTREAM_LAST_REVIEWED_SHA) {
    return process.env.UPSTREAM_LAST_REVIEWED_SHA.trim();
  }

  const text = await fs.readFile(path.resolve(lastReviewedPath), 'utf8');
  const match = text.match(/[0-9a-f]{40}/i);
  if (!match) {
    throw new Error(`${lastReviewedPath} must contain a 40-character upstream commit SHA.`);
  }
  return match[0];
}

async function github(pathname, options = {}) {
  const headers = {
    Accept: 'application/vnd.github+json',
    'User-Agent': 'peekaboo-upstream-watch',
    'X-GitHub-Api-Version': '2022-11-28',
    ...options.headers,
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`https://api.github.com${pathname}`, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const message = data?.message || text || response.statusText;
    throw new Error(`GitHub API ${response.status} for ${pathname}: ${message}`);
  }

  return data;
}

function categorizePath(filePath) {
  if (
    filePath.startsWith('Platforms/Windows/') ||
    filePath.startsWith('scripts/windows/') ||
    filePath === '.github/workflows/windows-11-platform.yml' ||
    filePath === 'docs/windows-11-refactor.md'
  ) {
    return 'windows-direct';
  }

  if (
    filePath.startsWith('Core/PeekabooDesktop/') ||
    filePath.startsWith('Apps/CLI/') ||
    filePath === 'Package.swift' ||
    filePath === 'peekaboo-mcp.js' ||
    filePath === 'package.json' ||
    filePath === 'pnpm-lock.yaml' ||
    filePath === 'pnpm-workspace.yaml'
  ) {
    return 'shared-contract-or-cli';
  }

  if (
    filePath.startsWith('Core/') ||
    filePath.startsWith('AXorcist/') ||
    filePath.startsWith('Apps/') ||
    filePath.startsWith('Commander/') ||
    filePath.startsWith('Tachikoma/')
  ) {
    return 'mac-source-reference';
  }

  if (
    filePath.startsWith('docs/') ||
    filePath.startsWith('release/') ||
    filePath.startsWith('homebrew/') ||
    filePath === 'README.md' ||
    filePath === 'CHANGELOG.md' ||
    filePath === 'appcast.xml' ||
    filePath === 'version.json'
  ) {
    return 'docs-release';
  }

  if (
    filePath.startsWith('.github/') ||
    filePath.startsWith('scripts/') ||
    filePath.endsWith('.yml') ||
    filePath.endsWith('.yaml')
  ) {
    return 'ci-tooling';
  }

  return 'other';
}

function groupFiles(files) {
  const groups = new Map();
  for (const file of files) {
    const category = categorizePath(file.filename);
    const group = groups.get(category) || [];
    group.push(file);
    groups.set(category, group);
  }
  return groups;
}

function markdownList(items, renderItem, emptyText = '_None._') {
  if (!items.length) {
    return emptyText;
  }
  return items.map(renderItem).join('\n');
}

function buildIssueBody({ branch, compare, groups, lastReviewedSha, latestSha }) {
  const commits = compare.commits || [];
  const files = compare.files || [];
  const groupOrder = [
    'windows-direct',
    'shared-contract-or-cli',
    'mac-source-reference',
    'docs-release',
    'ci-tooling',
    'other',
  ];

  const sections = groupOrder.map(category => {
    const entries = groups.get(category) || [];
    const body = markdownList(entries, file => `- \`${file.filename}\` (${file.status})`);
    return `### ${category}\n${body}`;
  });

  return `## Upstream Watch

New upstream changes were detected in \`${upstreamRepo}:${branch}\`.

- Last reviewed upstream SHA: \`${lastReviewedSha}\`
- Latest upstream SHA: \`${latestSha}\`
- Compare: ${compare.html_url}
- Commits ahead: ${compare.ahead_by}
- Changed files: ${files.length}

## Commit Summary

${markdownList(commits, commit => {
    const shortSha = commit.sha.slice(0, 8);
    const title = commit.commit.message.split('\n')[0];
    return `- \`${shortSha}\` ${title}`;
  })}

## Changed Files By Review Bucket

${sections.join('\n\n')}

## Suggested Review Flow

1. Review \`windows-direct\` and \`shared-contract-or-cli\` first.
2. Treat \`mac-source-reference\` as feature evidence, not as code to merge blindly.
3. Port useful behavior into \`Platforms/Windows/PeekabooWin11\` or \`Core/PeekabooDesktop\`.
4. After review or porting, update \`${lastReviewedPath}\` to the latest upstream SHA.

This issue is generated by \`.github/workflows/upstream-watch.yml\`.`;
}

async function findExistingIssue(repo, title) {
  const issues = await github(`/repos/${repo}/issues?state=open&per_page=100`);
  return issues.find(issue => !issue.pull_request && issue.title === title) || null;
}

async function upsertIssue(body) {
  if (!targetRepo) {
    throw new Error('GITHUB_REPOSITORY or TARGET_REPO is required to create an issue.');
  }
  if (!token) {
    throw new Error('GH_TOKEN or GITHUB_TOKEN is required to create an issue.');
  }

  const existing = await findExistingIssue(targetRepo, issueTitle);
  if (existing) {
    const issue = await github(`/repos/${targetRepo}/issues/${existing.number}`, {
      method: 'PATCH',
      body: { body },
    });
    return { action: 'updated', issue };
  }

  const issue = await github(`/repos/${targetRepo}/issues`, {
    method: 'POST',
    body: { title: issueTitle, body },
  });
  return { action: 'created', issue };
}

async function main() {
  parseRepo(upstreamRepo);
  if (targetRepo) {
    parseRepo(targetRepo);
  }

  const lastReviewedSha = await readLastReviewedSha();
  const branch = await github(`/repos/${upstreamRepo}/branches/${upstreamBranch}`);
  const latestSha = branch.commit.sha;
  const compare = await github(`/repos/${upstreamRepo}/compare/${lastReviewedSha}...${latestSha}`);
  const files = compare.files || [];
  const groups = groupFiles(files);

  const result = {
    upstreamRepo,
    upstreamBranch,
    lastReviewedSha,
    latestSha,
    status: compare.status,
    aheadBy: compare.ahead_by,
    changedFiles: files.length,
    compareUrl: compare.html_url,
  };

  if (compare.ahead_by === 0) {
    if (jsonOutput) {
      console.log(JSON.stringify({ ...result, issue: null }, null, 2));
    } else {
      console.log(`No new upstream commits. ${upstreamRepo}:${upstreamBranch} is at ${latestSha}.`);
    }
    return;
  }

  const body = buildIssueBody({ branch: upstreamBranch, compare, groups, lastReviewedSha, latestSha });
  let issue = null;
  if (shouldWriteIssue) {
    issue = await upsertIssue(body);
  }

  if (jsonOutput) {
    console.log(JSON.stringify({ ...result, issue }, null, 2));
  } else {
    console.log(`Detected ${compare.ahead_by} upstream commit(s).`);
    console.log(`Compare: ${compare.html_url}`);
    if (issue) {
      console.log(`${issue.action} issue: ${issue.issue.html_url}`);
    } else {
      console.log('Issue creation skipped.');
    }
  }

  if (process.env.GITHUB_OUTPUT) {
    await fs.appendFile(
      process.env.GITHUB_OUTPUT,
      `upstream_head=${latestSha}\ncompare_url=${compare.html_url}\n`);
  }
}

main().catch(error => {
  console.error(error.message);
  process.exit(1);
});
