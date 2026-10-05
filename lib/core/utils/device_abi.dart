// Conditional export: stubs on web (no APK), FFI implementation on Android.
// Mirrors Kelilink `kelilink-app/lib/core/utils/device_abi.dart` so the server
// can ship separate arm64 / arm32 APKs and the client picks the right one.
export 'device_abi_stub.dart' if (dart.library.ffi) 'device_abi_ffi.dart';