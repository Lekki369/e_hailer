const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const source = fs.readFileSync('web/firebase-messaging-sw.js', 'utf8');

function worker({emulator = false, version = '13.1.0'} = {}) {
  const imports = [], initialized = [];
  const context = {
    self: {},
    importScripts(url) {
      imports.push(url);
      if (url === 'firebase-client-config.js') {
        Object.assign(context.self, {
          E_HAILER_FIREBASE_EMULATORS: emulator,
          E_HAILER_FIREBASE_SDK_VERSION: version,
          E_HAILER_FIREBASE_CONFIG: {projectId: 'fixture-only'},
        });
      }
    },
    firebase: {initializeApp: value => initialized.push(value), messaging: () => ({})},
    console: {log: () => assert.fail('Notification contents must not be logged')},
  };
  return {run: () => vm.runInNewContext(source, context), imports, initialized};
}

test('worker uses generated config and only the pinned Firebase script origin', () => {
  const fixture = worker();
  fixture.run();
  assert.deepEqual(fixture.initialized, [{projectId: 'fixture-only'}]);
  assert.deepEqual(fixture.imports.slice(1), [
    'https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js',
    'https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js',
  ]);
});

test('emulator worker makes no remote SDK request or Firebase registration', () => {
  const fixture = worker({emulator: true});
  fixture.run();
  assert.equal(fixture.imports.length, 1);
  assert.equal(fixture.initialized.length, 0);
});

test('malformed SDK configuration fails before any remote script import', () => {
  const fixture = worker({version: '../untrusted'});
  assert.throws(fixture.run);
  assert.equal(fixture.imports.length, 1);
});
