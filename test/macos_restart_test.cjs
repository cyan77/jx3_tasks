const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname,
  '../macos/installer/scripts/restart-app.js'), 'utf8');

function fixture(paths, refusesToQuit = false) {
  const events = [];
  const clients = paths.map(appPath => ({
    bundleURL: { path: { js: appPath } },
    isTerminated: false,
    get terminate() {
      events.push(['quit', appPath]);
      this.isTerminated = !refusesToQuit;
      return !refusesToQuit;
    },
  }));
  const context = vm.createContext({ ObjC: { import() {} }, $: {
    NSFileManager: { defaultManager: { fileExistsAtPath: () => true } },
    NSRunningApplication: { runningApplicationsWithBundleIdentifier: () => ({
      count: clients.length, objectAtIndex: index => clients[index],
    }) },
    NSWorkspace: { sharedWorkspace: {
      launchApplicationAtURLOptionsConfigurationError(url) {
        assert(clients.filter(client => client.bundleURL.path.js === url)
          .every(client => client.isTerminated));
        events.push(['open', url]);
        return {};
      },
    } },
    NSURL: { fileURLWithPath: value => value },
    NSDictionary: { dictionary: {} },
    NSThread: { sleepForTimeInterval() {} },
  } });
  vm.runInContext(source, context);
  return { run: context.run, events };
}

test('installation does not launch a client that was not running', () => {
  const mock = fixture([]);
  mock.run(['/Applications/角色日程.app']);
  assert.deepEqual(mock.events, []);
});
test('only the replaced application is terminated and reopened', () => {
  const app = '/Applications/角色日程.app';
  const mock = fixture([app, '/Volumes/Trial/角色日程.app']);
  mock.run([app]);
  assert.deepEqual(mock.events, [['quit', app], ['open', app]]);
});
test('a failed termination does not launch a duplicate client', () => {
  const app = '/Applications/角色日程.app';
  const mock = fixture([app], true);
  assert.throws(() => mock.run([app]), /could not be closed/);
  assert.deepEqual(mock.events, [['quit', app]]);
});
