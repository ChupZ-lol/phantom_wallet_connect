import 'dart:convert';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart';

SolanaClient _solanaClient = SolanaClient(
  rpcUrl: Uri.parse('https://api.devnet.solana.com'),
  websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
);

//=========================================================
// Work with transactions must be done on the server side
//=========================================================

class Server {
  // Creating an unsigned transaction (USER PAYS FEE)
  // Returns Base64 for transmission between server and client
  Future<String> createUnsignedTx(
    String userPublicKey,
    double amount,
    String toWallet,
  ) async {
    try {
      final senderWallet = Ed25519HDPublicKey.fromBase58(userPublicKey);
      final int amountLamports = (amount * lamportsPerSol).round();

      final instruction = SystemInstruction.transfer(
        fundingAccount: senderWallet,
        recipientAccount: Ed25519HDPublicKey.fromBase58(toWallet),
        lamports: amountLamports,
      );

      final message = Message(instructions: [instruction]);
      final blockhash = await _solanaClient.rpcClient.getLatestBlockhash();

      final compiledMessage = message.compile(
        recentBlockhash: blockhash.value.blockhash,
        feePayer: senderWallet,
      );

      print('Unsigned transaction created!');
      return base64Encode(compiledMessage.toByteArray().toList());
    } catch (e) {
      print("Error createUnsignedTx: $e");
      rethrow;
    }
  }

  // Creating an Multiple unsigned transactions
  Future<List<String>> createMultipleUnsignedTxs(
    String senderPublicKey,
    List<String> recipients,
    List<double> amounts,
  ) async {
    try {
      if (recipients.length != amounts.length) {
        throw Exception(
          "Mismatch: Recipients count (${recipients.length}) != Amounts count (${amounts.length})",
        );
      }

      final senderWallet = Ed25519HDPublicKey.fromBase58(senderPublicKey);
      final blockhash = await _solanaClient.rpcClient.getLatestBlockhash();
      List<String> txs = [];

      for (int i = 0; i < recipients.length; i++) {
        final recipientAddr = recipients[i];
        final amountSol = amounts[i];

        final int amountLamports = (amountSol * lamportsPerSol).round();

        final transferIx = SystemInstruction.transfer(
          fundingAccount: senderWallet,
          recipientAccount: Ed25519HDPublicKey.fromBase58(recipientAddr),
          lamports: amountLamports,
        );

        final message = Message(instructions: [transferIx]);

        final compiledMessage = message.compile(
          recentBlockhash: blockhash.value.blockhash,
          feePayer: senderWallet,
        );

        txs.add(base64Encode(compiledMessage.toByteArray().toList()));
      }

      print('Multiple of ${recipients.length} transactions created!');
      return txs;
    } catch (e) {
      print("Error createMultipleUnsignedTxs: $e");
      rethrow;
    }
  }

  // Receiving and sending a signed transaction
  // Accepts Base64 of a signed transaction, returns Signature
  Future<String> sendTx(String signedTx) async {
    try {
      final signature = await _solanaClient.rpcClient.sendTransaction(
        signedTx,
        preflightCommitment: Commitment.confirmed,
      );

      print('transaction send!');
      return signature;
    } catch (e) {
      print("Error sending tx: $e");
      rethrow;
    }
  }

  // Receiving and sending a Multiple signed transactions
  Future<List<String>> sendMultipleTxs(List<String> signedTxs) async {
    final futures = signedTxs.map((txBase64) async {
      try {
        final sig = await _solanaClient.rpcClient.sendTransaction(
          txBase64,
          preflightCommitment: Commitment.confirmed,
        );
        print("Sent: $sig");
        return sig;
      } catch (e) {
        print("Error sending specific tx: $e");
        return "Error";
      }
    });

    final signatures = await Future.wait(futures);
    print('All transactions send!');
    return signatures;
  }

  //=========================================================
  // Validity window (e.g. 3 minutes = 180 000 ms)
  static const int _validityWindow = 180000;

  // Signature verification. Does the user own the declared publicKey?
  Future<bool> verifySign(
    String publicKey,
    String signatureBase58,
    int timestamp,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Checking that the timestamp is not too old and not from the distant future
    if (timestamp > now + 5000 || timestamp < now - _validityWindow) {
      throw Exception("Login request expired. Please try again.");
    }

    final message = "Sign in to MyApp: $timestamp";

    try {
      final List<int> messageBytes = message.codeUnits;
      final List<int> signatureBytes = base58decode(signatureBase58);

      bool isValid = await verifySignature(
        message: messageBytes,
        signature: signatureBytes,
        publicKey: Ed25519HDPublicKey.fromBase58(publicKey),
      );

      if (isValid) {
        // Login successful!
        // Here you can issue an AuthToken or create a session
        print('Sign isValid: $isValid');
        return true;
      }
      print('Sign isValid: $isValid');
      return false;
    } catch (e) {
      print('Sign Message ERROR: $e');
      return false;
    }
  }
}
