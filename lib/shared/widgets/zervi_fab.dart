import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class ZerviFAB extends StatefulWidget {
  final VoidCallback? onPublishService;
  final VoidCallback? onPublishJob;

  const ZerviFAB({
    super.key,
    this.onPublishService,
    this.onPublishJob,
  });

  @override
  State<ZerviFAB> createState() => _ZerviFABState();
}

class _ZerviFABState extends State<ZerviFAB> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          _buildOption(
            icon: Icons.add_business_outlined,
            label: 'Ofrecer Servicio',
            onTap: () {
              _toggle();
              widget.onPublishService?.call();
            },
          ),
          const SizedBox(height: 12),
          _buildOption(
            icon: Icons.post_add_outlined,
            label: 'Publicar Trabajo',
            onTap: () {
              _toggle();
              widget.onPublishJob?.call();
            },
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton.large(
          onPressed: _toggle,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _controller,
          ),
        ),
      ],
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return FadeScaleTransition(
      animation: _controller,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: label,
            onPressed: onTap,
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            child: Icon(icon),
          ),
        ],
      ),
    );
  }
}
