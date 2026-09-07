import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/features/partner/partner_scanner_screen.dart';
import 'package:been/services/partner_mode_config.dart';
import 'package:been/services/reward_redemption_service.dart';

/// A single staff route keeps Exit and system Back scoped to Partner Mode.
class PartnerModeScreen extends StatefulWidget {
  final RewardRedemptionService? service;
  const PartnerModeScreen({super.key, this.service});
  @override
  State<PartnerModeScreen> createState() => _PartnerModeScreenState();
}

class _PartnerModeScreenState extends State<PartnerModeScreen> {
  final _pin = TextEditingController();
  late final _service = widget.service ?? LocalRewardRedemptionService();
  final _partners = PartnerModeConfig.partners;
  late String _partnerId = _partners.first.id;
  bool _authorized = false;
  bool _busy = false;
  String? _error;
  String? _qr;
  RewardValidationResult? _result;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _unlock() {
    if (!PartnerModeConfig.acceptsPin(_pin.text)) {
      setState(() => _error = 'Incorrect PIN. Please try again.');
      return;
    }
    FocusScope.of(context).unfocus();
    _pin.clear();
    setState(() {
      _authorized = true;
      _error = null;
    });
  }

  Future<void> _scan() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final qr = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const PartnerScannerScreen()));
    if (!mounted) return;
    if (qr == null) {
      setState(() => _busy = false);
      return;
    }
    _qr = qr;
    await _validate();
  }

  Future<void> _validate({bool redeem = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = redeem
          ? await _service.redeemReward(_qr!, _partnerId)
          : await _service.validateRewardQr(_qr!, _partnerId);
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _result = null;
          _error =
              'Could not check the reward. Please retry before applying the offer.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _button(String label, VoidCallback action) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: SizedBox(
            width: double.infinity,
            child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    minimumSize: const Size.fromHeight(52)),
                onPressed: _busy ? null : action,
                child: Text(label))),
      );

  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(text, style: Theme.of(context).textTheme.headlineSmall));

  Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value),
      ]));

  String _date(DateTime value) =>
      DateFormat('dd MMM yyyy, HH:mm:ss').format(value.toLocal());

  List<Widget> _verification(RewardValidationResult result) {
    final status = result.status;
    final item = result.localReward;
    final payload = result.payload;
    final success = status == RewardValidationStatus.redeemed;
    final valid = status == RewardValidationStatus.validLocal;
    final title = switch (status) {
      RewardValidationStatus.validLocal => 'Reward valid',
      RewardValidationStatus.validExternalDemo => 'Demo validation',
      RewardValidationStatus.expired => 'Reward expired',
      RewardValidationStatus.alreadyRedeemed => 'Already redeemed',
      RewardValidationStatus.invalid => 'Invalid QR',
      RewardValidationStatus.wrongPartner => 'Different partner',
      RewardValidationStatus.redeemed => 'Reward redeemed',
    };
    return [
      Icon(success || valid ? Icons.check_circle_outline : Icons.info_outline,
          size: 56,
          color: success || valid
              ? AppColors.brandGreen
              : AppColors.textSecondary),
      _heading(title),
      if (status == RewardValidationStatus.invalid)
        const Text('This is not a valid BeenPin reward.'),
      if (status == RewardValidationStatus.wrongPartner)
        const Text('This reward belongs to another BeenPin partner.'),
      if (item == null && payload != null)
        const Text(
            'Backend verification is not connected yet. QR details are unverified; this reward cannot be redeemed on this device.'),
      if (valid) const Text('Validated against rewards saved on this device.'),
      if (item != null) ...[
        _line('Offer', item.reward.gift),
        _line('Partner', item.reward.partnerName),
      ] else if (payload != null)
        _line('Partner ID', payload.partnerId),
      if (payload != null) _line('Proof ID', item?.proofId ?? payload.proofId),
      if (item?.reward.capturedAt != null)
        _line('Captured at', _date(item!.reward.capturedAt!)),
      if (payload != null)
        _line(item == null ? 'QR date valid until (unverified)' : 'Valid until',
            _date(item?.validUntil ?? payload.validUntil)),
      if (item != null) _line('Source spot', item.reward.unlockedFromSpot),
      if (item?.reward.distanceMeters != null)
        _line(
            'GPS proof', '${item!.reward.distanceMeters!.round()} m from spot'),
      if (item?.redeemedAt != null)
        _line('Redeemed at', _date(item!.redeemedAt!)),
      if (valid) ...[
        _button('CONFIRM REDEMPTION', () => _validate(redeem: true)),
        TextButton(
            onPressed: _busy ? null : _home, child: const Text('Cancel')),
      ] else
        _button(
            status == RewardValidationStatus.invalid
                ? 'SCAN AGAIN'
                : 'SCAN ANOTHER',
            _scan),
    ];
  }

  void _home() => setState(() {
        _result = null;
        _qr = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surfaceSoft,
        appBar: AppBar(
            title: const Text.rich(TextSpan(children: [
          TextSpan(text: 'Been', style: TextStyle(color: AppColors.brandBlue)),
          TextSpan(text: 'Pin', style: TextStyle(color: AppColors.brandGreen)),
          TextSpan(text: ' Partner'),
        ]))),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            if (!_authorized) ...[
              _heading('Staff access'),
              TextField(
                  controller: _pin,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                      labelText: 'Partner PIN', errorText: _error),
                  onSubmitted: (_) => _unlock()),
              _button('Continue', _unlock),
              const SizedBox(height: 16),
              const Text('For BeenPin partner staff',
                  textAlign: TextAlign.center),
            ] else ...[
              if (_result != null)
                ..._verification(_result!)
              else ...[
                _heading('Ready to redeem'),
                const Text("Scan the customer's BeenPin reward"),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                    initialValue: _partnerId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Demo partner'),
                    items: _partners
                        .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.partnerName,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _partnerId = value);
                            }
                          }),
                _button('SCAN REWARD', _scan),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!),
                TextButton(
                    onPressed: _busy ? null : () => _validate(),
                    child: const Text('Retry validation')),
              ],
              if (_busy)
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator())),
              TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Exit Partner Mode')),
            ],
          ]),
        ))),
      );
}
