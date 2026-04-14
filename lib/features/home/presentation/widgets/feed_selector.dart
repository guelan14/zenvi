import 'package:flutter/material.dart';
import 'package:zenvi/features/home/domain/models/listing.dart';

class FeedSelector extends StatelessWidget {
  final ListingType selectedType;
  final ValueChanged<ListingType> onTypeChanged;

  const FeedSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            'Servicios',
            ListingType.service,
            selectedType == ListingType.service,
          ),
          _buildButton(
            'Trabajos',
            ListingType.job,
            selectedType == ListingType.job,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, ListingType type, bool isSelected) {
    return GestureDetector(
      onTap: () => onTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  )
                ]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.black54,
          ),
        ),
      ),
    );
  }
}
