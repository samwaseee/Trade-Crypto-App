import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Services/market_repository.dart';

class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = 8,
  });

  final double height;
  final double width;
  final double borderRadius;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + (_controller.value * 2), 0),
            end: Alignment(_controller.value * 2, 0),
            colors: [
              base,
              base.withValues(alpha: 0.55),
              base,
            ],
          ),
        ),
        child: SizedBox(width: widget.width, height: widget.height),
      ),
    );
  }
}

class CoinListSkeleton extends StatelessWidget {
  const CoinListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var index = 0; index < count; index++) ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    SkeletonShimmer(width: 44, height: 44, borderRadius: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonShimmer(width: 132),
                          SizedBox(height: 8),
                          SkeletonShimmer(width: 88, height: 12),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    SkeletonShimmer(width: 56, height: 28),
                  ],
                ),
              ),
            ),
            if (index < count - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class PortfolioHeaderSkeleton extends StatelessWidget {
  const PortfolioHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonShimmer(width: 116, height: 14),
              SizedBox(height: 8),
              SkeletonShimmer(width: 180, height: 34),
              SizedBox(height: 10),
              SkeletonShimmer(width: 142, height: 13),
            ],
          ),
        ),
        SizedBox(width: 16),
        SkeletonShimmer(width: 52, height: 52, borderRadius: 26),
      ],
    );
  }
}

class NewsListSkeleton extends StatelessWidget {
  const NewsListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              SkeletonShimmer(width: 90, height: 70, borderRadius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonShimmer(height: 16),
                    SizedBox(height: 8),
                    SkeletonShimmer(width: 112, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.error,
    this.message,
    required this.onRetry,
  });

  final Object? error;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = this.message ??
        (error is MarketException
            ? (error! as MarketException).message
            : 'Something went wrong. Please try again.');
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
        if (!constraints.maxHeight.isFinite) return content;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
