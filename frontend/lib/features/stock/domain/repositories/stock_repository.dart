import '../models/stock_in.dart';

abstract class StockRepository {
  Future<List<StockIn>> getAllStockIn();
  Future<void> insertStockIn(StockIn stockIn);
}
