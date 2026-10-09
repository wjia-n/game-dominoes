import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_store.dart';
import '../theme/palette.dart';
import '../theme/physical.dart';

/// Dominoes PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final SettingsStore settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      AudioService.instance.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — the whole club is yours!',
              style: ClubType.bodyText(15)),
          backgroundColor: ClubPalette.walnut,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    AudioService.instance.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: ClubType.bodyText(15)),
        backgroundColor: ClubPalette.walnut,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final store = widget.store;
    return Scaffold(
      backgroundColor: ClubPalette.darkSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ClubPalette.brassBright),
          onPressed: () {
            AudioService.instance.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('DOMINOES PRO', style: ClubType.plaqueTitle(20)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _ComparisonCard(isPro: s.pro),
                const SizedBox(height: 16),
                _BuyCard(settings: s, store: store),
                const SizedBox(height: 16),
                _TipsCard(store: store),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Free vs Pro comparison table — buyers see the big difference.
class _ComparisonCard extends StatelessWidget {
  final bool isPro;
  const _ComparisonCard({required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Complete dominoes game', true, true),
      ('Draw & Block modes, all official rules', true, true),
      ('Easy bot & pass-and-play', true, true),
      ('Renameable players', true, true),
      ('Music & sound effects', true, true),
      ('Club table themes', '4', '12'),
      ('Tile styles', '4', '10'),
      ('Table accents', '4', '6'),
      ('Hard bot (lookahead strategy)', false, true),
      ('Custom theme creator', false, true),
      ('Exclusive Pro felt & wood finishes', false, true),
    ];
    return ClubPanel(
      child: Column(
        children: [
          Text('FREE vs PRO', style: ClubType.headline(20)),
          const SizedBox(height: 4),
          Text(
            'One purchase. Yours forever.',
            style: ClubType.bodyText(13, color: ClubPalette.parchment),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(
                  flex: 2,
                  child: Text('FREE',
                      style: ClubType.label(12,
                          color: ClubPalette.brassBright),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('PRO',
                      style: ClubType.label(12,
                          color: ClubPalette.brassBright),
                      textAlign: TextAlign.center)),
            ],
          ),
          const Divider(height: 14, color: ClubPalette.brassDark),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(r.$1,
                        style: ClubType.bodyText(13)),
                  ),
                  Expanded(flex: 2, child: _Cell(value: r.$2)),
                  Expanded(flex: 2, child: _Cell(value: r.$3)),
                ],
              ),
            ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: ClubPalette.brass.withValues(alpha: 0.25),
                  border: Border.all(color: ClubPalette.brassBright),
                ),
                child: Text('✦ PRO ACTIVE ✦',
                    style: ClubType.label(14,
                        color: ClubPalette.brassBright)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final Object value; // bool | String
  const _Cell({required this.value});

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      final v = value as bool;
      return Text(
        v ? '✓' : '—',
        style: ClubType.bodyText(15,
            color: v
                ? ClubPalette.brassBright
                : ClubPalette.parchment.withValues(alpha: 0.4)),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      value as String,
      style: ClubType.label(12, color: ClubPalette.brassPale),
      textAlign: TextAlign.center,
    );
  }
}

class _BuyCard extends StatelessWidget {
  final SettingsStore settings;
  final StoreService store;
  const _BuyCard({required this.settings, required this.store});

  @override
  Widget build(BuildContext context) {
    final pro = store.proProduct;
    return ListenableBuilder(
      listenable: Listenable.merge(
          [store.purchaseInProgress, store.purchaseError]),
      builder: (_, _) => ClubPanel(
        child: Column(
          children: [
            Text('Unlock PRO', style: ClubType.headline(20)),
            const SizedBox(height: 8),
            if (settings.pro)
              Text('You already own PRO — thank you!',
                  style: ClubType.bodyText(14),
                  textAlign: TextAlign.center)
            else if (!store.storeReady)
              Text(
                store.error ?? 'Available after store setup',
                style:
                    ClubType.bodyText(14, color: ClubPalette.parchment),
                textAlign: TextAlign.center,
              )
            else if (pro != null) ...[
              Text('All 12 table themes · 10 tile styles · Hard bot · '
                  'custom theme creator · exclusive finishes.',
                  style: ClubType.bodyText(13.5,
                      color: ClubPalette.parchment),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              BrassButton(
                label: 'Unlock PRO — ${pro.price}',
                onTap: () {
                  AudioService.instance.click();
                  store.buyPro();
                },
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  AudioService.instance.click();
                  store.restore();
                },
                child: Text('Restore purchase',
                    style: ClubType.label(13,
                            color: ClubPalette.brassBright)
                        .copyWith(
                            decoration: TextDecoration.underline)),
              ),
            ],
            if (store.purchaseInProgress.value)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Contacting the store…',
                    style: ClubType.bodyText(13,
                        color: ClubPalette.parchment)),
              ),
            if (store.purchaseError.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(store.purchaseError.value!,
                    style: ClubType.bodyText(13,
                        color: const Color(0xFFE08A7A))),
              ),
          ],
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final StoreService store;
  const _TipsCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return ClubPanel(
      child: Column(
        children: [
          Text('Tip the house', style: ClubType.headline(20)),
          const SizedBox(height: 6),
          Text(
            'Dominoes is free forever. A tip keeps the tungsten lit '
            'and the coffee coming — it never changes gameplay.',
            style:
                ClubType.bodyText(13.5, color: ClubPalette.parchment),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup',
              style:
                  ClubType.bodyText(14, color: ClubPalette.parchment),
              textAlign: TextAlign.center,
            )
          else
            Row(
              children: [
                Expanded(
                    child: _TipButton(
                        product: store.coffeeProduct,
                        icon: '☕',
                        onBuy: store.buyTip)),
                const SizedBox(width: 10),
                Expanded(
                    child: _TipButton(
                        product: store.chocolateProduct,
                        icon: '🍫',
                        onBuy: store.buyTip)),
              ],
            ),
        ],
      ),
    );
  }
}

class _TipButton extends StatelessWidget {
  final ProductDetails? product;
  final String icon;
  final void Function(ProductDetails) onBuy;
  const _TipButton(
      {required this.product, required this.icon, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return BrassButton(
      label: p == null ? '$icon Tip' : '$icon ${p.title} — ${p.price}',
      compact: true,
      onTap: p == null
          ? null
          : () {
              AudioService.instance.click();
              onBuy(p);
            },
    );
  }
}
