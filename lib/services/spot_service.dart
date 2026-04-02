import '../models/spot.dart';

class SpotService {
  static List<Spot> getSpots() {
    return [
      Spot(id: '1', name: 'Hidden Graffiti', lat: 44.4325, lng: 26.1039, type: 'graffiti'),
      Spot(id: '2', name: 'Abandoned Factory', lat: 44.4300, lng: 26.1065, type: 'urban'),
      Spot(id: '3', name: 'Old Staircase', lat: 44.4352, lng: 26.0987, type: 'architecture'),
      Spot(id: '4', name: 'Arcul de Triumf', lat: 44.467, lng: 26.0781, type: 'monument'),
      Spot(id: '5', name: 'Ateneul Român', lat: 44.4413, lng: 26.0966, type: 'culture'),
      Spot(id: '6', name: 'Parcul Herăstrău', lat: 44.4663, lng: 26.0858, type: 'nature'),
      Spot(id: '7', name: 'Palatul Parlamentului', lat: 44.4273, lng: 26.0873, type: 'monument'),
      Spot(id: '8', name: 'Hanul lui Manuc', lat: 44.4318, lng: 26.1030, type: 'history'),
      Spot(id: '9', name: 'Cișmigiu Garden', lat: 44.4370, lng: 26.0915, type: 'nature'),
      Spot(id: '10', name: 'Piața Unirii', lat: 44.4268, lng: 26.1025, type: 'urban'),
      Spot(id: '11', name: 'Curtea Veche', lat: 44.4318, lng: 26.1048, type: 'history'),
      Spot(id: '12', name: 'Piața Victoriei', lat: 44.4521, lng: 26.0857, type: 'urban'),
      Spot(id: '13', name: 'Therme București', lat: 44.5773, lng: 26.0685, type: 'leisure'),
      Spot(id: '14', name: 'Floreasca Park', lat: 44.4663, lng: 26.1018, type: 'nature'),
      Spot(id: '15', name: 'Obor Market', lat: 44.4512, lng: 26.1153, type: 'urban'),
    ];
  }
}