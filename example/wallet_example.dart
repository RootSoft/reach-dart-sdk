import 'package:reach/reach.dart';

void main() async {
  //final wallet = AlgorandWallet(provider: 'MyAlgo');
  final reach = Reach(
    host: '0.0.0.0',
    port: 3000,
    verify: false,
  );

  // final x = reach.rpcInteractive(
  //   '/stdlib/setProvider',
  //   [],
  //   {
  //     'algodClient': null,
  //     'indexer': null,
  //     'getDefaultAddress': () =>
  //         'RQM43TQH4CHTOXKPLDWVH4FUZQVOWYHRXATHJSQLF7GN6CFFLC35FLNYHM',
  //     'isIsolatedNetwork': true,
  //     'signAndPostTxns': (txns, opts) async {
  //       print(txns);
  //     },
  //   },
  // );

  final wallet = reach.rpcInteractive(
    '/stdlib/setWalletFallback',
    [],
    {
      'make': () {
        print('make');
        return '';
      },
    },
  );
}
