class ResolvedSubscriptionInfo {
  const ResolvedSubscriptionInfo({
    this.profileTitle,
    this.announce,
    this.profileUpdateIntervalHours,
    this.refillAt,
    this.expireAt,
    this.uploadBytes,
    this.downloadBytes,
    this.totalBytes,
    this.webPageUrl,
    this.supportUrl,
  });

  final String? profileTitle;
  final String? announce;
  final int? profileUpdateIntervalHours;
  final DateTime? refillAt;
  final DateTime? expireAt;
  final int? uploadBytes;
  final int? downloadBytes;
  final int? totalBytes;
  final String? webPageUrl;
  final String? supportUrl;

  int? get usedBytes {
    final int upload = uploadBytes ?? 0;
    final int download = downloadBytes ?? 0;
    if (upload == 0 && download == 0) {
      return null;
    }
    return upload + download;
  }

  int? get remainingBytes {
    final int? total = totalBytes;
    final int? used = usedBytes;
    if (total == null || total <= 0 || used == null) {
      return null;
    }
    final int remaining = total - used;
    return remaining < 0 ? 0 : remaining;
  }
}
