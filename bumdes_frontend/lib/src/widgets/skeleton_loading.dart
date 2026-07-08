import 'package:flutter/material.dart';

/// Kotak abu-abu dengan animasi "shimmer" (berkilau) buat placeholder
/// loading — lebih modern dibanding spinner polos, dan kasih gambaran
/// bentuk konten yang akan muncul (skeleton screen).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.grey[300],
              Colors.grey[100],
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton khusus bentuk kartu produk — dipakai menggantikan
/// CircularProgressIndicator polos saat daftar produk masih dimuat.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.width = 220});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SkeletonBox(width: width, height: width * 0.75, borderRadius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 14),
                const SizedBox(height: 8),
                SkeletonBox(width: width * 0.5, height: 12),
                const SizedBox(height: 12),
                SkeletonBox(width: width * 0.4, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris horizontal skeleton produk — buat bagian "Produk Unggulan".
class ProductRowSkeleton extends StatelessWidget {
  const ProductRowSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: count,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(right: 16),
          child: ProductCardSkeleton(),
        ),
      ),
    );
  }
}