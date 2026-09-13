/// Helper utility for handling soft-delete name collisions with SQLite UNIQUE constraints.
class SoftDeleteHelper {
  static const String delMarker = '__del_';

  /// Generates a unique tombstone name for a soft-deleted item
  /// Example: "Nasi Goreng" -> "Nasi Goreng__del_1726200000000"
  static String makeDeletedName(String originalName) {
    final clean = cleanDeletedName(originalName);
    return '${clean}${delMarker}${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Strips the deleted tombstone marker from a name for user-facing display
  /// Example: "Nasi Goreng__del_1726200000000" -> "Nasi Goreng"
  static String cleanDeletedName(String name) {
    final idx = name.indexOf(delMarker);
    if (idx != -1) {
      return name.substring(0, idx);
    }
    return name;
  }

  /// Alias for cleanDeletedName
  static String getOriginalName(String name) => cleanDeletedName(name);

  /// Helper for table nomor
  static String makeDeletedNomor(String nomor) => makeDeletedName(nomor);
  static String getOriginalNomor(String nomor) => cleanDeletedName(nomor);

  /// Checks if a given name contains a tombstone deleted marker
  static bool isDeletedName(String name) {
    return name.contains(delMarker);
  }
}
