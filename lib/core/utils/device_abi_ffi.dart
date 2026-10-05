import 'dart:ffi' show Abi;

/// arm64 for modern devices, arm32 for the legacy 32-bit Android phones —
/// matching the per-ABI release APKs the manifest ships with.
String deviceApkAbi() =>
    Abi.current() == Abi.androidArm ? 'arm32' : 'arm64';