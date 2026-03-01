#!/usr/bin/env node

/**
 * Add "When Called by Another Workflow" trigger to all workflows (01-18).
 * This allows Master Orchestrator to call each workflow as a sub-workflow.
 */

const fs = require('fs');
const path = require('path');

const WORKFLOWS_DIR = path.join(__dirname, '..', 'workflows');

const files = fs.readdirSync(WORKFLOWS_DIR)
  .filter(f => f.endsWith('.json') && !f.startsWith('19-'))
  .sort();

let updated = 0;

files.forEach(file => {
  const filePath = path.join(WORKFLOWS_DIR, file);
  const workflow = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  // Check if sub-workflow trigger already exists
  const hasSubTrigger = workflow.nodes.some(n =>
    n.type === 'n8n-nodes-base.executeWorkflowTrigger'
  );

  if (hasSubTrigger) {
    console.log(`⏭ ${file} - already has sub-workflow trigger`);
    return;
  }

  // Find the first non-trigger node (the node that triggers connect to)
  const triggerNodes = workflow.nodes.filter(n =>
    n.type.includes('Trigger') || n.type.includes('trigger') ||
    n.type.includes('schedule') || n.type.includes('webhook') ||
    n.type.includes('manualTrigger')
  );

  // Find what the first trigger connects to
  let firstTargetNode = null;
  for (const trigger of triggerNodes) {
    const connections = workflow.connections[trigger.name];
    if (connections && connections.main && connections.main[0] && connections.main[0].length > 0) {
      firstTargetNode = connections.main[0][0].node;
      break;
    }
  }

  if (!firstTargetNode) {
    console.log(`⚠ ${file} - could not determine first target node, skipping`);
    return;
  }

  // Find position for new trigger (offset from existing triggers)
  const maxY = Math.max(...triggerNodes.map(n => n.position[1]));

  // Add the sub-workflow trigger node
  const subTriggerNode = {
    parameters: {},
    id: "sub-workflow-trigger",
    name: "Called by Orchestrator",
    type: "n8n-nodes-base.executeWorkflowTrigger",
    typeVersion: 1,
    position: [triggerNodes[0].position[0], maxY + 150]
  };

  workflow.nodes.push(subTriggerNode);

  // Connect it to the same first target node
  // Get all connections from the first trigger to find the targets
  const firstTrigger = triggerNodes[0];
  const firstTriggerConnections = workflow.connections[firstTrigger.name];

  if (firstTriggerConnections && firstTriggerConnections.main) {
    workflow.connections["Called by Orchestrator"] = {
      main: JSON.parse(JSON.stringify(firstTriggerConnections.main))
    };
  } else {
    workflow.connections["Called by Orchestrator"] = {
      main: [[{ node: firstTargetNode, type: "main", index: 0 }]]
    };
  }

  // Save
  fs.writeFileSync(filePath, JSON.stringify(workflow, null, 2));
  console.log(`✅ ${file} - added sub-workflow trigger → ${firstTargetNode}`);
  updated++;
});

console.log(`\nUpdated ${updated}/${files.length} workflows.`);
