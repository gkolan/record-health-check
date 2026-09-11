/** Preserves the established blue Action URL acceptance contract unchanged. */
public class RecordHealthCheckActionUrlPolicy {
  public static String sanitize(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String url = value.trim();
    if (
      url.length() > 2000 ||
      url.contains('\n') ||
      url.contains('\r') ||
      url.contains('\t') ||
      url.contains('\\') ||
      url.startsWith('//')
    ) {
      return null;
    }
    return url.startsWith('/') || url.toLowerCase().startsWith('https://')
      ? url
      : null;
  }
}
