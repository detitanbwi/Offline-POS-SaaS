import '../models/tax_setting.dart';

abstract class TaxRepository {
  Future<TaxSetting> getTaxSetting();
  Future<void> updateTaxSetting(TaxSetting taxSetting);
}
