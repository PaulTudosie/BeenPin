import 'package:intl/intl.dart';

class Reward {
  final String partnerName;
  final String partnerAddress;
  final String gift;
  final String qrCode;
  final String expiryDate;
  final String partnerUrl;

  final String partnerCategory;
  final String offerDescription;
  final String unlockedFromSpot;

  const Reward({
    required this.partnerName,
    required this.partnerAddress,
    required this.gift,
    required this.qrCode,
    required this.expiryDate,
    required this.partnerUrl,
    required this.partnerCategory,
    required this.offerDescription,
    required this.unlockedFromSpot,
  });

  factory Reward.generate(String spotId, {String? spotName}) {
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final displayDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    final random = (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();

    return Reward(
      partnerName: 'Café Central',
      partnerAddress: 'Strada Lipscani 15, București',
      gift: 'One complimentary espresso',
      qrCode: 'BEEN-$spotId-$today-$random',
      expiryDate: displayDate,
      partnerUrl: 'https://www.google.com',
      partnerCategory: 'Café',
      offerDescription: 'Available with any breakfast or brunch order.',
      unlockedFromSpot: spotName ?? 'this spot',
    );
  }
}