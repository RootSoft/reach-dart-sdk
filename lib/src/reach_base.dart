import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';

typedef OnSignTransaction = Future<Uint8List> Function(Uint8List transaction);

/// Reach is a domain-specific language for building decentralized applications.
///
/// The Reach RPC Server provides access to compiled JavaScript backends via an
/// HTTPS-accessible JSON-based RPC protocol.
///
/// A single Reach program incorporates all aspects of a DApp:
/// * Participant backends are the agents acting on behalf of the principals.
/// * Frontends are the technical representation of the interface between the
/// participants and the principals.
/// * A contract enforces the rules of the program, including the order of
/// operation.
///
/// Starts a new instance of the Reach RPC Server using:
/// $ reach rpc-server
///
/// More information:
/// https://docs.reach.sh/ref-backends-rpc.html
class Reach {
  final Dio _dio;
  final OnSignTransaction? onSignTransaction;

  Reach.dio({
    required Dio dio,
    this.onSignTransaction,
  }) : _dio = dio;

  /// Create a new Reach client.
  ///
  /// * Host is the hostname to contact for the Reach RPC Server instance.
  /// * Port is the TCP port to contact for the Reach RPC Server instance.
  /// * Verify determines whether to verify the TLS certificate of the Reach
  /// RPC Server instance. Defaults to true.
  /// * timeout is the number of seconds to wait for the Reach RPC Server
  /// instance to respond to its first request. Defaults to 5 seconds.n
  /// * key is the API key for the Reach RPC Server instance.
  factory Reach({
    required String host,
    int port = 3000,
    bool verify = true,
    int timeout = 5,
    String key = 'opensesame',
    bool debug = false,
    OnSignTransaction? onSignTransaction,
  }) {
    final options = BaseOptions(
      baseUrl: _formatBaseUrl(host, port),
      connectTimeout: Duration(seconds: timeout).inMilliseconds,
      receiveTimeout: Duration(seconds: timeout).inMilliseconds,
      headers: {
        'X-API-Key': key,
        'Content-Type': 'application/json; charset=utf-8',
      },
    );

    final dio = Dio(options);

    // TLS validation
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (HttpClient client) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => !verify;
      return client;
    };

    if (!verify) {
      //print();
    }

    if (debug) {
      dio.interceptors.add(LogInterceptor());
    }

    return Reach.dio(
      dio: dio,
      onSignTransaction: onSignTransaction,
    );
  }

  /// Invoke a synchronous value RPC method.
  /// It takes a string, naming the RPC method, and some JSON values to provide
  /// as arguments. It returns a Future of a single JSON value as the result.
  Future rpc(String method, [List? arguments = const []]) {
    final c = Completer();
    _dio
        .post(_formatMethod(method), data: json.encode(arguments))
        .then((data) => c.complete(data.data))
        .onError(c.completeError);

    return c.future;
  }

  /// Invokes an interactive RPC method, such as for a backend.
  /// It takes a string, naming the RPC method, a JSON value as an argument,
  /// and dictionary from strings to JSON values or async functions.
  ///
  /// The functions will be provided as interactive RPC callbacks to the RPC
  /// method and should expect JSON values as arguments and return a Future of
  /// a JSON value as a result.
  /// It returns a Future that does not contain a value.
  Future rpcInteractive(
    String method,
    List arguments,
    Map<String, dynamic> callbacks,
  ) async {
    final values = {};
    final methods = {};
    final c = Completer();

    callbacks.forEach((key, value) {
      final v = callbacks[key];
      if (v is Function) {
        methods[key] = true;
      } else {
        values[key] = v;
      }
    });

    var p = rpc(method, [...arguments, values, methods]);

    unawaited(Future.doWhile(() async {
      try {
        final r = await p;
        print(r);
        switch (r['t']) {
          case 'Done':
            c.complete(r['ans']);
            return false;

          case 'Kont':
            final m = r['m'];
            final kid = r['kid'];
            final args = r['args'] as List;
            final ans = await Function.apply(callbacks[m], args);

            p = rpc('/kont', [kid, ans]);
            break;
          default:
            throw Exception('Illegal callback return');
        }
      } catch (e) {
        c.completeError(e);
        return false;
      }

      return true;
    }));

    return c.future;
  }

  /// Returns true to indicate the server is running properly.
  Future<bool> health() async {
    final health = await rpc('/health');
    return health is bool ? health : false;
  }

  Future setProvider(Map<String, dynamic> provider) async {
    final x = rpcInteractive(
      '/stdlib/setProvider',
      [],
      {
        'algodClient': null,
        'indexer': null,
        'getDefaultAddress': () =>
            'RQM43TQH4CHTOXKPLDWVH4FUZQVOWYHRXATHJSQLF7GN6CFFLC35FLNYHM',
        'isIsolatedNetwork': true,
        'signAndPostTxns': (txns, opts) async {
          print(txns);
        },
      },
    );
  }

  /// Returns a Future for a Reach account abstraction for a new account on the
  /// consensus network with a given balance of network tokens.
  /// This can only be used in private testing scenarios, as it uses a private
  /// faucet to issue network tokens.
  Future<String> newTestAccount({int balance = 10}) async {
    final startingBalance = await rpc('/stdlib/parseCurrency', [balance]);
    return await rpc('/stdlib/newTestAccount', [startingBalance]);
  }

  /// Construct a contract handle from an account.
  /// Returns a Reach contract handle with access to the account.
  Future<String> deploy(String account) async {
    final ctc = await rpc('/acc/deploy', [account]);
    return ctc;
  }

  /// Construct a contract handle from an account.
  /// Typically, the deployer of a contract will not provide info, while users
  /// of a contract will.
  /// Returns a Reach contract handle with access to the account.
  Future<String> attach(String account, String contract) async {
    final ctc = await rpc('/acc/attach', [account, contract]);
    return ctc;
  }

  /// Returns a Future for the balance of network tokens
  /// (or non-network tokens if token is provided) held by the account given by
  /// a Reach account abstraction provided by the acc argument.
  Future balanceOf(String account) async {
    return await rpc('/stdlib/balanceOf', [account]);
  }

  /// Returns a Promise for a Contract value that may be given to contract to
  /// construct a Reach contract handle for this contract.
  Future getContractInfo(String ctcHandle) async {
    return await rpc('/ctc/getInfo', [ctcHandle]);
  }

  /// Accepts an account RPC handle and deletes it from the Reach RPC Server’s
  /// memory.
  Future forgetAccount(String account) async {
    return await rpc('/forget/acc', [account]);
  }

  /// Accepts a list of account RPC handles and deletes them from the Reach
  /// RPC Server’s memory.
  Future forgetAccounts(List<String> accounts) async {
    return await rpc('/forget/acc', accounts);
  }

  /// Accepts a contract RPC handle and deletes it from the Reach RPC Server’s
  /// memory.
  Future forgetContract(String ctcHandle) async {
    return await rpc('/forget/ctc', [ctcHandle]);
  }

  /// Format the method
  String _formatMethod(String method) {
    method = !method.startsWith('/') ? '/$method' : method;

    return method.trim();
  }
}

/// Format the base url
String _formatBaseUrl(String host, int? port) {
  host = !host.startsWith('http://') && !host.startsWith('https://')
      ? 'https://$host'
      : host;
  return '$host:$port';
}
