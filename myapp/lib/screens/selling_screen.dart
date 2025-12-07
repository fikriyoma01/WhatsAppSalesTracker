import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../providers/product_provider.dart';
import '../models/product.dart';
import '../services/kolosal_api_service.dart';
import '../utils/constants.dart';

class SellingScreen extends StatelessWidget {
  const SellingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundGrey,
      appBar: AppBar(
        title: const Text('Jual Produk'),
        backgroundColor: AppConstants.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final availableProducts = provider.products
              .where((p) => p.stockQuantity > 0)
              .toList();

          if (availableProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tidak ada produk tersedia',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambahkan produk di halaman Katalog',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadProducts(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              itemCount: availableProducts.length,
              itemBuilder: (context, index) {
                final product = availableProducts[index];
                return _ProductSellingCard(product: product);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProductSellingCard extends StatefulWidget {
  final Product product;

  const _ProductSellingCard({required this.product});

  @override
  State<_ProductSellingCard> createState() => _ProductSellingCardState();
}

class _ProductSellingCardState extends State<_ProductSellingCard> {
  int _selectedQuantity = 1;
  bool _isGeneratingCaption = false;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final totalPrice = widget.product.price * _selectedQuantity;

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Column(
        children: [
          // Product header with image and info
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image - larger and more prominent
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: widget.product.imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          child: Image.file(
                            File(widget.product.imagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.image, size: 40, color: Colors.grey[400]);
                            },
                          ),
                        )
                      : Icon(Icons.image, size: 40, color: Colors.grey[400]),
                ),
                const SizedBox(width: AppConstants.paddingMedium),

                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatter.format(widget.product.price),
                        style: TextStyle(
                          color: AppConstants.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.product.stockQuantity > 5
                              ? AppConstants.successGreen.withOpacity(0.1)
                              : AppConstants.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Stok: ${widget.product.stockQuantity}',
                          style: TextStyle(
                            color: widget.product.stockQuantity > 5
                                ? AppConstants.successGreen
                                : AppConstants.errorRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: Colors.grey[200]),

          // Quantity selector and share button
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Row(
              children: [
                // Quantity Selector
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jumlah yang dijual:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConstants.textGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppConstants.primaryBlue, width: 1.5),
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _QuantityButton(
                              icon: Icons.remove,
                              onPressed: _selectedQuantity > 1
                                  ? () => setState(() => _selectedQuantity--)
                                  : null,
                            ),
                            Container(
                              width: 50,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '$_selectedQuantity',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppConstants.primaryBlue,
                                ),
                              ),
                            ),
                            _QuantityButton(
                              icon: Icons.add,
                              onPressed: _selectedQuantity < widget.product.stockQuantity
                                  ? () => setState(() => _selectedQuantity++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Total and Share Button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppConstants.textGrey,
                      ),
                    ),
                    Text(
                      formatter.format(totalPrice),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.successGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // WhatsApp Share Button
                    ElevatedButton.icon(
                      onPressed: _isGeneratingCaption ? null : () => _shareToWhatsApp(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        ),
                      ),
                      icon: _isGeneratingCaption
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.share, size: 20),
                      label: Text(_isGeneratingCaption ? 'Loading...' : 'Share WA'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToWhatsApp(BuildContext context) async {
    setState(() => _isGeneratingCaption = true);

    try {
      // Generate AI caption
      final aiService = KolosalApiService();
      final caption = await aiService.generateProductCaption(
        widget.product.name,
        widget.product.price,
        widget.product.stockQuantity - _selectedQuantity,
      );

      if (!context.mounted) return;

      // Show caption review dialog
      _showCaptionReviewDialog(context, caption);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
            ],
          ),
          backgroundColor: AppConstants.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingCaption = false);
      }
    }
  }

  void _showCaptionReviewDialog(BuildContext context, String caption) {
    final controller = TextEditingController(text: caption);
    bool isCopied = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF25D366),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Caption AI',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Edit jika perlu sebelum dibagikan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Caption TextField
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Caption produk...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppConstants.primaryBlue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Copy Button
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: controller.text));
                      setModalState(() => isCopied = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (context.mounted) {
                          setModalState(() => isCopied = false);
                        }
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isCopied ? AppConstants.successGreen : AppConstants.primaryBlue,
                      side: BorderSide(color: isCopied ? AppConstants.successGreen : AppConstants.primaryBlue),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(isCopied ? Icons.check : Icons.copy),
                    label: Text(isCopied ? 'Caption Tersalin!' : 'Salin Caption'),
                  ),
                  const SizedBox(height: 12),

                  // Share Buttons
                  Row(
                    children: [
                      // Share Image + Caption
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _executeShare(context, controller.text, shareImage: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.image),
                          label: const Text('Share + Gambar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Share Caption Only
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _executeShare(context, controller.text, shareImage: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.text_fields),
                          label: const Text('Teks Saja'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pilih WhatsApp Status/Story setelah share, lalu paste caption yang sudah disalin.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _executeShare(BuildContext context, String caption, {required bool shareImage}) async {
    try {
      // Copy caption to clipboard first
      await Clipboard.setData(ClipboardData(text: caption));

      // Record sale
      if (widget.product.id != null) {
        await Provider.of<ProductProvider>(context, listen: false)
            .recordSale(widget.product.id!, _selectedQuantity);
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Close bottom sheet

      // Share based on option
      if (shareImage && widget.product.imagePath != null) {
        final file = File(widget.product.imagePath!);
        if (await file.exists()) {
          await Share.shareXFiles(
            [XFile(widget.product.imagePath!)],
            text: caption,
          );
        } else {
          await Share.share(caption);
        }
      } else {
        // Try to open WhatsApp directly
        final whatsappUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(caption)}');
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl);
        } else {
          await Share.share(caption);
        }
      }

      if (!context.mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Berhasil! Caption sudah disalin ke clipboard.'),
              ),
            ],
          ),
          backgroundColor: AppConstants.successGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      // Reset quantity
      setState(() {
        _selectedQuantity = 1;
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppConstants.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null ? AppConstants.primaryBlue : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
