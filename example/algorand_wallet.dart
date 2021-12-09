import 'dart:typed_data';

class AlgorandWallet {
  final String provider;

  AlgorandWallet({required this.provider});

  Future<Uint8List> signTransaction(Uint8List transaction) async {
    return Future.value(Uint8List.fromList([]));
  }
}
