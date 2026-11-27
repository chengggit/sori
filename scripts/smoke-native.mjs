import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const require = createRequire(import.meta.url);
const addon = require(join(root, 'apps', 'desktop', 'native', 'sori-node.node'));

addon.init(join(root, 'resources', 'kiwi'));
const reply = JSON.parse(
  await addon.invoke('analyzeText', JSON.stringify({ text: '학교에 갔어요.' })),
);

if (!reply.ok || !Array.isArray(reply.data) || reply.data.length === 0) {
  console.error('Native analysis smoke check failed:', reply);
  process.exit(1);
}

console.log(reply.data.map((token) => `${token.form}/${token.tag}`).join(' '));
