import 'dart:io' as io;

Future<void> restartApplication() async {
  if (!io.Platform.isWindows && !io.Platform.isMacOS) return;

  await io.Process.start(
    io.Platform.resolvedExecutable,
    io.Platform.executableArguments,
    mode: io.ProcessStartMode.detached,
  );
  io.exit(0);
}
