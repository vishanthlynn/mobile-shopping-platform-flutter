class PaymentRequest {
  const PaymentRequest.stripe({
    required this.cardNumber,
    required this.expiry,
    required this.cvc,
    required this.amount,
  })  : method = PaymentMethod.stripeTest,
        paypalEmail = null,
        paypalPassword = null;

  const PaymentRequest.paypal({
    required this.paypalEmail,
    required this.paypalPassword,
    required this.amount,
  })  : method = PaymentMethod.paypalTest,
        cardNumber = null,
        expiry = null,
        cvc = null;

  final PaymentMethod method;
  final String? cardNumber;
  final String? expiry;
  final String? cvc;
  final String? paypalEmail;
  final String? paypalPassword;
  final double amount;
}

enum PaymentMethod { stripeTest, paypalTest }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.stripeTest => 'Stripe test',
        PaymentMethod.paypalTest => 'PayPal sandbox',
      };

  String get storageKey => switch (this) {
        PaymentMethod.stripeTest => 'stripe_test',
        PaymentMethod.paypalTest => 'paypal_test',
      };
}

class PaymentReceipt {
  const PaymentReceipt({
    required this.ok,
    required this.reference,
    this.message,
  });

  final bool ok;
  final String reference;
  final String? message;
}

class PaymentService {
  const PaymentService();

  static const stripeSuccessPan = '4242424242424242';
  static const stripeDeclinePan = '4000000000000002';
  static const stripeInsufficientPan = '4000000000009995';
  static const paypalSandboxEmail = 'buyer@lumen.test';
  static const paypalSandboxPassword = 'sandbox';

  PaymentReceipt charge(PaymentRequest request) {
    if (request.amount <= 0) {
      return const PaymentReceipt(
        ok: false,
        reference: '',
        message: 'Cart total must be greater than zero.',
      );
    }
    return switch (request.method) {
      PaymentMethod.stripeTest => _chargeStripe(request),
      PaymentMethod.paypalTest => _chargePaypal(request),
    };
  }

  PaymentReceipt _chargeStripe(PaymentRequest request) {
    final pan = (request.cardNumber ?? '').replaceAll(RegExp(r'\s+'), '');
    final expiry = (request.expiry ?? '').trim();
    final cvc = (request.cvc ?? '').trim();

    if (!_validExpiry(expiry)) {
      return const PaymentReceipt(
        ok: false,
        reference: '',
        message: 'Enter a future expiry as MM/YY.',
      );
    }
    if (!RegExp(r'^\d{3,4}$').hasMatch(cvc)) {
      return const PaymentReceipt(
        ok: false,
        reference: '',
        message: 'Enter the 3-digit test CVC.',
      );
    }

    if (pan == stripeDeclinePan) {
      return const PaymentReceipt(
        ok: false,
        reference: '',
        message: 'Card declined. Stripe test card 4000...0002.',
      );
    }
    if (pan == stripeInsufficientPan) {
      return const PaymentReceipt(
        ok: false,
        reference: '',
        message: 'Insufficient funds. Stripe test card 4000...9995.',
      );
    }
    if (pan != stripeSuccessPan) {
      return const PaymentReceipt(
        ok: false,
        reference: '',
        message:
            'Use Stripe test card 4242 4242 4242 4242. Live cards are not charged.',
      );
    }
    if (!_luhn(pan)) {
      return const PaymentReceipt(
        ok: false,
        reference: '',
        message: 'Card number failed the Luhn check.',
      );
    }

    final reference = 'pi_test_${pan.substring(pan.length - 4)}_${request.amount.toStringAsFixed(2)}';
    return PaymentReceipt(ok: true, reference: reference);
  }

  PaymentReceipt _chargePaypal(PaymentRequest request) {
    final email = (request.paypalEmail ?? '').trim().toLowerCase();
    final password = request.paypalPassword ?? '';
    if (email != paypalSandboxEmail || password != paypalSandboxPassword) {
      return const PaymentReceipt(
        ok: false,
        reference: '',
        message: 'PayPal sandbox login is buyer@lumen.test / sandbox.',
      );
    }
    return PaymentReceipt(
      ok: true,
      reference: 'paypal_test_${request.amount.toStringAsFixed(2)}',
    );
  }

  bool _validExpiry(String expiry) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(expiry);
    if (match == null) return false;
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return false;
    final now = DateTime.now();
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);
    return endOfMonth.isAfter(now);
  }

  bool _luhn(String pan) {
    var sum = 0;
    var alternate = false;
    for (var i = pan.length - 1; i >= 0; i--) {
      var digit = int.parse(pan[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }
}
