import 'dart:math';

import 'package:reach/reach.dart';

import 'algorand_wallet.dart';

const HAND = ['Rock', 'Paper', 'Scissors'];
const OUTCOME = ['Bob wins', 'Draw', 'Alice wins'];

void main() async {
  final wallet = AlgorandWallet(provider: 'MyAlgo');
  final reach = Reach(
    host: '0.0.0.0',
    port: 3000,
    verify: false,
    onSignTransaction: (transaction) async {
      return await wallet.signTransaction(transaction);
    },
  );

  try {
    final provider = await reach.setProvider({});
  } catch (ex) {
    print(ex);
  }

  final aliceAcc = await reach.newTestAccount(balance: 10);
  final bobAcc = await reach.newTestAccount(balance: 10);

  Future format(dynamic currency) async {
    return await reach.rpc('/stdlib/formatCurrency', [currency, 4]);
  }

  Future balance(dynamic account) async {
    final balance = await reach.rpc('/stdlib/balanceOf', [account]);
    return format(balance);
  }

  final beforeAlice = await balance(aliceAcc);
  final beforeBob = await balance(bobAcc);

  final ctcAlice = await reach.deploy(aliceAcc);
  final alice = Player('Alice', reach);
  final bob = Player('Bob', reach);

  await Future.wait(
    [
      /// Alice backend
      reach.rpcInteractive(
        '/backend/Alice',
        [ctcAlice],
        {
          ...alice.toMap(),
          'wager': await reach.rpc('/stdlib/parseCurrency', [5]),
          'deadline': 10,
        },
      ),

      /// Bob backend
      reach.getContractInfo(ctcAlice).then((info) async {
        final ctcBob = await reach.attach(bobAcc, info);
        await reach.rpcInteractive(
          '/backend/Bob',
          [ctcBob],
          {
            ...bob.toMap(),
            'acceptWager': (amt) async {
              print('Bob accepts the wager of ${await format(amt)}');
            }
          },
        );

        return await reach.forgetContract(ctcBob);
      }),
    ],
  );

  final afterAlice = await balance(aliceAcc);
  final afterBob = await balance(bobAcc);

  print('Alice went from $beforeAlice to $afterAlice');
  print('Bob went from $beforeBob to $afterBob');

  await Future.wait([
    reach.forgetAccounts([aliceAcc, bobAcc]),
    reach.forgetContract(ctcAlice),
  ]);
}

class Player {
  final String name;
  final Reach reach;
  final Random _random;

  Player(this.name, this.reach) : _random = Random();

  int getHand() {
    final hand = _random.nextInt(3);
    print('$name played ${HAND[hand]}');
    return hand;
  }

  void informTimeout() {
    print('$name observed a timeout');
  }

  void seeOutcome(bn) async {
    final n = await reach.rpc('/stdlib/bigNumberToNumber', [bn]);
    final outcome = OUTCOME[n];

    print('$name saw outcome $outcome');
  }

  Map<String, dynamic> toMap() => {
        'stdlib.hasRandom': true,
        'getHand': getHand,
        'seeOutcome': seeOutcome,
        'informTimeout': informTimeout,
      };
}
