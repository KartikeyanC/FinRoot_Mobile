import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/upi_gateway.dart';

final upiGatewayProvider = Provider<UpiGateway>(
  (ref) => MethodChannelUpiGateway(),
  name: 'upiGateway',
);
