import 'dart:math';
import 'package:flutter/material.dart';

class PolaroidTile extends StatelessWidget {
  final ImageProvider image;
  final String spotName;
  final String cityCountry;
  final String dateText;
  final VoidCallback onTap;

  const PolaroidTile({
    super.key,
    required this.image,
    required this.spotName,
    required this.cityCountry,
    required this.dateText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final angle =
        (Random(spotName.hashCode).nextDouble() * 4 - 2) * 3.14159 / 180;

    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // photo with white padding (polaroid top/sides)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(
                          Icons.image_not_supported_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // white strip at bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spotName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      cityCountry,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
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