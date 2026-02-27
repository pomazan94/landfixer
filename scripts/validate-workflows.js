#!/usr/bin/env node

/**
 * Validate all n8n workflow JSON files in the workflows/ directory.
 * Checks for valid JSON, required fields, and node connections.
 *
 * Usage: node scripts/validate-workflows.js
 */

const fs = require('fs');
const path = require('path');

const WORKFLOWS_DIR = path.join(__dirname, '..', 'workflows');

function validateWorkflow(filePath) {
  const fileName = path.basename(filePath);
  const errors = [];

  // Parse JSON
  let workflow;
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    workflow = JSON.parse(content);
  } catch (e) {
    return { file: fileName, valid: false, errors: [`Invalid JSON: ${e.message}`] };
  }

  // Check required top-level fields
  if (!workflow.name) errors.push('Missing "name" field');
  if (!workflow.nodes || !Array.isArray(workflow.nodes)) errors.push('Missing or invalid "nodes" array');
  if (!workflow.connections || typeof workflow.connections !== 'object') errors.push('Missing or invalid "connections" object');

  // Validate nodes
  if (workflow.nodes) {
    const nodeNames = new Set();
    workflow.nodes.forEach((node, i) => {
      if (!node.id) errors.push(`Node ${i}: missing "id"`);
      if (!node.name) errors.push(`Node ${i}: missing "name"`);
      if (!node.type) errors.push(`Node ${i}: missing "type"`);
      if (!node.position) errors.push(`Node ${i}: missing "position"`);
      if (nodeNames.has(node.name)) errors.push(`Node ${i}: duplicate name "${node.name}"`);
      nodeNames.add(node.name);
    });

    // Validate connections reference existing nodes
    for (const [sourceName, outputs] of Object.entries(workflow.connections)) {
      if (!nodeNames.has(sourceName)) {
        errors.push(`Connection from non-existent node: "${sourceName}"`);
      }
      if (outputs.main) {
        outputs.main.forEach((connections, outputIndex) => {
          if (Array.isArray(connections)) {
            connections.forEach(conn => {
              if (!nodeNames.has(conn.node)) {
                errors.push(`Connection to non-existent node: "${conn.node}" (from "${sourceName}")`);
              }
            });
          }
        });
      }
    }

    // Check for trigger node
    const hasTrigger = workflow.nodes.some(n =>
      n.type.includes('Trigger') || n.type.includes('trigger') ||
      n.type.includes('webhook') || n.type.includes('schedule')
    );
    if (!hasTrigger) errors.push('No trigger node found');
  }

  return {
    file: fileName,
    valid: errors.length === 0,
    errors,
    nodeCount: workflow.nodes?.length || 0,
    connectionCount: Object.keys(workflow.connections || {}).length
  };
}

// Main
console.log('Validating n8n workflows...\n');

let files;
try {
  files = fs.readdirSync(WORKFLOWS_DIR).filter(f => f.endsWith('.json')).sort();
} catch (e) {
  console.error(`Error reading workflows directory: ${e.message}`);
  process.exit(1);
}

if (files.length === 0) {
  console.log('No workflow files found.');
  process.exit(0);
}

let totalErrors = 0;

files.forEach(file => {
  const result = validateWorkflow(path.join(WORKFLOWS_DIR, file));
  const status = result.valid ? '✅' : '❌';
  console.log(`${status} ${result.file} (${result.nodeCount} nodes, ${result.connectionCount} connections)`);
  if (!result.valid) {
    result.errors.forEach(err => console.log(`   ⚠ ${err}`));
    totalErrors += result.errors.length;
  }
});

console.log(`\n${files.length} workflows checked.`);
if (totalErrors > 0) {
  console.log(`❌ ${totalErrors} error(s) found.`);
  process.exit(1);
} else {
  console.log('✅ All workflows valid.');
}
