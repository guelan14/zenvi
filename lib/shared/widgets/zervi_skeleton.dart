import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zenvi/shared/widgets/zervi_card.dart';

class ZerviSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const ZerviSkeleton.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8.0,
  }) : shape = BoxShape.rectangle;

  const ZerviSkeleton.circular({
    super.key,
    required this.width,
    required this.height,
  }) : shape = BoxShape.circle,
        borderRadius = 0.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E222B) : const Color(0xFFE5E7EB);
    final highlight = isDark ? const Color(0xFF2E333F) : const Color(0xFFF3F4F6);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
        ),
      ),
    );
  }
}

class ZerviListingSkeleton extends StatelessWidget {
  const ZerviListingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ZerviCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ZerviSkeleton.circular(width: 36, height: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ZerviSkeleton.rectangular(width: 60, height: 8),
                    const SizedBox(height: 6),
                    const ZerviSkeleton.rectangular(width: 150, height: 14),
                  ],
                ),
              ),
              const ZerviSkeleton.rectangular(width: 50, height: 16),
            ],
          ),
          const SizedBox(height: 12),
          const ZerviSkeleton.rectangular(width: double.infinity, height: 12),
          const SizedBox(height: 6),
          const ZerviSkeleton.rectangular(width: 200, height: 12),
          const SizedBox(height: 16),
          const ZerviSkeleton.rectangular(width: double.infinity, height: 140, borderRadius: 12),
          const SizedBox(height: 12),
          const Row(
            children: [
              ZerviSkeleton.circular(width: 12, height: 12),
              SizedBox(width: 6),
              ZerviSkeleton.rectangular(width: 80, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class ZerviCategorySkeleton extends StatelessWidget {
  const ZerviCategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 8),
      child: ZerviSkeleton.rectangular(
        width: 100,
        height: 32,
        borderRadius: 20,
      ),
    );
  }
}

class ZerviProfileListingSkeleton extends StatelessWidget {
  const ZerviProfileListingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ZerviCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const ZerviSkeleton.rectangular(width: 60, height: 60, borderRadius: 8),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ZerviSkeleton.rectangular(width: 120, height: 14),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const ZerviSkeleton.rectangular(width: 50, height: 12, borderRadius: 6),
                    const SizedBox(width: 8),
                    const ZerviSkeleton.circular(width: 10, height: 10),
                    const SizedBox(width: 4),
                    const ZerviSkeleton.rectangular(width: 60, height: 10),
                  ],
                ),
              ],
            ),
          ),
          const ZerviSkeleton.rectangular(width: 40, height: 16),
        ],
      ),
    );
  }
}

class ZerviListingDetailSkeleton extends StatelessWidget {
  const ZerviListingDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ZerviSkeleton.rectangular(width: double.infinity, height: 250, borderRadius: 0),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ZerviSkeleton.rectangular(width: 70, height: 18, borderRadius: 6),
                      const SizedBox(width: 8),
                      const ZerviSkeleton.rectangular(width: 90, height: 18, borderRadius: 6),
                      const SizedBox(width: 8),
                      const ZerviSkeleton.rectangular(width: 80, height: 18, borderRadius: 6),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const ZerviSkeleton.rectangular(width: double.infinity, height: 28, borderRadius: 8),
                  const SizedBox(height: 8),
                  const ZerviSkeleton.rectangular(width: 200, height: 28, borderRadius: 8),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const ZerviSkeleton.circular(width: 16, height: 16),
                      const SizedBox(width: 8),
                      const ZerviSkeleton.rectangular(width: 150, height: 14),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const ZerviSkeleton.rectangular(width: 100, height: 24),
                  const SizedBox(height: 32),
                  const ZerviSkeleton.rectangular(width: 120, height: 18),
                  const SizedBox(height: 12),
                  const ZerviSkeleton.rectangular(width: double.infinity, height: 12),
                  const SizedBox(height: 8),
                  const ZerviSkeleton.rectangular(width: double.infinity, height: 12),
                  const SizedBox(height: 8),
                  const ZerviSkeleton.rectangular(width: 250, height: 12),
                  const SizedBox(height: 32),
                  const ZerviSkeleton.rectangular(width: 140, height: 18),
                  const SizedBox(height: 12),
                  const ZerviSkeleton.rectangular(width: double.infinity, height: 60, borderRadius: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ZerviAgendaEventSkeleton extends StatelessWidget {
  const ZerviAgendaEventSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          const ZerviSkeleton.circular(width: 44, height: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ZerviSkeleton.rectangular(width: 150, height: 16),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const ZerviSkeleton.circular(width: 12, height: 12),
                    const SizedBox(width: 4),
                    const ZerviSkeleton.rectangular(width: 60, height: 10),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const ZerviSkeleton.circular(width: 12, height: 12),
                    const SizedBox(width: 4),
                    const ZerviSkeleton.rectangular(width: 80, height: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ZerviAgendaSkeleton extends StatelessWidget {
  const ZerviAgendaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ZerviSkeleton.circular(width: 24, height: 24),
                    const ZerviSkeleton.rectangular(width: 100, height: 18),
                    const ZerviSkeleton.circular(width: 24, height: 24),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    7,
                    (index) => const ZerviSkeleton.rectangular(width: 30, height: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    7,
                    (index) => const ZerviSkeleton.circular(width: 28, height: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    7,
                    (index) => const ZerviSkeleton.circular(width: 28, height: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: ZerviSkeleton.rectangular(width: 150, height: 12, borderRadius: 6),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 2,
            itemBuilder: (context, index) => const ZerviAgendaEventSkeleton(),
          ),
        ),
      ],
    );
  }
}

class ZerviListingCardSkeleton extends StatelessWidget {
  const ZerviListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ZerviCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const ZerviSkeleton.rectangular(width: 50, height: 50, borderRadius: 8),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ZerviSkeleton.rectangular(width: 120, height: 14),
                const SizedBox(height: 8),
                const ZerviSkeleton.rectangular(width: 80, height: 10),
              ],
            ),
          ),
          const ZerviSkeleton.rectangular(width: 40, height: 16),
        ],
      ),
    );
  }
}

class ZerviContactCardSkeleton extends StatelessWidget {
  const ZerviContactCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ZerviCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const ZerviSkeleton.circular(width: 48, height: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ZerviSkeleton.rectangular(width: 100, height: 14),
                const SizedBox(height: 8),
                const ZerviSkeleton.rectangular(width: 70, height: 10),
              ],
            ),
          ),
          const ZerviSkeleton.circular(width: 36, height: 36),
          const SizedBox(width: 8),
          const ZerviSkeleton.circular(width: 36, height: 36),
        ],
      ),
    );
  }
}

class ZerviAppointmentDetailSkeleton extends StatelessWidget {
  const ZerviAppointmentDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ZerviSkeleton.rectangular(width: double.infinity, height: 100, borderRadius: 16),
            const SizedBox(height: 20),
            const ZerviSkeleton.rectangular(width: double.infinity, height: 80, borderRadius: 16),
            const SizedBox(height: 20),
            const ZerviListingCardSkeleton(),
            const SizedBox(height: 20),
            const ZerviContactCardSkeleton(),
            const SizedBox(height: 30),
            const ZerviSkeleton.rectangular(width: double.infinity, height: 50, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}
