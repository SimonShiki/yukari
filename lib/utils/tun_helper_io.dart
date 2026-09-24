/// Stub implementation for non-Windows platforms.
/// This file is imported on Linux, macOS, and other non-Windows platforms.
/// Returns false since Windows elevation checks don't apply here.
bool checkWindowsElevation() {
  // This should never be called on non-Windows platforms
  return false;
}

/// Stub implementation for requesting elevation on non-Windows platforms.
bool requestWindowsElevation() {
  // This should never be called on non-Windows platforms
  return false;
}
