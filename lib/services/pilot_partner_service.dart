import 'package:been/models/pilot_partner_offer.dart';

class PilotPartnerService {
  static const List<PilotPartnerOffer> offers = [
    PilotPartnerOffer(
      id: 'sample-old-town-coffee',
      partnerName: 'Sample Old Town Coffee',
      partnerCategory: 'Coffee shop',
      partnerAddress: 'Old Town pilot area, Bucharest',
      partnerUrl:
          'https://www.google.com/maps/search/coffee+old+town+bucharest',
      rewardTitle: 'Free cookie with any coffee',
      offerDescription:
          'A small purchase-attached treat designed for a coffee partner near the Old Town route.',
      purchaseCondition: 'Valid with any paid coffee or tea order.',
      staffInstruction:
          'Check that the QR says TODAY, then write the proof ID on the daily sheet.',
      dailyLimit: 20,
      spotIds: ['8', '10', '11'],
    ),
    PilotPartnerOffer(
      id: 'sample-victoriei-bistro',
      partnerName: 'Sample Victoriei Bistro',
      partnerCategory: 'Bistro',
      partnerAddress: 'Victoriei pilot area, Bucharest',
      partnerUrl:
          'https://www.google.com/maps/search/bistro+victoriei+bucharest',
      rewardTitle: 'Free lemonade upgrade',
      offerDescription:
          'A low-cost upgrade that fits lunch or coffee traffic around the Victoriei route.',
      purchaseCondition: 'Valid with any sandwich, brunch, or lunch order.',
      staffInstruction:
          'Ask the user to show the QR and proof ID before applying the upgrade.',
      dailyLimit: 15,
      spotIds: ['5', '12'],
    ),
    PilotPartnerOffer(
      id: 'sample-park-kiosk',
      partnerName: 'Sample Park Kiosk',
      partnerCategory: 'Park kiosk',
      partnerAddress: 'North park pilot area, Bucharest',
      partnerUrl: 'https://www.google.com/maps/search/cafe+herastrau+bucharest',
      rewardTitle: 'Free syrup or size upgrade',
      offerDescription:
          'A simple park-friendly extra for users who capture a nearby green or landmark spot.',
      purchaseCondition: 'Valid with any paid drink.',
      staffInstruction:
          'Confirm same-day validity and mark the proof ID as used on the staff list.',
      dailyLimit: 25,
      spotIds: ['4', '6', '14'],
    ),
    PilotPartnerOffer(
      id: 'sample-museum-shop',
      partnerName: 'Sample Museum Shop',
      partnerCategory: 'Museum shop',
      partnerAddress: 'Central culture pilot area, Bucharest',
      partnerUrl: 'https://www.google.com/maps/search/museum+shop+bucharest',
      rewardTitle: 'Free postcard with purchase',
      offerDescription:
          'A culture-friendly extra that keeps partner cost low and gives the visit a souvenir moment.',
      purchaseCondition: 'Valid with any ticket, book, or gift-shop purchase.',
      staffInstruction:
          'Check QR, proof ID, and same-day date, then add the proof ID to the redemption sheet.',
      dailyLimit: 30,
      spotIds: ['7', '13'],
    ),
    PilotPartnerOffer(
      id: 'sample-street-art-studio',
      partnerName: 'Sample Street Art Studio',
      partnerCategory: 'Creative shop',
      partnerAddress: 'Creative district pilot area, Bucharest',
      partnerUrl: 'https://www.google.com/maps/search/creative+shop+bucharest',
      rewardTitle: '10% off a sticker pack',
      offerDescription:
          'A discovery-led offer for urban, hidden, and street-photo moments.',
      purchaseCondition:
          'Valid with any sticker, print, or small item purchase.',
      staffInstruction:
          'Use the discount only once per proof ID and keep the proof ID for reconciliation.',
      dailyLimit: 10,
      spotIds: ['1', '2', '3', '15'],
    ),
  ];

  static PilotPartnerOffer offerForSpot(String spotId) {
    return offers.firstWhere(
      (offer) => offer.spotIds.contains(spotId),
      orElse: () => offers.first,
    );
  }
}
