enum Cluster {
  mainnetBeta('mainnet-beta'),
  testnet('testnet'),
  devnet('devnet');

  final String value;
  const Cluster(this.value);
}
