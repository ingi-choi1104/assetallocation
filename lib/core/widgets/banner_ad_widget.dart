import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const _adUnitId = 'ca-app-pub-6235846592723695/4324631345';

/// Loads and displays an AdMob banner ad.
/// Renders nothing until the ad is loaded (no layout shift).
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always reserve the banner height so the layout doesn't shift.
    // AdSize.banner is 320×50 dp (standard).
    return SizedBox(
      width: double.infinity,
      height: AdSize.banner.height.toDouble(),
      child: (_loaded && _ad != null)
          ? AdWidget(ad: _ad!)
          : const SizedBox.shrink(),
    );
  }
}
