// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalTransactionsTable extends LocalTransactions
    with TableInfo<$LocalTransactionsTable, LocalTransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalSyncStatus, String>
  syncStatus =
      GeneratedColumn<String>(
        'sync_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('synced'),
      ).withConverter<LocalSyncStatus>(
        $LocalTransactionsTable.$convertersyncStatus,
      );
  static const VerificationMeta _pendingMutationIdMeta = const VerificationMeta(
    'pendingMutationId',
  );
  @override
  late final GeneratedColumn<String> pendingMutationId =
      GeneratedColumn<String>(
        'pending_mutation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> amount =
      GeneratedColumn<String>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($LocalTransactionsTable.$converteramount);
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentModeMeta = const VerificationMeta(
    'paymentMode',
  );
  @override
  late final GeneratedColumn<String> paymentMode = GeneratedColumn<String>(
    'payment_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transferToAccountIdMeta =
      const VerificationMeta('transferToAccountId');
  @override
  late final GeneratedColumn<String> transferToAccountId =
      GeneratedColumn<String>(
        'transfer_to_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _trackerIdMeta = const VerificationMeta(
    'trackerId',
  );
  @override
  late final GeneratedColumn<String> trackerId = GeneratedColumn<String>(
    'tracker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverCreatedAtMeta = const VerificationMeta(
    'serverCreatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverCreatedAt =
      GeneratedColumn<DateTime>(
        'server_created_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    userId,
    type,
    amount,
    currency,
    category,
    description,
    occurredAt,
    accountId,
    paymentMode,
    transferToAccountId,
    trackerId,
    serverCreatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('pending_mutation_id')) {
      context.handle(
        _pendingMutationIdMeta,
        pendingMutationId.isAcceptableOrUnknown(
          data['pending_mutation_id']!,
          _pendingMutationIdMeta,
        ),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('payment_mode')) {
      context.handle(
        _paymentModeMeta,
        paymentMode.isAcceptableOrUnknown(
          data['payment_mode']!,
          _paymentModeMeta,
        ),
      );
    }
    if (data.containsKey('transfer_to_account_id')) {
      context.handle(
        _transferToAccountIdMeta,
        transferToAccountId.isAcceptableOrUnknown(
          data['transfer_to_account_id']!,
          _transferToAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('tracker_id')) {
      context.handle(
        _trackerIdMeta,
        trackerId.isAcceptableOrUnknown(data['tracker_id']!, _trackerIdMeta),
      );
    }
    if (data.containsKey('server_created_at')) {
      context.handle(
        _serverCreatedAtMeta,
        serverCreatedAt.isAcceptableOrUnknown(
          data['server_created_at']!,
          _serverCreatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTransactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTransactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      syncStatus: $LocalTransactionsTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      pendingMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_mutation_id'],
      ),
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amount: $LocalTransactionsTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}amount'],
        )!,
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      paymentMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_mode'],
      ),
      transferToAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_to_account_id'],
      ),
      trackerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tracker_id'],
      ),
      serverCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_created_at'],
      ),
    );
  }

  @override
  $LocalTransactionsTable createAlias(String alias) {
    return $LocalTransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocalSyncStatus, String, String>
  $convertersyncStatus = const EnumNameConverter<LocalSyncStatus>(
    LocalSyncStatus.values,
  );
  static TypeConverter<Decimal, String> $converteramount =
      const DecimalConverter();
}

class LocalTransactionRow extends DataClass
    implements Insertable<LocalTransactionRow> {
  final String id;
  final String tenantId;

  /// Where this row stands relative to the server.
  final LocalSyncStatus syncStatus;

  /// The outbox `mutationId` that owns the pending local change, if any.
  final String? pendingMutationId;

  /// `transactions.updated_at` (etc.) as last seen from the server — the basis
  /// for delta pulls and last-write-wins conflict detection.
  final DateTime? serverUpdatedAt;

  /// When this cache row was last written locally.
  final DateTime cachedAt;
  final String? userId;
  final String type;
  final Decimal amount;
  final String currency;
  final String category;
  final String? description;
  final DateTime occurredAt;
  final String? accountId;
  final String? paymentMode;
  final String? transferToAccountId;
  final String? trackerId;
  final DateTime? serverCreatedAt;
  const LocalTransactionRow({
    required this.id,
    required this.tenantId,
    required this.syncStatus,
    this.pendingMutationId,
    this.serverUpdatedAt,
    required this.cachedAt,
    this.userId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.category,
    this.description,
    required this.occurredAt,
    this.accountId,
    this.paymentMode,
    this.transferToAccountId,
    this.trackerId,
    this.serverCreatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    {
      map['sync_status'] = Variable<String>(
        $LocalTransactionsTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    if (!nullToAbsent || pendingMutationId != null) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId);
    }
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['type'] = Variable<String>(type);
    {
      map['amount'] = Variable<String>(
        $LocalTransactionsTable.$converteramount.toSql(amount),
      );
    }
    map['currency'] = Variable<String>(currency);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || paymentMode != null) {
      map['payment_mode'] = Variable<String>(paymentMode);
    }
    if (!nullToAbsent || transferToAccountId != null) {
      map['transfer_to_account_id'] = Variable<String>(transferToAccountId);
    }
    if (!nullToAbsent || trackerId != null) {
      map['tracker_id'] = Variable<String>(trackerId);
    }
    if (!nullToAbsent || serverCreatedAt != null) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt);
    }
    return map;
  }

  LocalTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalTransactionsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      syncStatus: Value(syncStatus),
      pendingMutationId: pendingMutationId == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingMutationId),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      cachedAt: Value(cachedAt),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      type: Value(type),
      amount: Value(amount),
      currency: Value(currency),
      category: Value(category),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      occurredAt: Value(occurredAt),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      paymentMode: paymentMode == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMode),
      transferToAccountId: transferToAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferToAccountId),
      trackerId: trackerId == null && nullToAbsent
          ? const Value.absent()
          : Value(trackerId),
      serverCreatedAt: serverCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverCreatedAt),
    );
  }

  factory LocalTransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransactionRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      syncStatus: $LocalTransactionsTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      pendingMutationId: serializer.fromJson<String?>(
        json['pendingMutationId'],
      ),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      userId: serializer.fromJson<String?>(json['userId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<Decimal>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      category: serializer.fromJson<String>(json['category']),
      description: serializer.fromJson<String?>(json['description']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      paymentMode: serializer.fromJson<String?>(json['paymentMode']),
      transferToAccountId: serializer.fromJson<String?>(
        json['transferToAccountId'],
      ),
      trackerId: serializer.fromJson<String?>(json['trackerId']),
      serverCreatedAt: serializer.fromJson<DateTime?>(json['serverCreatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'syncStatus': serializer.toJson<String>(
        $LocalTransactionsTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'pendingMutationId': serializer.toJson<String?>(pendingMutationId),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'userId': serializer.toJson<String?>(userId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<Decimal>(amount),
      'currency': serializer.toJson<String>(currency),
      'category': serializer.toJson<String>(category),
      'description': serializer.toJson<String?>(description),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'accountId': serializer.toJson<String?>(accountId),
      'paymentMode': serializer.toJson<String?>(paymentMode),
      'transferToAccountId': serializer.toJson<String?>(transferToAccountId),
      'trackerId': serializer.toJson<String?>(trackerId),
      'serverCreatedAt': serializer.toJson<DateTime?>(serverCreatedAt),
    };
  }

  LocalTransactionRow copyWith({
    String? id,
    String? tenantId,
    LocalSyncStatus? syncStatus,
    Value<String?> pendingMutationId = const Value.absent(),
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    DateTime? cachedAt,
    Value<String?> userId = const Value.absent(),
    String? type,
    Decimal? amount,
    String? currency,
    String? category,
    Value<String?> description = const Value.absent(),
    DateTime? occurredAt,
    Value<String?> accountId = const Value.absent(),
    Value<String?> paymentMode = const Value.absent(),
    Value<String?> transferToAccountId = const Value.absent(),
    Value<String?> trackerId = const Value.absent(),
    Value<DateTime?> serverCreatedAt = const Value.absent(),
  }) => LocalTransactionRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    syncStatus: syncStatus ?? this.syncStatus,
    pendingMutationId: pendingMutationId.present
        ? pendingMutationId.value
        : this.pendingMutationId,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
    userId: userId.present ? userId.value : this.userId,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    category: category ?? this.category,
    description: description.present ? description.value : this.description,
    occurredAt: occurredAt ?? this.occurredAt,
    accountId: accountId.present ? accountId.value : this.accountId,
    paymentMode: paymentMode.present ? paymentMode.value : this.paymentMode,
    transferToAccountId: transferToAccountId.present
        ? transferToAccountId.value
        : this.transferToAccountId,
    trackerId: trackerId.present ? trackerId.value : this.trackerId,
    serverCreatedAt: serverCreatedAt.present
        ? serverCreatedAt.value
        : this.serverCreatedAt,
  );
  LocalTransactionRow copyWithCompanion(LocalTransactionsCompanion data) {
    return LocalTransactionRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      pendingMutationId: data.pendingMutationId.present
          ? data.pendingMutationId.value
          : this.pendingMutationId,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      paymentMode: data.paymentMode.present
          ? data.paymentMode.value
          : this.paymentMode,
      transferToAccountId: data.transferToAccountId.present
          ? data.transferToAccountId.value
          : this.transferToAccountId,
      trackerId: data.trackerId.present ? data.trackerId.value : this.trackerId,
      serverCreatedAt: data.serverCreatedAt.present
          ? data.serverCreatedAt.value
          : this.serverCreatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransactionRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('accountId: $accountId, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('transferToAccountId: $transferToAccountId, ')
          ..write('trackerId: $trackerId, ')
          ..write('serverCreatedAt: $serverCreatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    userId,
    type,
    amount,
    currency,
    category,
    description,
    occurredAt,
    accountId,
    paymentMode,
    transferToAccountId,
    trackerId,
    serverCreatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransactionRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.syncStatus == this.syncStatus &&
          other.pendingMutationId == this.pendingMutationId &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.cachedAt == this.cachedAt &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.category == this.category &&
          other.description == this.description &&
          other.occurredAt == this.occurredAt &&
          other.accountId == this.accountId &&
          other.paymentMode == this.paymentMode &&
          other.transferToAccountId == this.transferToAccountId &&
          other.trackerId == this.trackerId &&
          other.serverCreatedAt == this.serverCreatedAt);
}

class LocalTransactionsCompanion extends UpdateCompanion<LocalTransactionRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<LocalSyncStatus> syncStatus;
  final Value<String?> pendingMutationId;
  final Value<DateTime?> serverUpdatedAt;
  final Value<DateTime> cachedAt;
  final Value<String?> userId;
  final Value<String> type;
  final Value<Decimal> amount;
  final Value<String> currency;
  final Value<String> category;
  final Value<String?> description;
  final Value<DateTime> occurredAt;
  final Value<String?> accountId;
  final Value<String?> paymentMode;
  final Value<String?> transferToAccountId;
  final Value<String?> trackerId;
  final Value<DateTime?> serverCreatedAt;
  final Value<int> rowid;
  const LocalTransactionsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.accountId = const Value.absent(),
    this.paymentMode = const Value.absent(),
    this.transferToAccountId = const Value.absent(),
    this.trackerId = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTransactionsCompanion.insert({
    required String id,
    required String tenantId,
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.userId = const Value.absent(),
    required String type,
    required Decimal amount,
    this.currency = const Value.absent(),
    required String category,
    this.description = const Value.absent(),
    required DateTime occurredAt,
    this.accountId = const Value.absent(),
    this.paymentMode = const Value.absent(),
    this.transferToAccountId = const Value.absent(),
    this.trackerId = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       type = Value(type),
       amount = Value(amount),
       category = Value(category),
       occurredAt = Value(occurredAt);
  static Insertable<LocalTransactionRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? syncStatus,
    Expression<String>? pendingMutationId,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? cachedAt,
    Expression<String>? userId,
    Expression<String>? type,
    Expression<String>? amount,
    Expression<String>? currency,
    Expression<String>? category,
    Expression<String>? description,
    Expression<DateTime>? occurredAt,
    Expression<String>? accountId,
    Expression<String>? paymentMode,
    Expression<String>? transferToAccountId,
    Expression<String>? trackerId,
    Expression<DateTime>? serverCreatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (pendingMutationId != null) 'pending_mutation_id': pendingMutationId,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (accountId != null) 'account_id': accountId,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (transferToAccountId != null)
        'transfer_to_account_id': transferToAccountId,
      if (trackerId != null) 'tracker_id': trackerId,
      if (serverCreatedAt != null) 'server_created_at': serverCreatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<LocalSyncStatus>? syncStatus,
    Value<String?>? pendingMutationId,
    Value<DateTime?>? serverUpdatedAt,
    Value<DateTime>? cachedAt,
    Value<String?>? userId,
    Value<String>? type,
    Value<Decimal>? amount,
    Value<String>? currency,
    Value<String>? category,
    Value<String?>? description,
    Value<DateTime>? occurredAt,
    Value<String?>? accountId,
    Value<String?>? paymentMode,
    Value<String?>? transferToAccountId,
    Value<String?>? trackerId,
    Value<DateTime?>? serverCreatedAt,
    Value<int>? rowid,
  }) {
    return LocalTransactionsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingMutationId: pendingMutationId ?? this.pendingMutationId,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      occurredAt: occurredAt ?? this.occurredAt,
      accountId: accountId ?? this.accountId,
      paymentMode: paymentMode ?? this.paymentMode,
      transferToAccountId: transferToAccountId ?? this.transferToAccountId,
      trackerId: trackerId ?? this.trackerId,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $LocalTransactionsTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (pendingMutationId.present) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(
        $LocalTransactionsTable.$converteramount.toSql(amount.value),
      );
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (paymentMode.present) {
      map['payment_mode'] = Variable<String>(paymentMode.value);
    }
    if (transferToAccountId.present) {
      map['transfer_to_account_id'] = Variable<String>(
        transferToAccountId.value,
      );
    }
    if (trackerId.present) {
      map['tracker_id'] = Variable<String>(trackerId.value);
    }
    if (serverCreatedAt.present) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('accountId: $accountId, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('transferToAccountId: $transferToAccountId, ')
          ..write('trackerId: $trackerId, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAccountsTable extends LocalAccounts
    with TableInfo<$LocalAccountsTable, LocalAccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalSyncStatus, String>
  syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  ).withConverter<LocalSyncStatus>($LocalAccountsTable.$convertersyncStatus);
  static const VerificationMeta _pendingMutationIdMeta = const VerificationMeta(
    'pendingMutationId',
  );
  @override
  late final GeneratedColumn<String> pendingMutationId =
      GeneratedColumn<String>(
        'pending_mutation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, String> openingBalance =
      GeneratedColumn<String>(
        'opening_balance',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Decimal?>($LocalAccountsTable.$converteropeningBalancen);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    name,
    type,
    openingBalance,
    color,
    icon,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('pending_mutation_id')) {
      context.handle(
        _pendingMutationIdMeta,
        pendingMutationId.isAcceptableOrUnknown(
          data['pending_mutation_id']!,
          _pendingMutationIdMeta,
        ),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      syncStatus: $LocalAccountsTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      pendingMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_mutation_id'],
      ),
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      openingBalance: $LocalAccountsTable.$converteropeningBalancen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}opening_balance'],
        ),
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
    );
  }

  @override
  $LocalAccountsTable createAlias(String alias) {
    return $LocalAccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocalSyncStatus, String, String>
  $convertersyncStatus = const EnumNameConverter<LocalSyncStatus>(
    LocalSyncStatus.values,
  );
  static TypeConverter<Decimal, String> $converteropeningBalance =
      const DecimalConverter();
  static TypeConverter<Decimal?, String?> $converteropeningBalancen =
      NullAwareTypeConverter.wrap($converteropeningBalance);
}

class LocalAccountRow extends DataClass implements Insertable<LocalAccountRow> {
  final String id;
  final String tenantId;

  /// Where this row stands relative to the server.
  final LocalSyncStatus syncStatus;

  /// The outbox `mutationId` that owns the pending local change, if any.
  final String? pendingMutationId;

  /// `transactions.updated_at` (etc.) as last seen from the server — the basis
  /// for delta pulls and last-write-wins conflict detection.
  final DateTime? serverUpdatedAt;

  /// When this cache row was last written locally.
  final DateTime cachedAt;
  final String name;
  final String type;
  final Decimal? openingBalance;
  final String? color;
  final String? icon;
  const LocalAccountRow({
    required this.id,
    required this.tenantId,
    required this.syncStatus,
    this.pendingMutationId,
    this.serverUpdatedAt,
    required this.cachedAt,
    required this.name,
    required this.type,
    this.openingBalance,
    this.color,
    this.icon,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    {
      map['sync_status'] = Variable<String>(
        $LocalAccountsTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    if (!nullToAbsent || pendingMutationId != null) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId);
    }
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || openingBalance != null) {
      map['opening_balance'] = Variable<String>(
        $LocalAccountsTable.$converteropeningBalancen.toSql(openingBalance),
      );
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    return map;
  }

  LocalAccountsCompanion toCompanion(bool nullToAbsent) {
    return LocalAccountsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      syncStatus: Value(syncStatus),
      pendingMutationId: pendingMutationId == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingMutationId),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      cachedAt: Value(cachedAt),
      name: Value(name),
      type: Value(type),
      openingBalance: openingBalance == null && nullToAbsent
          ? const Value.absent()
          : Value(openingBalance),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
    );
  }

  factory LocalAccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAccountRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      syncStatus: $LocalAccountsTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      pendingMutationId: serializer.fromJson<String?>(
        json['pendingMutationId'],
      ),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      openingBalance: serializer.fromJson<Decimal?>(json['openingBalance']),
      color: serializer.fromJson<String?>(json['color']),
      icon: serializer.fromJson<String?>(json['icon']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'syncStatus': serializer.toJson<String>(
        $LocalAccountsTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'pendingMutationId': serializer.toJson<String?>(pendingMutationId),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'openingBalance': serializer.toJson<Decimal?>(openingBalance),
      'color': serializer.toJson<String?>(color),
      'icon': serializer.toJson<String?>(icon),
    };
  }

  LocalAccountRow copyWith({
    String? id,
    String? tenantId,
    LocalSyncStatus? syncStatus,
    Value<String?> pendingMutationId = const Value.absent(),
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    DateTime? cachedAt,
    String? name,
    String? type,
    Value<Decimal?> openingBalance = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<String?> icon = const Value.absent(),
  }) => LocalAccountRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    syncStatus: syncStatus ?? this.syncStatus,
    pendingMutationId: pendingMutationId.present
        ? pendingMutationId.value
        : this.pendingMutationId,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
    name: name ?? this.name,
    type: type ?? this.type,
    openingBalance: openingBalance.present
        ? openingBalance.value
        : this.openingBalance,
    color: color.present ? color.value : this.color,
    icon: icon.present ? icon.value : this.icon,
  );
  LocalAccountRow copyWithCompanion(LocalAccountsCompanion data) {
    return LocalAccountRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      pendingMutationId: data.pendingMutationId.present
          ? data.pendingMutationId.value
          : this.pendingMutationId,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      openingBalance: data.openingBalance.present
          ? data.openingBalance.value
          : this.openingBalance,
      color: data.color.present ? data.color.value : this.color,
      icon: data.icon.present ? data.icon.value : this.icon,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAccountRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('color: $color, ')
          ..write('icon: $icon')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    name,
    type,
    openingBalance,
    color,
    icon,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAccountRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.syncStatus == this.syncStatus &&
          other.pendingMutationId == this.pendingMutationId &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.cachedAt == this.cachedAt &&
          other.name == this.name &&
          other.type == this.type &&
          other.openingBalance == this.openingBalance &&
          other.color == this.color &&
          other.icon == this.icon);
}

class LocalAccountsCompanion extends UpdateCompanion<LocalAccountRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<LocalSyncStatus> syncStatus;
  final Value<String?> pendingMutationId;
  final Value<DateTime?> serverUpdatedAt;
  final Value<DateTime> cachedAt;
  final Value<String> name;
  final Value<String> type;
  final Value<Decimal?> openingBalance;
  final Value<String?> color;
  final Value<String?> icon;
  final Value<int> rowid;
  const LocalAccountsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.openingBalance = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAccountsCompanion.insert({
    required String id,
    required String tenantId,
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    required String name,
    required String type,
    this.openingBalance = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       name = Value(name),
       type = Value(type);
  static Insertable<LocalAccountRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? syncStatus,
    Expression<String>? pendingMutationId,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? cachedAt,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? openingBalance,
    Expression<String>? color,
    Expression<String>? icon,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (pendingMutationId != null) 'pending_mutation_id': pendingMutationId,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (openingBalance != null) 'opening_balance': openingBalance,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<LocalSyncStatus>? syncStatus,
    Value<String?>? pendingMutationId,
    Value<DateTime?>? serverUpdatedAt,
    Value<DateTime>? cachedAt,
    Value<String>? name,
    Value<String>? type,
    Value<Decimal?>? openingBalance,
    Value<String?>? color,
    Value<String?>? icon,
    Value<int>? rowid,
  }) {
    return LocalAccountsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingMutationId: pendingMutationId ?? this.pendingMutationId,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $LocalAccountsTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (pendingMutationId.present) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (openingBalance.present) {
      map['opening_balance'] = Variable<String>(
        $LocalAccountsTable.$converteropeningBalancen.toSql(
          openingBalance.value,
        ),
      );
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAccountsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTrackersTable extends LocalTrackers
    with TableInfo<$LocalTrackersTable, LocalTrackerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTrackersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalSyncStatus, String>
  syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  ).withConverter<LocalSyncStatus>($LocalTrackersTable.$convertersyncStatus);
  static const VerificationMeta _pendingMutationIdMeta = const VerificationMeta(
    'pendingMutationId',
  );
  @override
  late final GeneratedColumn<String> pendingMutationId =
      GeneratedColumn<String>(
        'pending_mutation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, String> budget =
      GeneratedColumn<String>(
        'budget',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Decimal?>($LocalTrackersTable.$converterbudgetn);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    name,
    type,
    startDate,
    endDate,
    budget,
    description,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_trackers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTrackerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('pending_mutation_id')) {
      context.handle(
        _pendingMutationIdMeta,
        pendingMutationId.isAcceptableOrUnknown(
          data['pending_mutation_id']!,
          _pendingMutationIdMeta,
        ),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTrackerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTrackerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      syncStatus: $LocalTrackersTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      pendingMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_mutation_id'],
      ),
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      budget: $LocalTrackersTable.$converterbudgetn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}budget'],
        ),
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $LocalTrackersTable createAlias(String alias) {
    return $LocalTrackersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocalSyncStatus, String, String>
  $convertersyncStatus = const EnumNameConverter<LocalSyncStatus>(
    LocalSyncStatus.values,
  );
  static TypeConverter<Decimal, String> $converterbudget =
      const DecimalConverter();
  static TypeConverter<Decimal?, String?> $converterbudgetn =
      NullAwareTypeConverter.wrap($converterbudget);
}

class LocalTrackerRow extends DataClass implements Insertable<LocalTrackerRow> {
  final String id;
  final String tenantId;

  /// Where this row stands relative to the server.
  final LocalSyncStatus syncStatus;

  /// The outbox `mutationId` that owns the pending local change, if any.
  final String? pendingMutationId;

  /// `transactions.updated_at` (etc.) as last seen from the server — the basis
  /// for delta pulls and last-write-wins conflict detection.
  final DateTime? serverUpdatedAt;

  /// When this cache row was last written locally.
  final DateTime cachedAt;
  final String name;
  final String type;
  final DateTime startDate;
  final DateTime? endDate;

  /// INR-anchored (web keeps tracker budgets in the workspace currency).
  final Decimal? budget;
  final String? description;
  final String status;
  const LocalTrackerRow({
    required this.id,
    required this.tenantId,
    required this.syncStatus,
    this.pendingMutationId,
    this.serverUpdatedAt,
    required this.cachedAt,
    required this.name,
    required this.type,
    required this.startDate,
    this.endDate,
    this.budget,
    this.description,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    {
      map['sync_status'] = Variable<String>(
        $LocalTrackersTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    if (!nullToAbsent || pendingMutationId != null) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId);
    }
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || budget != null) {
      map['budget'] = Variable<String>(
        $LocalTrackersTable.$converterbudgetn.toSql(budget),
      );
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  LocalTrackersCompanion toCompanion(bool nullToAbsent) {
    return LocalTrackersCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      syncStatus: Value(syncStatus),
      pendingMutationId: pendingMutationId == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingMutationId),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      cachedAt: Value(cachedAt),
      name: Value(name),
      type: Value(type),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      budget: budget == null && nullToAbsent
          ? const Value.absent()
          : Value(budget),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
    );
  }

  factory LocalTrackerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTrackerRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      syncStatus: $LocalTrackersTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      pendingMutationId: serializer.fromJson<String?>(
        json['pendingMutationId'],
      ),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      budget: serializer.fromJson<Decimal?>(json['budget']),
      description: serializer.fromJson<String?>(json['description']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'syncStatus': serializer.toJson<String>(
        $LocalTrackersTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'pendingMutationId': serializer.toJson<String?>(pendingMutationId),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'budget': serializer.toJson<Decimal?>(budget),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(status),
    };
  }

  LocalTrackerRow copyWith({
    String? id,
    String? tenantId,
    LocalSyncStatus? syncStatus,
    Value<String?> pendingMutationId = const Value.absent(),
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    DateTime? cachedAt,
    String? name,
    String? type,
    DateTime? startDate,
    Value<DateTime?> endDate = const Value.absent(),
    Value<Decimal?> budget = const Value.absent(),
    Value<String?> description = const Value.absent(),
    String? status,
  }) => LocalTrackerRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    syncStatus: syncStatus ?? this.syncStatus,
    pendingMutationId: pendingMutationId.present
        ? pendingMutationId.value
        : this.pendingMutationId,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
    name: name ?? this.name,
    type: type ?? this.type,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    budget: budget.present ? budget.value : this.budget,
    description: description.present ? description.value : this.description,
    status: status ?? this.status,
  );
  LocalTrackerRow copyWithCompanion(LocalTrackersCompanion data) {
    return LocalTrackerRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      pendingMutationId: data.pendingMutationId.present
          ? data.pendingMutationId.value
          : this.pendingMutationId,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      budget: data.budget.present ? data.budget.value : this.budget,
      description: data.description.present
          ? data.description.value
          : this.description,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTrackerRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('budget: $budget, ')
          ..write('description: $description, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    name,
    type,
    startDate,
    endDate,
    budget,
    description,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTrackerRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.syncStatus == this.syncStatus &&
          other.pendingMutationId == this.pendingMutationId &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.cachedAt == this.cachedAt &&
          other.name == this.name &&
          other.type == this.type &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.budget == this.budget &&
          other.description == this.description &&
          other.status == this.status);
}

class LocalTrackersCompanion extends UpdateCompanion<LocalTrackerRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<LocalSyncStatus> syncStatus;
  final Value<String?> pendingMutationId;
  final Value<DateTime?> serverUpdatedAt;
  final Value<DateTime> cachedAt;
  final Value<String> name;
  final Value<String> type;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<Decimal?> budget;
  final Value<String?> description;
  final Value<String> status;
  final Value<int> rowid;
  const LocalTrackersCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.budget = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTrackersCompanion.insert({
    required String id,
    required String tenantId,
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    required String name,
    required String type,
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.budget = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       name = Value(name),
       type = Value(type),
       startDate = Value(startDate);
  static Insertable<LocalTrackerRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? syncStatus,
    Expression<String>? pendingMutationId,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? cachedAt,
    Expression<String>? name,
    Expression<String>? type,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? budget,
    Expression<String>? description,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (pendingMutationId != null) 'pending_mutation_id': pendingMutationId,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (budget != null) 'budget': budget,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTrackersCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<LocalSyncStatus>? syncStatus,
    Value<String?>? pendingMutationId,
    Value<DateTime?>? serverUpdatedAt,
    Value<DateTime>? cachedAt,
    Value<String>? name,
    Value<String>? type,
    Value<DateTime>? startDate,
    Value<DateTime?>? endDate,
    Value<Decimal?>? budget,
    Value<String?>? description,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return LocalTrackersCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingMutationId: pendingMutationId ?? this.pendingMutationId,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      name: name ?? this.name,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      description: description ?? this.description,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $LocalTrackersTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (pendingMutationId.present) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (budget.present) {
      map['budget'] = Variable<String>(
        $LocalTrackersTable.$converterbudgetn.toSql(budget.value),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTrackersCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('budget: $budget, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalBudgetsTable extends LocalBudgets
    with TableInfo<$LocalBudgetsTable, LocalBudgetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalSyncStatus, String>
  syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  ).withConverter<LocalSyncStatus>($LocalBudgetsTable.$convertersyncStatus);
  static const VerificationMeta _pendingMutationIdMeta = const VerificationMeta(
    'pendingMutationId',
  );
  @override
  late final GeneratedColumn<String> pendingMutationId =
      GeneratedColumn<String>(
        'pending_mutation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  @override
  late final GeneratedColumn<String> bucket = GeneratedColumn<String>(
    'bucket',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> allocated =
      GeneratedColumn<String>(
        'allocated',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($LocalBudgetsTable.$converterallocated);
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
    'period',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('monthly'),
  );
  static const VerificationMeta _periodStartMeta = const VerificationMeta(
    'periodStart',
  );
  @override
  late final GeneratedColumn<DateTime> periodStart = GeneratedColumn<DateTime>(
    'period_start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    bucket,
    allocated,
    period,
    periodStart,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBudgetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('pending_mutation_id')) {
      context.handle(
        _pendingMutationIdMeta,
        pendingMutationId.isAcceptableOrUnknown(
          data['pending_mutation_id']!,
          _pendingMutationIdMeta,
        ),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    if (data.containsKey('bucket')) {
      context.handle(
        _bucketMeta,
        bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketMeta);
    }
    if (data.containsKey('period')) {
      context.handle(
        _periodMeta,
        period.isAcceptableOrUnknown(data['period']!, _periodMeta),
      );
    }
    if (data.containsKey('period_start')) {
      context.handle(
        _periodStartMeta,
        periodStart.isAcceptableOrUnknown(
          data['period_start']!,
          _periodStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodStartMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBudgetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBudgetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      syncStatus: $LocalBudgetsTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      pendingMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_mutation_id'],
      ),
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      bucket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket'],
      )!,
      allocated: $LocalBudgetsTable.$converterallocated.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}allocated'],
        )!,
      ),
      period: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period'],
      )!,
      periodStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}period_start'],
      )!,
    );
  }

  @override
  $LocalBudgetsTable createAlias(String alias) {
    return $LocalBudgetsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocalSyncStatus, String, String>
  $convertersyncStatus = const EnumNameConverter<LocalSyncStatus>(
    LocalSyncStatus.values,
  );
  static TypeConverter<Decimal, String> $converterallocated =
      const DecimalConverter();
}

class LocalBudgetRow extends DataClass implements Insertable<LocalBudgetRow> {
  final String id;
  final String tenantId;

  /// Where this row stands relative to the server.
  final LocalSyncStatus syncStatus;

  /// The outbox `mutationId` that owns the pending local change, if any.
  final String? pendingMutationId;

  /// `transactions.updated_at` (etc.) as last seen from the server — the basis
  /// for delta pulls and last-write-wins conflict detection.
  final DateTime? serverUpdatedAt;

  /// When this cache row was last written locally.
  final DateTime cachedAt;
  final String bucket;
  final Decimal allocated;
  final String period;
  final DateTime periodStart;
  const LocalBudgetRow({
    required this.id,
    required this.tenantId,
    required this.syncStatus,
    this.pendingMutationId,
    this.serverUpdatedAt,
    required this.cachedAt,
    required this.bucket,
    required this.allocated,
    required this.period,
    required this.periodStart,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    {
      map['sync_status'] = Variable<String>(
        $LocalBudgetsTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    if (!nullToAbsent || pendingMutationId != null) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId);
    }
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['bucket'] = Variable<String>(bucket);
    {
      map['allocated'] = Variable<String>(
        $LocalBudgetsTable.$converterallocated.toSql(allocated),
      );
    }
    map['period'] = Variable<String>(period);
    map['period_start'] = Variable<DateTime>(periodStart);
    return map;
  }

  LocalBudgetsCompanion toCompanion(bool nullToAbsent) {
    return LocalBudgetsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      syncStatus: Value(syncStatus),
      pendingMutationId: pendingMutationId == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingMutationId),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      cachedAt: Value(cachedAt),
      bucket: Value(bucket),
      allocated: Value(allocated),
      period: Value(period),
      periodStart: Value(periodStart),
    );
  }

  factory LocalBudgetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBudgetRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      syncStatus: $LocalBudgetsTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      pendingMutationId: serializer.fromJson<String?>(
        json['pendingMutationId'],
      ),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      bucket: serializer.fromJson<String>(json['bucket']),
      allocated: serializer.fromJson<Decimal>(json['allocated']),
      period: serializer.fromJson<String>(json['period']),
      periodStart: serializer.fromJson<DateTime>(json['periodStart']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'syncStatus': serializer.toJson<String>(
        $LocalBudgetsTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'pendingMutationId': serializer.toJson<String?>(pendingMutationId),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'bucket': serializer.toJson<String>(bucket),
      'allocated': serializer.toJson<Decimal>(allocated),
      'period': serializer.toJson<String>(period),
      'periodStart': serializer.toJson<DateTime>(periodStart),
    };
  }

  LocalBudgetRow copyWith({
    String? id,
    String? tenantId,
    LocalSyncStatus? syncStatus,
    Value<String?> pendingMutationId = const Value.absent(),
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    DateTime? cachedAt,
    String? bucket,
    Decimal? allocated,
    String? period,
    DateTime? periodStart,
  }) => LocalBudgetRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    syncStatus: syncStatus ?? this.syncStatus,
    pendingMutationId: pendingMutationId.present
        ? pendingMutationId.value
        : this.pendingMutationId,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
    bucket: bucket ?? this.bucket,
    allocated: allocated ?? this.allocated,
    period: period ?? this.period,
    periodStart: periodStart ?? this.periodStart,
  );
  LocalBudgetRow copyWithCompanion(LocalBudgetsCompanion data) {
    return LocalBudgetRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      pendingMutationId: data.pendingMutationId.present
          ? data.pendingMutationId.value
          : this.pendingMutationId,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      allocated: data.allocated.present ? data.allocated.value : this.allocated,
      period: data.period.present ? data.period.value : this.period,
      periodStart: data.periodStart.present
          ? data.periodStart.value
          : this.periodStart,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBudgetRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('bucket: $bucket, ')
          ..write('allocated: $allocated, ')
          ..write('period: $period, ')
          ..write('periodStart: $periodStart')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    bucket,
    allocated,
    period,
    periodStart,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBudgetRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.syncStatus == this.syncStatus &&
          other.pendingMutationId == this.pendingMutationId &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.cachedAt == this.cachedAt &&
          other.bucket == this.bucket &&
          other.allocated == this.allocated &&
          other.period == this.period &&
          other.periodStart == this.periodStart);
}

class LocalBudgetsCompanion extends UpdateCompanion<LocalBudgetRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<LocalSyncStatus> syncStatus;
  final Value<String?> pendingMutationId;
  final Value<DateTime?> serverUpdatedAt;
  final Value<DateTime> cachedAt;
  final Value<String> bucket;
  final Value<Decimal> allocated;
  final Value<String> period;
  final Value<DateTime> periodStart;
  final Value<int> rowid;
  const LocalBudgetsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.bucket = const Value.absent(),
    this.allocated = const Value.absent(),
    this.period = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBudgetsCompanion.insert({
    required String id,
    required String tenantId,
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    required String bucket,
    required Decimal allocated,
    this.period = const Value.absent(),
    required DateTime periodStart,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       bucket = Value(bucket),
       allocated = Value(allocated),
       periodStart = Value(periodStart);
  static Insertable<LocalBudgetRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? syncStatus,
    Expression<String>? pendingMutationId,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? cachedAt,
    Expression<String>? bucket,
    Expression<String>? allocated,
    Expression<String>? period,
    Expression<DateTime>? periodStart,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (pendingMutationId != null) 'pending_mutation_id': pendingMutationId,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (bucket != null) 'bucket': bucket,
      if (allocated != null) 'allocated': allocated,
      if (period != null) 'period': period,
      if (periodStart != null) 'period_start': periodStart,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBudgetsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<LocalSyncStatus>? syncStatus,
    Value<String?>? pendingMutationId,
    Value<DateTime?>? serverUpdatedAt,
    Value<DateTime>? cachedAt,
    Value<String>? bucket,
    Value<Decimal>? allocated,
    Value<String>? period,
    Value<DateTime>? periodStart,
    Value<int>? rowid,
  }) {
    return LocalBudgetsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingMutationId: pendingMutationId ?? this.pendingMutationId,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      bucket: bucket ?? this.bucket,
      allocated: allocated ?? this.allocated,
      period: period ?? this.period,
      periodStart: periodStart ?? this.periodStart,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $LocalBudgetsTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (pendingMutationId.present) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<String>(bucket.value);
    }
    if (allocated.present) {
      map['allocated'] = Variable<String>(
        $LocalBudgetsTable.$converterallocated.toSql(allocated.value),
      );
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (periodStart.present) {
      map['period_start'] = Variable<DateTime>(periodStart.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('bucket: $bucket, ')
          ..write('allocated: $allocated, ')
          ..write('period: $period, ')
          ..write('periodStart: $periodStart, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalGoalsTable extends LocalGoals
    with TableInfo<$LocalGoalsTable, LocalGoalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalSyncStatus, String>
  syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  ).withConverter<LocalSyncStatus>($LocalGoalsTable.$convertersyncStatus);
  static const VerificationMeta _pendingMutationIdMeta = const VerificationMeta(
    'pendingMutationId',
  );
  @override
  late final GeneratedColumn<String> pendingMutationId =
      GeneratedColumn<String>(
        'pending_mutation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> targetAmount =
      GeneratedColumn<String>(
        'target_amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($LocalGoalsTable.$convertertargetAmount);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> currentAmount =
      GeneratedColumn<String>(
        'current_amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($LocalGoalsTable.$convertercurrentAmount);
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    title,
    category,
    targetAmount,
    currentAmount,
    currency,
    targetDate,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalGoalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('pending_mutation_id')) {
      context.handle(
        _pendingMutationIdMeta,
        pendingMutationId.isAcceptableOrUnknown(
          data['pending_mutation_id']!,
          _pendingMutationIdMeta,
        ),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalGoalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalGoalRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      syncStatus: $LocalGoalsTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      pendingMutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_mutation_id'],
      ),
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      targetAmount: $LocalGoalsTable.$convertertargetAmount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}target_amount'],
        )!,
      ),
      currentAmount: $LocalGoalsTable.$convertercurrentAmount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}current_amount'],
        )!,
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $LocalGoalsTable createAlias(String alias) {
    return $LocalGoalsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocalSyncStatus, String, String>
  $convertersyncStatus = const EnumNameConverter<LocalSyncStatus>(
    LocalSyncStatus.values,
  );
  static TypeConverter<Decimal, String> $convertertargetAmount =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $convertercurrentAmount =
      const DecimalConverter();
}

class LocalGoalRow extends DataClass implements Insertable<LocalGoalRow> {
  final String id;
  final String tenantId;

  /// Where this row stands relative to the server.
  final LocalSyncStatus syncStatus;

  /// The outbox `mutationId` that owns the pending local change, if any.
  final String? pendingMutationId;

  /// `transactions.updated_at` (etc.) as last seen from the server — the basis
  /// for delta pulls and last-write-wins conflict detection.
  final DateTime? serverUpdatedAt;

  /// When this cache row was last written locally.
  final DateTime cachedAt;
  final String title;
  final String? category;
  final Decimal targetAmount;
  final Decimal currentAmount;
  final String currency;
  final DateTime? targetDate;
  final String status;
  const LocalGoalRow({
    required this.id,
    required this.tenantId,
    required this.syncStatus,
    this.pendingMutationId,
    this.serverUpdatedAt,
    required this.cachedAt,
    required this.title,
    this.category,
    required this.targetAmount,
    required this.currentAmount,
    required this.currency,
    this.targetDate,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    {
      map['sync_status'] = Variable<String>(
        $LocalGoalsTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    if (!nullToAbsent || pendingMutationId != null) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId);
    }
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    {
      map['target_amount'] = Variable<String>(
        $LocalGoalsTable.$convertertargetAmount.toSql(targetAmount),
      );
    }
    {
      map['current_amount'] = Variable<String>(
        $LocalGoalsTable.$convertercurrentAmount.toSql(currentAmount),
      );
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  LocalGoalsCompanion toCompanion(bool nullToAbsent) {
    return LocalGoalsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      syncStatus: Value(syncStatus),
      pendingMutationId: pendingMutationId == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingMutationId),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      cachedAt: Value(cachedAt),
      title: Value(title),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      targetAmount: Value(targetAmount),
      currentAmount: Value(currentAmount),
      currency: Value(currency),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      status: Value(status),
    );
  }

  factory LocalGoalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalGoalRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      syncStatus: $LocalGoalsTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      pendingMutationId: serializer.fromJson<String?>(
        json['pendingMutationId'],
      ),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String?>(json['category']),
      targetAmount: serializer.fromJson<Decimal>(json['targetAmount']),
      currentAmount: serializer.fromJson<Decimal>(json['currentAmount']),
      currency: serializer.fromJson<String>(json['currency']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'syncStatus': serializer.toJson<String>(
        $LocalGoalsTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'pendingMutationId': serializer.toJson<String?>(pendingMutationId),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String?>(category),
      'targetAmount': serializer.toJson<Decimal>(targetAmount),
      'currentAmount': serializer.toJson<Decimal>(currentAmount),
      'currency': serializer.toJson<String>(currency),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'status': serializer.toJson<String>(status),
    };
  }

  LocalGoalRow copyWith({
    String? id,
    String? tenantId,
    LocalSyncStatus? syncStatus,
    Value<String?> pendingMutationId = const Value.absent(),
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    DateTime? cachedAt,
    String? title,
    Value<String?> category = const Value.absent(),
    Decimal? targetAmount,
    Decimal? currentAmount,
    String? currency,
    Value<DateTime?> targetDate = const Value.absent(),
    String? status,
  }) => LocalGoalRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    syncStatus: syncStatus ?? this.syncStatus,
    pendingMutationId: pendingMutationId.present
        ? pendingMutationId.value
        : this.pendingMutationId,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
    title: title ?? this.title,
    category: category.present ? category.value : this.category,
    targetAmount: targetAmount ?? this.targetAmount,
    currentAmount: currentAmount ?? this.currentAmount,
    currency: currency ?? this.currency,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    status: status ?? this.status,
  );
  LocalGoalRow copyWithCompanion(LocalGoalsCompanion data) {
    return LocalGoalRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      pendingMutationId: data.pendingMutationId.present
          ? data.pendingMutationId.value
          : this.pendingMutationId,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      currentAmount: data.currentAmount.present
          ? data.currentAmount.value
          : this.currentAmount,
      currency: data.currency.present ? data.currency.value : this.currency,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalGoalRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('currency: $currency, ')
          ..write('targetDate: $targetDate, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    syncStatus,
    pendingMutationId,
    serverUpdatedAt,
    cachedAt,
    title,
    category,
    targetAmount,
    currentAmount,
    currency,
    targetDate,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalGoalRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.syncStatus == this.syncStatus &&
          other.pendingMutationId == this.pendingMutationId &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.cachedAt == this.cachedAt &&
          other.title == this.title &&
          other.category == this.category &&
          other.targetAmount == this.targetAmount &&
          other.currentAmount == this.currentAmount &&
          other.currency == this.currency &&
          other.targetDate == this.targetDate &&
          other.status == this.status);
}

class LocalGoalsCompanion extends UpdateCompanion<LocalGoalRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<LocalSyncStatus> syncStatus;
  final Value<String?> pendingMutationId;
  final Value<DateTime?> serverUpdatedAt;
  final Value<DateTime> cachedAt;
  final Value<String> title;
  final Value<String?> category;
  final Value<Decimal> targetAmount;
  final Value<Decimal> currentAmount;
  final Value<String> currency;
  final Value<DateTime?> targetDate;
  final Value<String> status;
  final Value<int> rowid;
  const LocalGoalsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.currentAmount = const Value.absent(),
    this.currency = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalGoalsCompanion.insert({
    required String id,
    required String tenantId,
    this.syncStatus = const Value.absent(),
    this.pendingMutationId = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    required String title,
    this.category = const Value.absent(),
    required Decimal targetAmount,
    required Decimal currentAmount,
    this.currency = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       title = Value(title),
       targetAmount = Value(targetAmount),
       currentAmount = Value(currentAmount);
  static Insertable<LocalGoalRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? syncStatus,
    Expression<String>? pendingMutationId,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? cachedAt,
    Expression<String>? title,
    Expression<String>? category,
    Expression<String>? targetAmount,
    Expression<String>? currentAmount,
    Expression<String>? currency,
    Expression<DateTime>? targetDate,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (pendingMutationId != null) 'pending_mutation_id': pendingMutationId,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (currentAmount != null) 'current_amount': currentAmount,
      if (currency != null) 'currency': currency,
      if (targetDate != null) 'target_date': targetDate,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalGoalsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<LocalSyncStatus>? syncStatus,
    Value<String?>? pendingMutationId,
    Value<DateTime?>? serverUpdatedAt,
    Value<DateTime>? cachedAt,
    Value<String>? title,
    Value<String?>? category,
    Value<Decimal>? targetAmount,
    Value<Decimal>? currentAmount,
    Value<String>? currency,
    Value<DateTime?>? targetDate,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return LocalGoalsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingMutationId: pendingMutationId ?? this.pendingMutationId,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      title: title ?? this.title,
      category: category ?? this.category,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      currency: currency ?? this.currency,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $LocalGoalsTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (pendingMutationId.present) {
      map['pending_mutation_id'] = Variable<String>(pendingMutationId.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<String>(
        $LocalGoalsTable.$convertertargetAmount.toSql(targetAmount.value),
      );
    }
    if (currentAmount.present) {
      map['current_amount'] = Variable<String>(
        $LocalGoalsTable.$convertercurrentAmount.toSql(currentAmount.value),
      );
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalGoalsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('pendingMutationId: $pendingMutationId, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('currency: $currency, ')
          ..write('targetDate: $targetDate, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('transaction'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxOperation, String>
  operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<OutboxOperation>($SyncOutboxTable.$converteroperation);
  static const VerificationMeta _entityLocalIdMeta = const VerificationMeta(
    'entityLocalId',
  );
  @override
  late final GeneratedColumn<String> entityLocalId = GeneratedColumn<String>(
    'entity_local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      ).withConverter<OutboxStatus>($SyncOutboxTable.$converterstatus);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mutationId,
    tenantId,
    entity,
    operation,
    entityLocalId,
    payload,
    status,
    attempts,
    lastError,
    lastAttemptAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    }
    if (data.containsKey('entity_local_id')) {
      context.handle(
        _entityLocalIdMeta,
        entityLocalId.isAcceptableOrUnknown(
          data['entity_local_id']!,
          _entityLocalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityLocalIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      operation: $SyncOutboxTable.$converteroperation.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}operation'],
        )!,
      ),
      entityLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_local_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      status: $SyncOutboxTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OutboxOperation, String, String>
  $converteroperation = const EnumNameConverter<OutboxOperation>(
    OutboxOperation.values,
  );
  static JsonTypeConverter2<OutboxStatus, String, String> $converterstatus =
      const EnumNameConverter<OutboxStatus>(OutboxStatus.values);
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int id;

  /// Client-generated UUID. Sent verbatim to `apply_transaction_mutation` on
  /// every retry so a lost response cannot double-apply (M1.5).
  final String mutationId;
  final String tenantId;
  final String entity;
  final OutboxOperation operation;

  /// The `id` of the cached row this entry affects.
  final String entityLocalId;

  /// The mutation envelope's `payload` object, as JSON. Null for a delete.
  final String? payload;
  final OutboxStatus status;
  final int attempts;
  final String? lastError;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;
  const OutboxEntry({
    required this.id,
    required this.mutationId,
    required this.tenantId,
    required this.entity,
    required this.operation,
    required this.entityLocalId,
    this.payload,
    required this.status,
    required this.attempts,
    this.lastError,
    this.lastAttemptAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mutation_id'] = Variable<String>(mutationId);
    map['tenant_id'] = Variable<String>(tenantId);
    map['entity'] = Variable<String>(entity);
    {
      map['operation'] = Variable<String>(
        $SyncOutboxTable.$converteroperation.toSql(operation),
      );
    }
    map['entity_local_id'] = Variable<String>(entityLocalId);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    {
      map['status'] = Variable<String>(
        $SyncOutboxTable.$converterstatus.toSql(status),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      mutationId: Value(mutationId),
      tenantId: Value(tenantId),
      entity: Value(entity),
      operation: Value(operation),
      entityLocalId: Value(entityLocalId),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      entity: serializer.fromJson<String>(json['entity']),
      operation: $SyncOutboxTable.$converteroperation.fromJson(
        serializer.fromJson<String>(json['operation']),
      ),
      entityLocalId: serializer.fromJson<String>(json['entityLocalId']),
      payload: serializer.fromJson<String?>(json['payload']),
      status: $SyncOutboxTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mutationId': serializer.toJson<String>(mutationId),
      'tenantId': serializer.toJson<String>(tenantId),
      'entity': serializer.toJson<String>(entity),
      'operation': serializer.toJson<String>(
        $SyncOutboxTable.$converteroperation.toJson(operation),
      ),
      'entityLocalId': serializer.toJson<String>(entityLocalId),
      'payload': serializer.toJson<String?>(payload),
      'status': serializer.toJson<String>(
        $SyncOutboxTable.$converterstatus.toJson(status),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxEntry copyWith({
    int? id,
    String? mutationId,
    String? tenantId,
    String? entity,
    OutboxOperation? operation,
    String? entityLocalId,
    Value<String?> payload = const Value.absent(),
    OutboxStatus? status,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxEntry(
    id: id ?? this.id,
    mutationId: mutationId ?? this.mutationId,
    tenantId: tenantId ?? this.tenantId,
    entity: entity ?? this.entity,
    operation: operation ?? this.operation,
    entityLocalId: entityLocalId ?? this.entityLocalId,
    payload: payload.present ? payload.value : this.payload,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxEntry copyWithCompanion(SyncOutboxCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      entity: data.entity.present ? data.entity.value : this.entity,
      operation: data.operation.present ? data.operation.value : this.operation,
      entityLocalId: data.entityLocalId.present
          ? data.entityLocalId.value
          : this.entityLocalId,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('mutationId: $mutationId, ')
          ..write('tenantId: $tenantId, ')
          ..write('entity: $entity, ')
          ..write('operation: $operation, ')
          ..write('entityLocalId: $entityLocalId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mutationId,
    tenantId,
    entity,
    operation,
    entityLocalId,
    payload,
    status,
    attempts,
    lastError,
    lastAttemptAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.mutationId == this.mutationId &&
          other.tenantId == this.tenantId &&
          other.entity == this.entity &&
          other.operation == this.operation &&
          other.entityLocalId == this.entityLocalId &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.createdAt == this.createdAt);
}

class SyncOutboxCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> id;
  final Value<String> mutationId;
  final Value<String> tenantId;
  final Value<String> entity;
  final Value<OutboxOperation> operation;
  final Value<String> entityLocalId;
  final Value<String?> payload;
  final Value<OutboxStatus> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime> createdAt;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.entity = const Value.absent(),
    this.operation = const Value.absent(),
    this.entityLocalId = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String mutationId,
    required String tenantId,
    this.entity = const Value.absent(),
    required OutboxOperation operation,
    required String entityLocalId,
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : mutationId = Value(mutationId),
       tenantId = Value(tenantId),
       operation = Value(operation),
       entityLocalId = Value(entityLocalId);
  static Insertable<OutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? mutationId,
    Expression<String>? tenantId,
    Expression<String>? entity,
    Expression<String>? operation,
    Expression<String>? entityLocalId,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mutationId != null) 'mutation_id': mutationId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (entity != null) 'entity': entity,
      if (operation != null) 'operation': operation,
      if (entityLocalId != null) 'entity_local_id': entityLocalId,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? mutationId,
    Value<String>? tenantId,
    Value<String>? entity,
    Value<OutboxOperation>? operation,
    Value<String>? entityLocalId,
    Value<String?>? payload,
    Value<OutboxStatus>? status,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime>? createdAt,
  }) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      mutationId: mutationId ?? this.mutationId,
      tenantId: tenantId ?? this.tenantId,
      entity: entity ?? this.entity,
      operation: operation ?? this.operation,
      entityLocalId: entityLocalId ?? this.entityLocalId,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(
        $SyncOutboxTable.$converteroperation.toSql(operation.value),
      );
    }
    if (entityLocalId.present) {
      map['entity_local_id'] = Variable<String>(entityLocalId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $SyncOutboxTable.$converterstatus.toSql(status.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('mutationId: $mutationId, ')
          ..write('tenantId: $tenantId, ')
          ..write('entity: $entity, ')
          ..write('operation: $operation, ')
          ..write('entityLocalId: $entityLocalId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<DateTime> cursor = GeneratedColumn<DateTime>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPulledAtMeta = const VerificationMeta(
    'lastPulledAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPulledAt = GeneratedColumn<DateTime>(
    'last_pulled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastFullSyncAtMeta = const VerificationMeta(
    'lastFullSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastFullSyncAt =
      GeneratedColumn<DateTime>(
        'last_full_sync_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    entity,
    tenantId,
    cursor,
    lastPulledAt,
    lastFullSyncAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('last_pulled_at')) {
      context.handle(
        _lastPulledAtMeta,
        lastPulledAt.isAcceptableOrUnknown(
          data['last_pulled_at']!,
          _lastPulledAtMeta,
        ),
      );
    }
    if (data.containsKey('last_full_sync_at')) {
      context.handle(
        _lastFullSyncAtMeta,
        lastFullSyncAt.isAcceptableOrUnknown(
          data['last_full_sync_at']!,
          _lastFullSyncAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cursor'],
      ),
      lastPulledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pulled_at'],
      ),
      lastFullSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_full_sync_at'],
      ),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  /// `<entity>:<tenantId>`, e.g. `transaction:6f1e…`.
  final String key;
  final String entity;
  final String tenantId;

  /// Highest `updated_at` pulled so far (ISO) — the `gt` bound for the next
  /// delta pull.
  final DateTime? cursor;
  final DateTime? lastPulledAt;
  final DateTime? lastFullSyncAt;
  const SyncStateRow({
    required this.key,
    required this.entity,
    required this.tenantId,
    this.cursor,
    this.lastPulledAt,
    this.lastFullSyncAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['entity'] = Variable<String>(entity);
    map['tenant_id'] = Variable<String>(tenantId);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<DateTime>(cursor);
    }
    if (!nullToAbsent || lastPulledAt != null) {
      map['last_pulled_at'] = Variable<DateTime>(lastPulledAt);
    }
    if (!nullToAbsent || lastFullSyncAt != null) {
      map['last_full_sync_at'] = Variable<DateTime>(lastFullSyncAt);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      key: Value(key),
      entity: Value(entity),
      tenantId: Value(tenantId),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
      lastPulledAt: lastPulledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPulledAt),
      lastFullSyncAt: lastFullSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFullSyncAt),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      key: serializer.fromJson<String>(json['key']),
      entity: serializer.fromJson<String>(json['entity']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      cursor: serializer.fromJson<DateTime?>(json['cursor']),
      lastPulledAt: serializer.fromJson<DateTime?>(json['lastPulledAt']),
      lastFullSyncAt: serializer.fromJson<DateTime?>(json['lastFullSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'entity': serializer.toJson<String>(entity),
      'tenantId': serializer.toJson<String>(tenantId),
      'cursor': serializer.toJson<DateTime?>(cursor),
      'lastPulledAt': serializer.toJson<DateTime?>(lastPulledAt),
      'lastFullSyncAt': serializer.toJson<DateTime?>(lastFullSyncAt),
    };
  }

  SyncStateRow copyWith({
    String? key,
    String? entity,
    String? tenantId,
    Value<DateTime?> cursor = const Value.absent(),
    Value<DateTime?> lastPulledAt = const Value.absent(),
    Value<DateTime?> lastFullSyncAt = const Value.absent(),
  }) => SyncStateRow(
    key: key ?? this.key,
    entity: entity ?? this.entity,
    tenantId: tenantId ?? this.tenantId,
    cursor: cursor.present ? cursor.value : this.cursor,
    lastPulledAt: lastPulledAt.present ? lastPulledAt.value : this.lastPulledAt,
    lastFullSyncAt: lastFullSyncAt.present
        ? lastFullSyncAt.value
        : this.lastFullSyncAt,
  );
  SyncStateRow copyWithCompanion(SyncStatesCompanion data) {
    return SyncStateRow(
      key: data.key.present ? data.key.value : this.key,
      entity: data.entity.present ? data.entity.value : this.entity,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastPulledAt: data.lastPulledAt.present
          ? data.lastPulledAt.value
          : this.lastPulledAt,
      lastFullSyncAt: data.lastFullSyncAt.present
          ? data.lastFullSyncAt.value
          : this.lastFullSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('key: $key, ')
          ..write('entity: $entity, ')
          ..write('tenantId: $tenantId, ')
          ..write('cursor: $cursor, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('lastFullSyncAt: $lastFullSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, entity, tenantId, cursor, lastPulledAt, lastFullSyncAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.key == this.key &&
          other.entity == this.entity &&
          other.tenantId == this.tenantId &&
          other.cursor == this.cursor &&
          other.lastPulledAt == this.lastPulledAt &&
          other.lastFullSyncAt == this.lastFullSyncAt);
}

class SyncStatesCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> key;
  final Value<String> entity;
  final Value<String> tenantId;
  final Value<DateTime?> cursor;
  final Value<DateTime?> lastPulledAt;
  final Value<DateTime?> lastFullSyncAt;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.key = const Value.absent(),
    this.entity = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.lastFullSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String key,
    required String entity,
    required String tenantId,
    this.cursor = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.lastFullSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       entity = Value(entity),
       tenantId = Value(tenantId);
  static Insertable<SyncStateRow> custom({
    Expression<String>? key,
    Expression<String>? entity,
    Expression<String>? tenantId,
    Expression<DateTime>? cursor,
    Expression<DateTime>? lastPulledAt,
    Expression<DateTime>? lastFullSyncAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (entity != null) 'entity': entity,
      if (tenantId != null) 'tenant_id': tenantId,
      if (cursor != null) 'cursor': cursor,
      if (lastPulledAt != null) 'last_pulled_at': lastPulledAt,
      if (lastFullSyncAt != null) 'last_full_sync_at': lastFullSyncAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? key,
    Value<String>? entity,
    Value<String>? tenantId,
    Value<DateTime?>? cursor,
    Value<DateTime?>? lastPulledAt,
    Value<DateTime?>? lastFullSyncAt,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      key: key ?? this.key,
      entity: entity ?? this.entity,
      tenantId: tenantId ?? this.tenantId,
      cursor: cursor ?? this.cursor,
      lastPulledAt: lastPulledAt ?? this.lastPulledAt,
      lastFullSyncAt: lastFullSyncAt ?? this.lastFullSyncAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<DateTime>(cursor.value);
    }
    if (lastPulledAt.present) {
      map['last_pulled_at'] = Variable<DateTime>(lastPulledAt.value);
    }
    if (lastFullSyncAt.present) {
      map['last_full_sync_at'] = Variable<DateTime>(lastFullSyncAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('key: $key, ')
          ..write('entity: $entity, ')
          ..write('tenantId: $tenantId, ')
          ..write('cursor: $cursor, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('lastFullSyncAt: $lastFullSyncAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KvCacheTable extends KvCache with TableInfo<$KvCacheTable, KvCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [scope, key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<KvCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, key};
  @override
  KvCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvCacheRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $KvCacheTable createAlias(String alias) {
    return $KvCacheTable(attachedDatabase, alias);
  }
}

class KvCacheRow extends DataClass implements Insertable<KvCacheRow> {
  final String scope;
  final String key;
  final String value;
  final DateTime updatedAt;
  const KvCacheRow({
    required this.scope,
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  KvCacheCompanion toCompanion(bool nullToAbsent) {
    return KvCacheCompanion(
      scope: Value(scope),
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory KvCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvCacheRow(
      scope: serializer.fromJson<String>(json['scope']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  KvCacheRow copyWith({
    String? scope,
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => KvCacheRow(
    scope: scope ?? this.scope,
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  KvCacheRow copyWithCompanion(KvCacheCompanion data) {
    return KvCacheRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvCacheRow(')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvCacheRow &&
          other.scope == this.scope &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class KvCacheCompanion extends UpdateCompanion<KvCacheRow> {
  final Value<String> scope;
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const KvCacheCompanion({
    this.scope = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvCacheCompanion.insert({
    required String scope,
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       key = Value(key),
       value = Value(value);
  static Insertable<KvCacheRow> custom({
    Expression<String>? scope,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvCacheCompanion copyWith({
    Value<String>? scope,
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return KvCacheCompanion(
      scope: scope ?? this.scope,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvCacheCompanion(')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalTransactionsTable localTransactions =
      $LocalTransactionsTable(this);
  late final $LocalAccountsTable localAccounts = $LocalAccountsTable(this);
  late final $LocalTrackersTable localTrackers = $LocalTrackersTable(this);
  late final $LocalBudgetsTable localBudgets = $LocalBudgetsTable(this);
  late final $LocalGoalsTable localGoals = $LocalGoalsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $KvCacheTable kvCache = $KvCacheTable(this);
  late final SyncOutboxDao syncOutboxDao = SyncOutboxDao(this as AppDatabase);
  late final SyncStateDao syncStateDao = SyncStateDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localTransactions,
    localAccounts,
    localTrackers,
    localBudgets,
    localGoals,
    syncOutbox,
    syncStates,
    kvCache,
  ];
}

typedef $$LocalTransactionsTableCreateCompanionBuilder =
    LocalTransactionsCompanion Function({
      required String id,
      required String tenantId,
      Value<LocalSyncStatus> syncStatus,
      Value<String?> pendingMutationId,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> cachedAt,
      Value<String?> userId,
      required String type,
      required Decimal amount,
      Value<String> currency,
      required String category,
      Value<String?> description,
      required DateTime occurredAt,
      Value<String?> accountId,
      Value<String?> paymentMode,
      Value<String?> transferToAccountId,
      Value<String?> trackerId,
      Value<DateTime?> serverCreatedAt,
      Value<int> rowid,
    });
typedef $$LocalTransactionsTableUpdateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<LocalSyncStatus> syncStatus,
      Value<String?> pendingMutationId,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> cachedAt,
      Value<String?> userId,
      Value<String> type,
      Value<Decimal> amount,
      Value<String> currency,
      Value<String> category,
      Value<String?> description,
      Value<DateTime> occurredAt,
      Value<String?> accountId,
      Value<String?> paymentMode,
      Value<String?> transferToAccountId,
      Value<String?> trackerId,
      Value<DateTime?> serverCreatedAt,
      Value<int> rowid,
    });

class $$LocalTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalSyncStatus, LocalSyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMode => $composableBuilder(
    column: $table.paymentMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferToAccountId => $composableBuilder(
    column: $table.transferToAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackerId => $composableBuilder(
    column: $table.trackerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMode => $composableBuilder(
    column: $table.paymentMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferToAccountId => $composableBuilder(
    column: $table.transferToAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackerId => $composableBuilder(
    column: $table.trackerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalSyncStatus, String> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get paymentMode => $composableBuilder(
    column: $table.paymentMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transferToAccountId => $composableBuilder(
    column: $table.transferToAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackerId =>
      $composableBuilder(column: $table.trackerId, builder: (column) => column);

  GeneratedColumn<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => column,
  );
}

class $$LocalTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransactionRow,
          $$LocalTransactionsTableFilterComposer,
          $$LocalTransactionsTableOrderingComposer,
          $$LocalTransactionsTableAnnotationComposer,
          $$LocalTransactionsTableCreateCompanionBuilder,
          $$LocalTransactionsTableUpdateCompanionBuilder,
          (
            LocalTransactionRow,
            BaseReferences<
              _$AppDatabase,
              $LocalTransactionsTable,
              LocalTransactionRow
            >,
          ),
          LocalTransactionRow,
          PrefetchHooks Function()
        > {
  $$LocalTransactionsTableTableManager(
    _$AppDatabase db,
    $LocalTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<Decimal> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> paymentMode = const Value.absent(),
                Value<String?> transferToAccountId = const Value.absent(),
                Value<String?> trackerId = const Value.absent(),
                Value<DateTime?> serverCreatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransactionsCompanion(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                userId: userId,
                type: type,
                amount: amount,
                currency: currency,
                category: category,
                description: description,
                occurredAt: occurredAt,
                accountId: accountId,
                paymentMode: paymentMode,
                transferToAccountId: transferToAccountId,
                trackerId: trackerId,
                serverCreatedAt: serverCreatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                required String type,
                required Decimal amount,
                Value<String> currency = const Value.absent(),
                required String category,
                Value<String?> description = const Value.absent(),
                required DateTime occurredAt,
                Value<String?> accountId = const Value.absent(),
                Value<String?> paymentMode = const Value.absent(),
                Value<String?> transferToAccountId = const Value.absent(),
                Value<String?> trackerId = const Value.absent(),
                Value<DateTime?> serverCreatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransactionsCompanion.insert(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                userId: userId,
                type: type,
                amount: amount,
                currency: currency,
                category: category,
                description: description,
                occurredAt: occurredAt,
                accountId: accountId,
                paymentMode: paymentMode,
                transferToAccountId: transferToAccountId,
                trackerId: trackerId,
                serverCreatedAt: serverCreatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalTransactionsTable, LocalTransactionRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalTransactionsTable,
                    LocalTransactionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTransactionsTable,
      LocalTransactionRow,
      $$LocalTransactionsTableFilterComposer,
      $$LocalTransactionsTableOrderingComposer,
      $$LocalTransactionsTableAnnotationComposer,
      $$LocalTransactionsTableCreateCompanionBuilder,
      $$LocalTransactionsTableUpdateCompanionBuilder,
      (
        LocalTransactionRow,
        BaseReferences<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransactionRow
        >,
      ),
      LocalTransactionRow,
      PrefetchHooks Function()
    >;
typedef $$LocalAccountsTableCreateCompanionBuilder =
    LocalAccountsCompanion Function({
      required String id,
      required String tenantId,
      Value<LocalSyncStatus> syncStatus,
      Value<String?> pendingMutationId,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> cachedAt,
      required String name,
      required String type,
      Value<Decimal?> openingBalance,
      Value<String?> color,
      Value<String?> icon,
      Value<int> rowid,
    });
typedef $$LocalAccountsTableUpdateCompanionBuilder =
    LocalAccountsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<LocalSyncStatus> syncStatus,
      Value<String?> pendingMutationId,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> cachedAt,
      Value<String> name,
      Value<String> type,
      Value<Decimal?> openingBalance,
      Value<String?> color,
      Value<String?> icon,
      Value<int> rowid,
    });

class $$LocalAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalSyncStatus, LocalSyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, String>
  get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalSyncStatus, String> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal?, String> get openingBalance =>
      $composableBuilder(
        column: $table.openingBalance,
        builder: (column) => column,
      );

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);
}

class $$LocalAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAccountsTable,
          LocalAccountRow,
          $$LocalAccountsTableFilterComposer,
          $$LocalAccountsTableOrderingComposer,
          $$LocalAccountsTableAnnotationComposer,
          $$LocalAccountsTableCreateCompanionBuilder,
          $$LocalAccountsTableUpdateCompanionBuilder,
          (
            LocalAccountRow,
            BaseReferences<_$AppDatabase, $LocalAccountsTable, LocalAccountRow>,
          ),
          LocalAccountRow,
          PrefetchHooks Function()
        > {
  $$LocalAccountsTableTableManager(_$AppDatabase db, $LocalAccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<Decimal?> openingBalance = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAccountsCompanion(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                name: name,
                type: type,
                openingBalance: openingBalance,
                color: color,
                icon: icon,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                required String name,
                required String type,
                Value<Decimal?> openingBalance = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAccountsCompanion.insert(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                name: name,
                type: type,
                openingBalance: openingBalance,
                color: color,
                icon: icon,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalAccountsTable, LocalAccountRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalAccountsTable,
                    LocalAccountRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAccountsTable,
      LocalAccountRow,
      $$LocalAccountsTableFilterComposer,
      $$LocalAccountsTableOrderingComposer,
      $$LocalAccountsTableAnnotationComposer,
      $$LocalAccountsTableCreateCompanionBuilder,
      $$LocalAccountsTableUpdateCompanionBuilder,
      (
        LocalAccountRow,
        BaseReferences<_$AppDatabase, $LocalAccountsTable, LocalAccountRow>,
      ),
      LocalAccountRow,
      PrefetchHooks Function()
    >;
typedef $$LocalTrackersTableCreateCompanionBuilder =
    LocalTrackersCompanion Function({
      required String id,
      required String tenantId,
      Value<LocalSyncStatus> syncStatus,
      Value<String?> pendingMutationId,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> cachedAt,
      required String name,
      required String type,
      required DateTime startDate,
      Value<DateTime?> endDate,
      Value<Decimal?> budget,
      Value<String?> description,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$LocalTrackersTableUpdateCompanionBuilder =
    LocalTrackersCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<LocalSyncStatus> syncStatus,
      Value<String?> pendingMutationId,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> cachedAt,
      Value<String> name,
      Value<String> type,
      Value<DateTime> startDate,
      Value<DateTime?> endDate,
      Value<Decimal?> budget,
      Value<String?> description,
      Value<String> status,
      Value<int> rowid,
    });

class $$LocalTrackersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTrackersTable> {
  $$LocalTrackersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalSyncStatus, LocalSyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, String> get budget =>
      $composableBuilder(
        column: $table.budget,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTrackersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTrackersTable> {
  $$LocalTrackersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budget => $composableBuilder(
    column: $table.budget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTrackersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTrackersTable> {
  $$LocalTrackersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalSyncStatus, String> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal?, String> get budget =>
      $composableBuilder(column: $table.budget, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$LocalTrackersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTrackersTable,
          LocalTrackerRow,
          $$LocalTrackersTableFilterComposer,
          $$LocalTrackersTableOrderingComposer,
          $$LocalTrackersTableAnnotationComposer,
          $$LocalTrackersTableCreateCompanionBuilder,
          $$LocalTrackersTableUpdateCompanionBuilder,
          (
            LocalTrackerRow,
            BaseReferences<_$AppDatabase, $LocalTrackersTable, LocalTrackerRow>,
          ),
          LocalTrackerRow,
          PrefetchHooks Function()
        > {
  $$LocalTrackersTableTableManager(_$AppDatabase db, $LocalTrackersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTrackersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTrackersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTrackersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<Decimal?> budget = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTrackersCompanion(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                name: name,
                type: type,
                startDate: startDate,
                endDate: endDate,
                budget: budget,
                description: description,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                required String name,
                required String type,
                required DateTime startDate,
                Value<DateTime?> endDate = const Value.absent(),
                Value<Decimal?> budget = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTrackersCompanion.insert(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                name: name,
                type: type,
                startDate: startDate,
                endDate: endDate,
                budget: budget,
                description: description,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalTrackersTable, LocalTrackerRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalTrackersTable,
                    LocalTrackerRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTrackersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTrackersTable,
      LocalTrackerRow,
      $$LocalTrackersTableFilterComposer,
      $$LocalTrackersTableOrderingComposer,
      $$LocalTrackersTableAnnotationComposer,
      $$LocalTrackersTableCreateCompanionBuilder,
      $$LocalTrackersTableUpdateCompanionBuilder,
      (
        LocalTrackerRow,
        BaseReferences<_$AppDatabase, $LocalTrackersTable, LocalTrackerRow>,
      ),
      LocalTrackerRow,
      PrefetchHooks Function()
    >;
typedef $$LocalBudgetsTableCreateCompanionBuilder =
    LocalBudgetsCompanion Function({
      required String id,
      required String tenantId,
      Value<LocalSyncStatus> syncStatus,
      Value<String?> pendingMutationId,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> cachedAt,
      required String bucket,
      required Decimal allocated,
      Value<String> period,
      required DateTime periodStart,
      Value<int> rowid,
    });
typedef $$LocalBudgetsTableUpdateCompanionBuilder =
    LocalBudgetsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<LocalSyncStatus> syncStatus,
      Value<String?> pendingMutationId,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> cachedAt,
      Value<String> bucket,
      Value<Decimal> allocated,
      Value<String> period,
      Value<DateTime> periodStart,
      Value<int> rowid,
    });

class $$LocalBudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBudgetsTable> {
  $$LocalBudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalSyncStatus, LocalSyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get allocated =>
      $composableBuilder(
        column: $table.allocated,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBudgetsTable> {
  $$LocalBudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allocated => $composableBuilder(
    column: $table.allocated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBudgetsTable> {
  $$LocalBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalSyncStatus, String> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get allocated =>
      $composableBuilder(column: $table.allocated, builder: (column) => column);

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<DateTime> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => column,
  );
}

class $$LocalBudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBudgetsTable,
          LocalBudgetRow,
          $$LocalBudgetsTableFilterComposer,
          $$LocalBudgetsTableOrderingComposer,
          $$LocalBudgetsTableAnnotationComposer,
          $$LocalBudgetsTableCreateCompanionBuilder,
          $$LocalBudgetsTableUpdateCompanionBuilder,
          (
            LocalBudgetRow,
            BaseReferences<_$AppDatabase, $LocalBudgetsTable, LocalBudgetRow>,
          ),
          LocalBudgetRow,
          PrefetchHooks Function()
        > {
  $$LocalBudgetsTableTableManager(_$AppDatabase db, $LocalBudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String> bucket = const Value.absent(),
                Value<Decimal> allocated = const Value.absent(),
                Value<String> period = const Value.absent(),
                Value<DateTime> periodStart = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalBudgetsCompanion(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                bucket: bucket,
                allocated: allocated,
                period: period,
                periodStart: periodStart,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                required String bucket,
                required Decimal allocated,
                Value<String> period = const Value.absent(),
                required DateTime periodStart,
                Value<int> rowid = const Value.absent(),
              }) => LocalBudgetsCompanion.insert(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                bucket: bucket,
                allocated: allocated,
                period: period,
                periodStart: periodStart,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalBudgetsTable, LocalBudgetRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalBudgetsTable,
                    LocalBudgetRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBudgetsTable,
      LocalBudgetRow,
      $$LocalBudgetsTableFilterComposer,
      $$LocalBudgetsTableOrderingComposer,
      $$LocalBudgetsTableAnnotationComposer,
      $$LocalBudgetsTableCreateCompanionBuilder,
      $$LocalBudgetsTableUpdateCompanionBuilder,
      (
        LocalBudgetRow,
        BaseReferences<_$AppDatabase, $LocalBudgetsTable, LocalBudgetRow>,
      ),
      LocalBudgetRow,
      PrefetchHooks Function()
    >;
typedef $$LocalGoalsTableCreateCompanionBuilder = LocalGoalsCompanion Function({
  required String id,
  required String tenantId,
  Value<LocalSyncStatus> syncStatus,
  Value<String?> pendingMutationId,
  Value<DateTime?> serverUpdatedAt,
  Value<DateTime> cachedAt,
  required String title,
  Value<String?> category,
  required Decimal targetAmount,
  required Decimal currentAmount,
  Value<String> currency,
  Value<DateTime?> targetDate,
  Value<String> status,
  Value<int> rowid,
});
typedef $$LocalGoalsTableUpdateCompanionBuilder = LocalGoalsCompanion Function({
  Value<String> id,
  Value<String> tenantId,
  Value<LocalSyncStatus> syncStatus,
  Value<String?> pendingMutationId,
  Value<DateTime?> serverUpdatedAt,
  Value<DateTime> cachedAt,
  Value<String> title,
  Value<String?> category,
  Value<Decimal> targetAmount,
  Value<Decimal> currentAmount,
  Value<String> currency,
  Value<DateTime?> targetDate,
  Value<String> status,
  Value<int> rowid,
});

class $$LocalGoalsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalGoalsTable> {
  $$LocalGoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalSyncStatus, LocalSyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get targetAmount =>
      $composableBuilder(
        column: $table.targetAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get currentAmount =>
      $composableBuilder(
        column: $table.currentAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalGoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalGoalsTable> {
  $$LocalGoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentAmount => $composableBuilder(
    column: $table.currentAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalGoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalGoalsTable> {
  $$LocalGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalSyncStatus, String> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get pendingMutationId => $composableBuilder(
    column: $table.pendingMutationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get targetAmount =>
      $composableBuilder(
        column: $table.targetAmount,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, String> get currentAmount =>
      $composableBuilder(
        column: $table.currentAmount,
        builder: (column) => column,
      );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$LocalGoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalGoalsTable,
          LocalGoalRow,
          $$LocalGoalsTableFilterComposer,
          $$LocalGoalsTableOrderingComposer,
          $$LocalGoalsTableAnnotationComposer,
          $$LocalGoalsTableCreateCompanionBuilder,
          $$LocalGoalsTableUpdateCompanionBuilder,
          (
            LocalGoalRow,
            BaseReferences<_$AppDatabase, $LocalGoalsTable, LocalGoalRow>,
          ),
          LocalGoalRow,
          PrefetchHooks Function()
        > {
  $$LocalGoalsTableTableManager(_$AppDatabase db, $LocalGoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalGoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<Decimal> targetAmount = const Value.absent(),
                Value<Decimal> currentAmount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalGoalsCompanion(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                title: title,
                category: category,
                targetAmount: targetAmount,
                currentAmount: currentAmount,
                currency: currency,
                targetDate: targetDate,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                Value<LocalSyncStatus> syncStatus = const Value.absent(),
                Value<String?> pendingMutationId = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                required String title,
                Value<String?> category = const Value.absent(),
                required Decimal targetAmount,
                required Decimal currentAmount,
                Value<String> currency = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalGoalsCompanion.insert(
                id: id,
                tenantId: tenantId,
                syncStatus: syncStatus,
                pendingMutationId: pendingMutationId,
                serverUpdatedAt: serverUpdatedAt,
                cachedAt: cachedAt,
                title: title,
                category: category,
                targetAmount: targetAmount,
                currentAmount: currentAmount,
                currency: currency,
                targetDate: targetDate,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalGoalsTable, LocalGoalRow>(table),
                  BaseReferences<_$AppDatabase, $LocalGoalsTable, LocalGoalRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalGoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalGoalsTable,
      LocalGoalRow,
      $$LocalGoalsTableFilterComposer,
      $$LocalGoalsTableOrderingComposer,
      $$LocalGoalsTableAnnotationComposer,
      $$LocalGoalsTableCreateCompanionBuilder,
      $$LocalGoalsTableUpdateCompanionBuilder,
      (
        LocalGoalRow,
        BaseReferences<_$AppDatabase, $LocalGoalsTable, LocalGoalRow>,
      ),
      LocalGoalRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> id,
  required String mutationId,
  required String tenantId,
  Value<String> entity,
  required OutboxOperation operation,
  required String entityLocalId,
  Value<String?> payload,
  Value<OutboxStatus> status,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime> createdAt,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> id,
  Value<String> mutationId,
  Value<String> tenantId,
  Value<String> entity,
  Value<OutboxOperation> operation,
  Value<String> entityLocalId,
  Value<String?> payload,
  Value<OutboxStatus> status,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime> createdAt,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxOperation, OutboxOperation, String>
  get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get entityLocalId => $composableBuilder(
    column: $table.entityLocalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxStatus, OutboxStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityLocalId => $composableBuilder(
    column: $table.entityLocalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OutboxOperation, String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get entityLocalId => $composableBuilder(
    column: $table.entityLocalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OutboxStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          OutboxEntry,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<OutboxOperation> operation = const Value.absent(),
                Value<String> entityLocalId = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<OutboxStatus> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncOutboxCompanion(
                id: id,
                mutationId: mutationId,
                tenantId: tenantId,
                entity: entity,
                operation: operation,
                entityLocalId: entityLocalId,
                payload: payload,
                status: status,
                attempts: attempts,
                lastError: lastError,
                lastAttemptAt: lastAttemptAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String mutationId,
                required String tenantId,
                Value<String> entity = const Value.absent(),
                required OutboxOperation operation,
                required String entityLocalId,
                Value<String?> payload = const Value.absent(),
                Value<OutboxStatus> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                id: id,
                mutationId: mutationId,
                tenantId: tenantId,
                entity: entity,
                operation: operation,
                entityLocalId: entityLocalId,
                payload: payload,
                status: status,
                attempts: attempts,
                lastError: lastError,
                lastAttemptAt: lastAttemptAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, OutboxEntry>(table),
                  BaseReferences<_$AppDatabase, $SyncOutboxTable, OutboxEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      OutboxEntry,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, OutboxEntry>,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  required String key,
  required String entity,
  required String tenantId,
  Value<DateTime?> cursor,
  Value<DateTime?> lastPulledAt,
  Value<DateTime?> lastFullSyncAt,
  Value<int> rowid,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<String> key,
  Value<String> entity,
  Value<String> tenantId,
  Value<DateTime?> cursor,
  Value<DateTime?> lastPulledAt,
  Value<DateTime?> lastFullSyncAt,
  Value<int> rowid,
});

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastFullSyncAt => $composableBuilder(
    column: $table.lastFullSyncAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastFullSyncAt => $composableBuilder(
    column: $table.lastFullSyncAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<DateTime> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastFullSyncAt => $composableBuilder(
    column: $table.lastFullSyncAt,
    builder: (column) => column,
  );
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncStateRow,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<DateTime?> cursor = const Value.absent(),
                Value<DateTime?> lastPulledAt = const Value.absent(),
                Value<DateTime?> lastFullSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                key: key,
                entity: entity,
                tenantId: tenantId,
                cursor: cursor,
                lastPulledAt: lastPulledAt,
                lastFullSyncAt: lastFullSyncAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String entity,
                required String tenantId,
                Value<DateTime?> cursor = const Value.absent(),
                Value<DateTime?> lastPulledAt = const Value.absent(),
                Value<DateTime?> lastFullSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                key: key,
                entity: entity,
                tenantId: tenantId,
                cursor: cursor,
                lastPulledAt: lastPulledAt,
                lastFullSyncAt: lastFullSyncAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStatesTable, SyncStateRow>(table),
                  BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncStateRow,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$KvCacheTableCreateCompanionBuilder = KvCacheCompanion Function({
  required String scope,
  required String key,
  required String value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$KvCacheTableUpdateCompanionBuilder = KvCacheCompanion Function({
  Value<String> scope,
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$KvCacheTableFilterComposer
    extends Composer<_$AppDatabase, $KvCacheTable> {
  $$KvCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KvCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $KvCacheTable> {
  $$KvCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KvCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $KvCacheTable> {
  $$KvCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$KvCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KvCacheTable,
          KvCacheRow,
          $$KvCacheTableFilterComposer,
          $$KvCacheTableOrderingComposer,
          $$KvCacheTableAnnotationComposer,
          $$KvCacheTableCreateCompanionBuilder,
          $$KvCacheTableUpdateCompanionBuilder,
          (
            KvCacheRow,
            BaseReferences<_$AppDatabase, $KvCacheTable, KvCacheRow>,
          ),
          KvCacheRow,
          PrefetchHooks Function()
        > {
  $$KvCacheTableTableManager(_$AppDatabase db, $KvCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvCacheCompanion(
                scope: scope,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvCacheCompanion.insert(
                scope: scope,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KvCacheTable, KvCacheRow>(table),
                  BaseReferences<_$AppDatabase, $KvCacheTable, KvCacheRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KvCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KvCacheTable,
      KvCacheRow,
      $$KvCacheTableFilterComposer,
      $$KvCacheTableOrderingComposer,
      $$KvCacheTableAnnotationComposer,
      $$KvCacheTableCreateCompanionBuilder,
      $$KvCacheTableUpdateCompanionBuilder,
      (KvCacheRow, BaseReferences<_$AppDatabase, $KvCacheTable, KvCacheRow>),
      KvCacheRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalTransactionsTableTableManager get localTransactions =>
      $$LocalTransactionsTableTableManager(_db, _db.localTransactions);
  $$LocalAccountsTableTableManager get localAccounts =>
      $$LocalAccountsTableTableManager(_db, _db.localAccounts);
  $$LocalTrackersTableTableManager get localTrackers =>
      $$LocalTrackersTableTableManager(_db, _db.localTrackers);
  $$LocalBudgetsTableTableManager get localBudgets =>
      $$LocalBudgetsTableTableManager(_db, _db.localBudgets);
  $$LocalGoalsTableTableManager get localGoals =>
      $$LocalGoalsTableTableManager(_db, _db.localGoals);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$KvCacheTableTableManager get kvCache =>
      $$KvCacheTableTableManager(_db, _db.kvCache);
}
