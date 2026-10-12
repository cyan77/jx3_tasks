ObjC.import('AppKit');
ObjC.import('Foundation');

function run(argv) {
  const appPath = argv[0];
  if (!appPath || !$.NSFileManager.defaultManager.fileExistsAtPath(appPath)) {
    return 'No installed application to restart';
  }
  const running = $.NSRunningApplication.runningApplicationsWithBundleIdentifier(
    'lynn.game.tasks');
  const clients = [];
  for (let index = 0; index < running.count; index++) {
    const client = running.objectAtIndex(index);
    if (client.bundleURL.path.js === appPath) clients.push(client);
  }
  if (clients.length === 0) return 'Client was not running';

  // Cocoa termination avoids Apple Events permissions and targets this bundle only.
  for (const client of clients) {
    if (!client.terminate) throw new Error('The old client could not be closed');
  }
  const deadline = Date.now() + 30000;
  while (clients.some(client => !client.isTerminated)) {
    if (Date.now() >= deadline) throw new Error('Timed out waiting for the old client');
    $.NSThread.sleepForTimeInterval(0.2);
  }
  const workspace = $.NSWorkspace.sharedWorkspace;
  const url = $.NSURL.fileURLWithPath(appPath);
  if (!workspace.launchApplicationAtURLOptionsConfigurationError(
    url, 0, $.NSDictionary.dictionary, null)) {
    throw new Error('The updated client could not be launched');
  }
  return 'Updated client reopened';
}
