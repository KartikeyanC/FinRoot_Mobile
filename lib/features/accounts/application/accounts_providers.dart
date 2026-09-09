import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/application/workspace_providers.dart';
import '../data/accounts_repository.dart';
import '../domain/account.dart';

/// The active workspace's accounts, from the local cache. Empty when there is
/// no workspace. Backs the Quick Add Transfer picker (M7).
final workspaceAccountsProvider = StreamProvider<List<AccountEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <AccountEntity>[]);
  return ref.watch(accountsRepositoryProvider).watchAll(tenantId);
}, name: 'workspaceAccounts');
