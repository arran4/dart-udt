/// High-level module mapping from upstream UDT C++ files to pure Dart libraries.
///
/// This does not implement full behavior yet; it documents canonical ownership so
/// the incremental port can stay line-by-line traceable.
enum UdtModule {
  api,
  core,
  channel,
  epoll,
  queue,
  buffer,
  packet,
  window,
  cache,
  list,
  ccc,
  md5,
  common,
}

extension UdtModuleDescription on UdtModule {
  String get dartTarget => switch (this) {
        UdtModule.api => 'lib/src/udt_port/api/',
        UdtModule.core => 'lib/src/udt_port/core/',
        UdtModule.channel => 'lib/src/udt_port/channel/',
        UdtModule.epoll => 'lib/src/udt_port/epoll/',
        UdtModule.queue => 'lib/src/udt_port/queue/',
        UdtModule.buffer => 'lib/src/udt_port/buffer/',
        UdtModule.packet => 'lib/src/udt_port/protocol/',
        UdtModule.window => 'lib/src/udt_port/window/',
        UdtModule.cache => 'lib/src/udt_port/cache/',
        UdtModule.list => 'lib/src/udt_port/list/',
        UdtModule.ccc => 'lib/src/udt_port/ccc/',
        UdtModule.md5 => 'lib/src/udt_port/md5/',
        UdtModule.common => 'lib/src/udt_port/common/',
      };
}
