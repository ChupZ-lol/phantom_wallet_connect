import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Phantom logo color options for the connect button.
enum PhantomLogoColor {
  /// Black logo
  black('assets/images/phantom_logo_black.svg'),

  /// Purple logo
  purple('assets/images/phantom_logo_purple.svg'),

  /// White logo
  white('assets/images/phantom_logo_white.svg');

  /// Path to the logo SVG file in the package assets.
  final String path;
  const PhantomLogoColor(this.path);
}

/// Ready-made UI button component for connecting the Phantom wallet.
/// The widget automatically changes its state (Connected/Disconnected)
/// and displays the abbreviated wallet address, if provided.
class PhantomConnectButton extends StatelessWidget {
  /// Текущий адрес подключенного кошелька.
  /// Если `null`, кнопка отображает состояние "Connect".
  final String? walletAddress;

  /// Displays a loading indicator if `true`.
  final bool isLoading;

  /// Function called when Connect is clicked
  final VoidCallback onConnect;

  /// Function called when the wallet is disconnected.
  final VoidCallback? onDisconnect;

  /// Button design customization
  /// The button's primary background color. Defaults to the brand purple.
  final Color backgroundColor;

  /// The color of the text and loading icon on the button.
  /// If not specified, it is calculated automatically based on [backgroundColor].
  final Color? foregroundColor;

  /// Phantom logo color. Defaults to [PhantomLogoColor.white].
  final PhantomLogoColor logoColor;

  /// Button padding.
  final EdgeInsetsGeometry padding;

  /// Button shape (borders, rounding).
  final OutlinedBorder? shape;

  /// Button height. Default is 42.0.
  final double height;

  /// Button width. If `null`, the button takes up the minimum necessary space.
  final double? width;

  /// Creates a Phantom connect button with extensive customization options.
  const PhantomConnectButton({
    super.key,
    required this.onConnect,
    this.onDisconnect,
    this.walletAddress,
    this.isLoading = false,

    // Parameters with default values
    this.backgroundColor = const Color(0xFFAB9FF2),
    this.logoColor = PhantomLogoColor.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    this.height = 42.0,
    this.width,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = walletAddress != null;

    final effectiveTextColor =
        foregroundColor ??
        (backgroundColor == const Color(0xFFAB9FF2)
            ? Colors.black
            : Colors.white);

    return SizedBox(
      height: height,
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: effectiveTextColor,
          padding: padding,
          shape: shape,
          elevation: 0,
        ),
        onPressed: isLoading ? null : (isConnected ? onDisconnect : onConnect),
        child: _buildContent(isConnected, effectiveTextColor),
      ),
    );
  }

  Widget _buildContent(bool isConnected, Color textColor) {
    if (isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isConnected) ...[
          SvgPicture.asset(
            logoColor.path,
            package: 'phantom_wallet_connect',
            height: 24,
            width: 24,
          ),
          const SizedBox(width: 12),
        ],

        Text(
          isConnected ? _formatWalletAddress(walletAddress!) : 'Connect',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

//===================================================================
// A function to display the user's wallet on a button after authorization. Example: AKiB...ox1s
String _formatWalletAddress(String publicKey) {
  if (publicKey.length <= 8) {
    return publicKey;
  }
  return '${publicKey.substring(0, 4)}...${publicKey.substring(publicKey.length - 4)}';
}
