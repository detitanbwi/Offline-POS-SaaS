import '../models/cashier.dart';

abstract class CashierRepository {
  Future<List<CashierModel>> getAllCashiers();
  Future<CashierModel?> getCashierById(String id);
  Future<CashierModel?> getCashierByPin(String hashedPin);
  Future<void> saveCashier(CashierModel cashier);
  Future<void> updateStatus(String id, int status);
  Future<void> softDelete(String id);
}
