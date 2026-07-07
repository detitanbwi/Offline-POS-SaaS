import '../models/payment_method.dart';

abstract class PaymentMethodRepository {
  Future<List<PaymentMethod>> getAllPaymentMethods();
  Future<PaymentMethod?> getPaymentMethodById(String id);
  Future<void> insertPaymentMethod(PaymentMethod paymentMethod);
  Future<void> updatePaymentMethod(PaymentMethod paymentMethod);
  Future<void> deletePaymentMethod(String id);
  Future<bool> isPaymentMethodNameExists(String name, {String? excludeId});
}
