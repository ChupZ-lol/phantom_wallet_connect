import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PhantomLogoColor {
  black('assets/images/phantom_logo_black.svg'),
  purple('assets/images/phantom_logo_purple.svg'),
  white('assets/images/phantom_logo_white.svg');

  final String path;
  const PhantomLogoColor(this.path);
}

class PhantomConnectButton extends StatelessWidget {
  final String? walletAddress;
  final bool isLoading;

  final VoidCallback onConnect;
  final VoidCallback? onDisconnect;

  // Button design customization
  final Color backgroundColor;
  final Color? foregroundColor;
  final PhantomLogoColor logoColor;
  final EdgeInsetsGeometry padding;
  final OutlinedBorder? shape;
  final double height;
  final double? width;

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
