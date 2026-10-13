public enum NativeIOError: Error {
    case unsafeStorage, system(Int32), malformed, busy, failed, timeout, cancelled, outputLimit, readback
}
