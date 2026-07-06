import '../domain/cabinet_session.dart';

abstract class CabinetSessionStorage {
  Future<CabinetSession?> load();

  Future<void> save(CabinetSession session);

  Future<void> clear();
}
