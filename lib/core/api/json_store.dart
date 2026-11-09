import 'json_store_base.dart';
import 'json_store_memory.dart'
    if (dart.library.io) 'json_store_io.dart'
    if (dart.library.js_interop) 'json_store_web.dart' as impl;

export 'json_store_base.dart';

/// 按平台造一个持久化实现：原生写文件、Web 写 localStorage、
/// 其余平台（含测试环境的默认分支）退回内存。
JsonStore createJsonStore() => impl.createJsonStore();
