import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/product_provider.dart';
import '../services/ml_service.dart';
import '../utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _dailyRevenue = 0.0;
  double _weeklyRevenue = 0.0;
  String? _selectedProductId;
  List<FlSpot> _salesData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await _loadRevenue();
    await _loadSalesData();
    setState(() => _isLoading = false);
  }

  Future<void> _loadRevenue() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

    // Load sales filtered by product
    await provider.loadSales(startDate: todayStart, endDate: todayEnd);
    final todaySales = _selectedProductId == null
        ? provider.sales
        : provider.sales.where((s) => s.productId == _selectedProductId).toList();

    await provider.loadSales(startDate: weekStartDate, endDate: todayEnd);
    final weekSales = _selectedProductId == null
        ? provider.sales
        : provider.sales.where((s) => s.productId == _selectedProductId).toList();

    if (mounted) {
      setState(() {
        _dailyRevenue = todaySales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
        _weeklyRevenue = weekSales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
      });
    }
  }

  Future<void> _loadSalesData() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));

    await provider.loadSales(startDate: weekStart, endDate: now);

    // Filter by product if selected
    final sales = _selectedProductId == null
        ? provider.sales
        : provider.sales.where((s) => s.productId == _selectedProductId).toList();

    // Group by day
    Map<int, double> dailyTotals = {};
    for (var sale in sales) {
      final dayIndex = sale.createdAt.difference(weekStart).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        dailyTotals[dayIndex] = (dailyTotals[dayIndex] ?? 0) + sale.quantity.toDouble();
      }
    }

    if (mounted) {
      setState(() {
        _salesData = List.generate(7, (i) {
          return FlSpot(i.toDouble(), dailyTotals[i] ?? 0);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppConstants.backgroundGrey,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppConstants.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Filter
                    Consumer<ProductProvider>(
                      builder: (context, provider, _) {
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppConstants.paddingMedium),
                            child: DropdownButtonFormField<String?>(
                              decoration: InputDecoration(
                                labelText: 'Filter Produk',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              value: _selectedProductId,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Semua Produk'),
                                ),
                                ...provider.products.map((product) {
                                  return DropdownMenuItem(
                                    value: product.id,
                                    child: Text(
                                      product.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedProductId = value;
                                });
                                _loadAllData();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),

                    // Revenue Cards
                    Row(
                      children: [
                        Expanded(
                          child: _RevenueCard(
                            title: 'Hari Ini',
                            amount: formatter.format(_dailyRevenue),
                            icon: Icons.today,
                            color: AppConstants.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingMedium),
                        Expanded(
                          child: _RevenueCard(
                            title: 'Minggu Ini',
                            amount: formatter.format(_weeklyRevenue),
                            icon: Icons.calendar_today,
                            color: AppConstants.successGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingLarge),

                    // Sales Chart
                    Row(
                      children: [
                        Icon(Icons.show_chart, color: AppConstants.primaryBlue, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Grafik Penjualan (7 Hari)',
                          style: TextStyle(
                            fontSize: AppConstants.fontSizeLarge,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),
                    _SalesChart(salesData: _salesData),
                    const SizedBox(height: AppConstants.paddingLarge),

                    // ML Forecasting Section
                    Row(
                      children: [
                        Icon(Icons.auto_graph, color: AppConstants.primaryBlue, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Prediksi Penjualan (AI)',
                          style: TextStyle(
                            fontSize: AppConstants.fontSizeLarge,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),
                    _ForecastingCard(selectedProductId: _selectedProductId),
                    const SizedBox(height: AppConstants.paddingLarge),

                    // Recent Sales
                    Row(
                      children: [
                        Icon(Icons.history, color: AppConstants.primaryBlue, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Penjualan Terbaru',
                          style: TextStyle(
                            fontSize: AppConstants.fontSizeLarge,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),
                    const _RecentSalesList(),
                    const SizedBox(height: AppConstants.paddingMedium),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const _RevenueCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  final List<FlSpot> salesData;

  const _SalesChart({required this.salesData});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.2),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: AppConstants.textGrey,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final dayIndex = value.toInt();
                    final date = now.subtract(Duration(days: 6 - dayIndex));
                    final dayName = _getDayName(date.weekday);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dayName,
                        style: TextStyle(
                          color: AppConstants.textGrey,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: _generateChartData(),
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppConstants.primaryBlue,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: AppConstants.primaryBlue,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryBlue.withOpacity(0.3),
                      AppConstants.primaryBlue.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toInt()} unit',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[weekday - 1];
  }

  List<FlSpot> _generateChartData() {
    return salesData.isEmpty
        ? [const FlSpot(0, 0), const FlSpot(6, 0)]
        : salesData;
  }
}

class _ForecastingCard extends StatefulWidget {
  final String? selectedProductId;

  const _ForecastingCard({this.selectedProductId});

  @override
  State<_ForecastingCard> createState() => _ForecastingCardState();
}

class _ForecastingCardState extends State<_ForecastingCard> {
  final MLService _mlService = MLService();
  List<Map<String, dynamic>>? _forecasts;
  bool _isLoading = false;
  String? _error;
  bool _hasEnoughData = false;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  @override
  void didUpdateWidget(covariant _ForecastingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProductId != widget.selectedProductId) {
      _loadForecast();
    }
  }

  Future<void> _loadForecast() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _forecasts = null;
    });

    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);

      // Get historical sales data (last 14 days)
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 14));
      await provider.loadSales(startDate: startDate, endDate: now);

      // Filter by product if selected
      final sales = widget.selectedProductId == null
          ? provider.sales
          : provider.sales.where((s) => s.productId == widget.selectedProductId).toList();

      // Check if we have enough data
      if (sales.length < 7) {
        setState(() {
          _hasEnoughData = false;
          _isLoading = false;
        });
        return;
      }

      _hasEnoughData = true;

      // Initialize ML service and get forecast
      await _mlService.initialize();

      // Use default IDs for forecast (the model accepts any outlet/product IDs)
      final forecasts = await _mlService.forecast(
        outletId: 1,
        productId: widget.selectedProductId != null
            ? int.tryParse(widget.selectedProductId!) ?? 1
            : 1,
        historicalSales: sales,
        days: 3,
      );

      if (mounted) {
        setState(() {
          _forecasts = forecasts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormatter = DateFormat('EEE, d MMM', 'id_ID');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.accentBlue.withOpacity(0.15),
              AppConstants.lightBlue.withOpacity(0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: AppConstants.primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prediksi AI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Model LightGBM',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConstants.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: AppConstants.primaryBlue),
                  onPressed: _isLoading ? null : _loadForecast,
                  tooltip: 'Refresh Prediksi',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Menganalisis data penjualan...'),
                    ],
                  ),
                ),
              )
            else if (!_hasEnoughData)
              _buildInfoCard(
                icon: Icons.info_outline,
                color: Colors.orange,
                title: 'Data Belum Cukup',
                message: 'Minimal 7 transaksi diperlukan untuk prediksi. Terus jual produk Anda!',
              )
            else if (_error != null)
              _buildInfoCard(
                icon: Icons.warning_amber_outlined,
                color: AppConstants.errorRed,
                title: 'Gagal Memuat Prediksi',
                message: 'Coba refresh atau periksa model AI.',
              )
            else if (_forecasts != null && _forecasts!.isNotEmpty)
              Column(
                children: [
                  // Forecast cards
                  ...List.generate(_forecasts!.length, (index) {
                    final forecast = _forecasts![index];
                    final date = forecast['date'] as DateTime;
                    final quantity = forecast['forecast'] as int;

                    // Get average price from provider for revenue estimation
                    final provider = Provider.of<ProductProvider>(context, listen: false);
                    final avgPrice = provider.products.isNotEmpty
                        ? provider.products.map((p) => p.price).reduce((a, b) => a + b) / provider.products.length
                        : 0.0;
                    final estimatedRevenue = quantity * avgPrice;

                    return Container(
                      margin: EdgeInsets.only(bottom: index < _forecasts!.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        border: Border.all(
                          color: index == 0
                              ? AppConstants.primaryBlue.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Date
                          Container(
                            width: 60,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  index == 0 ? 'Besok' : index == 1 ? 'Lusa' : '+3 Hari',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppConstants.textGrey,
                                  ),
                                ),
                                Text(
                                  dateFormatter.format(date),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Quantity
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 16,
                                      color: AppConstants.primaryBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$quantity unit',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppConstants.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                if (avgPrice > 0)
                                  Text(
                                    '~ ${formatter.format(estimatedRevenue)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppConstants.successGreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Trend indicator
                          Icon(
                            quantity > 0 ? Icons.trending_up : Icons.trending_flat,
                            color: quantity > 0 ? AppConstants.successGreen : Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              )
            else
              _buildInfoCard(
                icon: Icons.auto_graph,
                color: AppConstants.primaryBlue,
                title: 'Siap Prediksi',
                message: 'Tekan tombol refresh untuk memuat prediksi penjualan.',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSalesList extends StatelessWidget {
  const _RecentSalesList();

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormatter = DateFormat('dd MMM, HH:mm', 'id_ID');

    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        final recentSales = provider.sales.take(5).toList();

        if (recentSales.isEmpty) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada penjualan',
                    style: TextStyle(
                      color: AppConstants.textGrey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mulai jual produk di halaman "Jual"',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentSales.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final sale = recentSales[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: AppConstants.primaryBlue.withOpacity(0.1),
                  child: Icon(
                    Icons.shopping_bag,
                    color: AppConstants.primaryBlue,
                    size: 20,
                  ),
                ),
                title: Text(
                  sale.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${sale.quantity}x • ${dateFormatter.format(sale.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.textGrey,
                  ),
                ),
                trailing: Text(
                  formatter.format(sale.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.successGreen,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
