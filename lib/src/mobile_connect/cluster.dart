/// Network configuration for operation
enum Cluster {
  /// Mainnet
  mainnetBeta('mainnet-beta'),

  /// Testnet
  testnet('testnet'),

  /// Devnet
  devnet('devnet');

  /// Selected value
  final String value;
  const Cluster(this.value);
}
