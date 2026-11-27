import { mkdtempSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const require = createRequire(import.meta.url);
const addon = require(join(root, 'apps', 'desktop', 'native', 'sori-node.node'));

async function call(command, payload = {}) {
  const reply = JSON.parse(await addon.invoke(command, JSON.stringify(payload)));
  if (!reply.ok) throw new Error(`${command}: ${reply.error}`);
  return reply.data;
}

const directory = mkdtempSync(join(tmpdir(), 'sori-persistence-'));
try {
  addon.initLibrary(directory);
  await call('document:add', { title: '한국어', content: '안녕하세요' });

  let state = await call('library:state');
  if (state.documents.length !== 1) throw new Error('Document was not listed.');
  const id = state.documents[0].id;

  const document = await call('document:read', { id });
  if (document.content !== '안녕하세요') throw new Error('Document content mismatch.');

  await call('progress:saveDocument', { id, position: 0.6 });
  const resumed = await call('document:read', { id });
  if (resumed.position !== 0.6) throw new Error('Reading progress was not saved.');

  const entry = await call('vocabulary:save', {
    kind: 'document',
    id,
    input: { word: '안녕', context: '안녕하세요', tags: [] },
  });
  state = await call('library:state');
  if (state.vocabulary.length !== 1) throw new Error('Vocabulary was not saved.');

  await call('vocabulary:remove', { id: entry.id });
  await call('document:remove', { id });
  state = await call('library:state');
  if (state.vocabulary.length || state.documents.length) {
    throw new Error('Removal left data behind.');
  }

  console.log('Persistence smoke: OK');
} finally {
  rmSync(directory, { recursive: true, force: true });
}
