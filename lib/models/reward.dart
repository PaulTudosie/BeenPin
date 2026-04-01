import 'package:intl/intl.dart';

class Reward {
  final String partnerName;
  final String partnerAddress;
  final String gift;
  final String qrCode;
  final String expiryDate;
  final String partnerUrl;

  const Reward({
    required this.partnerName,
    required this.partnerAddress,
    required this.gift,
    required this.qrCode,
    required this.expiryDate,
    required this.partnerUrl,
  });

  factory Reward.generate(String spotId) {
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
    );
  }
}