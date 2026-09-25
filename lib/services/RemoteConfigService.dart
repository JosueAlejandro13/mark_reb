import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(seconds: 10),
      ),
    );
    await remoteConfig.fetchAndActivate();
  }

  String get dbHost => remoteConfig.getString('DB_HOST');
  String get dbName => remoteConfig.getString('DB_NAME');
  String get dbPassword => remoteConfig.getString('DB_PASSWORD');
  String get dbPort => remoteConfig.getString('DB_PORT');
  String get dbTimeout => remoteConfig.getString('DB_TIMEOUT');
  String get dbUser => remoteConfig.getString('DB_USER').isNotEmpty
      ? remoteConfig.getString('DB_USER')
      : 'root';
}
