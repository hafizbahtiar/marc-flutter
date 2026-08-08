package com.hafizbahtiar.marc

import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_stripe (Payment Element/CardFormField, 3DS) perlukan
// FlutterFragmentActivity, bukan FlutterActivity biasa — native SDK
// Stripe guna Fragment untuk paparan kad/3DS.
class MainActivity : FlutterFragmentActivity()
