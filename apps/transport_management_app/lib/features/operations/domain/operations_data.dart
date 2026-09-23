import '../../clients/domain/client_models.dart';
import '../../fleet/domain/fleet_models.dart';
import '../../trips/domain/trip_models.dart';

final class OperationsData {
  const OperationsData({
    required this.clients,
    required this.trucks,
    required this.drivers,
    required this.trips,
  });
  final List<Client> clients;
  final List<Truck> trucks;
  final List<Driver> drivers;
  final List<Trip> trips;
}
