class VlessProfile {
  const VlessProfile({
    required this.uuid,
    required this.host,
    required this.port,
    required this.security,
    required this.transport,
    required this.encryption,
    this.flow,
    this.fingerprint,
    this.publicKey,
    this.shortId,
    this.spiderX,
    this.remark,
    this.serverName,
  });

  final String uuid;
  final String host;
  final int port;
  final String security;
  final String transport;
  final String encryption;
  final String? flow;
  final String? fingerprint;
  final String? publicKey;
  final String? shortId;
  final String? spiderX;
  final String? remark;
  final String? serverName;
}
