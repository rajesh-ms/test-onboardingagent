import fs from 'node:fs';

const manifest = JSON.parse(fs.readFileSync('agent-manifest.json', 'utf8'));
const requiredTopLevel = ['name', 'version', 'description', 'owner', 'runtime', 'capabilities', 'rai', 'repository'];
const missing = requiredTopLevel.filter((field) => manifest[field] === undefined);

if (missing.length > 0) {
  throw new Error(`agent-manifest.json is missing required fields: ${missing.join(', ')}`);
}

if (manifest.runtime.type !== 'aca') {
  throw new Error('runtime.type must be aca for this marketplace demo');
}

if (!manifest.repository.url.startsWith('https://github.com/')) {
  throw new Error('repository.url must point to GitHub');
}

if (!Array.isArray(manifest.rai.data_categories) || manifest.rai.data_categories.length === 0) {
  throw new Error('rai.data_categories must declare the data handled by the agent');
}

console.log('agent-manifest.json is ready for AI Marketplace onboarding');