import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../models/sale.dart';

class MLService {
  OrtSession? _session;
  
  Future<void> initialize() async {
    if (_session != null) return;
    
    try {
      final rawAssetFile = await rootBundle.load('lib/models/umkm_forecast.onnx');
      final bytes = rawAssetFile.buffer.asUint8List();
      
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
    } catch (e) {
      print('Error loading ONNX model: $e');
    }
  }
  
  double _calculateEWM(List<double> values, {int span = 7}) {
    if (values.isEmpty) return 0;
    
    final alpha = 2 / (span + 1);
    double result = values[0];
    
    for (int i = 1; i < values.length; i++) {
      result = alpha * values[i] + (1 - alpha) * result;
    }
    
    return result;
  }
  
  Future<List<Map<String, dynamic>>> forecast({
    required int outletId,
    required int productId,
    required List<Sale> historicalSales,
    int days = 3,
  }) async {
    if (_session == null) await initialize();
    if (historicalSales.length < 7) {
      throw Exception('Need at least 7 days of historical data');
    }
    
    // Sort and get last 7 days
    historicalSales.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final last7 = historicalSales.map((s) => s.quantity.toDouble()).toList().sublist(
      max(0, historicalSales.length - 7)
    );
    
    final lastDate = historicalSales.last.createdAt;
    final List<Map<String, dynamic>> forecasts = [];
    final historicalValues = List<double>.from(last7);
    
    for (int day = 1; day <= days; day++) {
      final forecastDate = lastDate.add(Duration(days: day));
      
      // Calculate features
      final lag1 = historicalValues.isNotEmpty ? historicalValues.last : 0.0;
      final lag3 = historicalValues.length >= 3 ? historicalValues[historicalValues.length - 3] : 0.0;
      final lag7 = historicalValues.length >= 7 ? historicalValues[historicalValues.length - 7] : 0.0;
      
      final last3 = historicalValues.length >= 3 
          ? historicalValues.sublist(historicalValues.length - 3)
          : historicalValues;
      final last7Full = historicalValues.length >= 7
          ? historicalValues.sublist(historicalValues.length - 7)
          : historicalValues;
      
      final rollingMean3 = last3.isEmpty ? 0.0 : last3.reduce((a, b) => a + b) / last3.length;
      final rollingMean7 = last7Full.isEmpty ? 0.0 : last7Full.reduce((a, b) => a + b) / last7Full.length;
      
      // Calculate std
      double rollingStd3 = 0.0;
      if (last3.length >= 2) {
        final mean = rollingMean3;
        final variance = last3.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / last3.length;
        rollingStd3 = sqrt(variance);
      }
      
      final ewm7 = _calculateEWM(historicalValues, span: 7);
      final dayOfWeek = forecastDate.weekday - 1; // 0-6 (Monday=0)
      final isWeekend = dayOfWeek >= 5 ? 1.0 : 0.0;
      
      // Prepare features in exact order
      final features = [
        outletId.toDouble(),      // outlet_id
        productId.toDouble(),     // product_id
        lag1,                     // lag_1
        lag3,                     // lag_3
        lag7,                     // lag_7
        rollingMean3,             // rolling_mean_3
        rollingMean7,             // rolling_mean_7
        rollingStd3,              // rolling_std_3
        ewm7,                     // ewm_7
        dayOfWeek.toDouble(),     // dayofweek
        isWeekend,                // is_weekend
        forecastDate.day.toDouble(),   // day
        forecastDate.month.toDouble(), // month
      ];
      
      // Run prediction
      final inputOrt = OrtValueTensor.createTensorWithDataList(
        [features],
        [1, 13],
      );
      
      final inputs = {'float_input': inputOrt};
      final outputs = await _session!.runAsync(
        OrtRunOptions(),
        inputs,
      );
      
      final prediction = (outputs?[0]?.value as List<List<double>>)[0][0];
      final forecastValue = max(0.0, prediction);
      
      inputOrt.release();
      outputs?.forEach((element) => element?.release());
      
      forecasts.add({
        'date': forecastDate,
        'forecast': forecastValue.round(),
      });
      
      // Add prediction to history for next iteration
      historicalValues.add(forecastValue);
    }
    
    return forecasts;
  }
  
  void dispose() {
    _session?.release();
    _session = null;
  }
}