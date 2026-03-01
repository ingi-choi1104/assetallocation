// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PortfoliosTable extends Portfolios
    with TableInfo<$PortfoliosTable, PortfolioRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfoliosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _baseCurrencyMeta =
      const VerificationMeta('baseCurrency');
  @override
  late final GeneratedColumn<String> baseCurrency = GeneratedColumn<String>(
      'base_currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('KRW'));
  static const VerificationMeta _rebalancePeriodMeta =
      const VerificationMeta('rebalancePeriod');
  @override
  late final GeneratedColumn<String> rebalancePeriod = GeneratedColumn<String>(
      'rebalance_period', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nextRebalanceDateMeta =
      const VerificationMeta('nextRebalanceDate');
  @override
  late final GeneratedColumn<DateTime> nextRebalanceDate =
      GeneratedColumn<DateTime>('next_rebalance_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deviationThresholdMeta =
      const VerificationMeta('deviationThreshold');
  @override
  late final GeneratedColumn<double> deviationThreshold =
      GeneratedColumn<double>('deviation_threshold', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(5.0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        baseCurrency,
        rebalancePeriod,
        nextRebalanceDate,
        deviationThreshold,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'portfolios';
  @override
  VerificationContext validateIntegrity(Insertable<PortfolioRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('base_currency')) {
      context.handle(
          _baseCurrencyMeta,
          baseCurrency.isAcceptableOrUnknown(
              data['base_currency']!, _baseCurrencyMeta));
    }
    if (data.containsKey('rebalance_period')) {
      context.handle(
          _rebalancePeriodMeta,
          rebalancePeriod.isAcceptableOrUnknown(
              data['rebalance_period']!, _rebalancePeriodMeta));
    }
    if (data.containsKey('next_rebalance_date')) {
      context.handle(
          _nextRebalanceDateMeta,
          nextRebalanceDate.isAcceptableOrUnknown(
              data['next_rebalance_date']!, _nextRebalanceDateMeta));
    }
    if (data.containsKey('deviation_threshold')) {
      context.handle(
          _deviationThresholdMeta,
          deviationThreshold.isAcceptableOrUnknown(
              data['deviation_threshold']!, _deviationThresholdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PortfolioRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortfolioRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      baseCurrency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base_currency'])!,
      rebalancePeriod: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}rebalance_period']),
      nextRebalanceDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_rebalance_date']),
      deviationThreshold: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}deviation_threshold'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PortfoliosTable createAlias(String alias) {
    return $PortfoliosTable(attachedDatabase, alias);
  }
}

class PortfolioRecord extends DataClass implements Insertable<PortfolioRecord> {
  final int id;
  final String name;
  final String? description;
  final String baseCurrency;
  final String? rebalancePeriod;
  final DateTime? nextRebalanceDate;
  final double deviationThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PortfolioRecord(
      {required this.id,
      required this.name,
      this.description,
      required this.baseCurrency,
      this.rebalancePeriod,
      this.nextRebalanceDate,
      required this.deviationThreshold,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['base_currency'] = Variable<String>(baseCurrency);
    if (!nullToAbsent || rebalancePeriod != null) {
      map['rebalance_period'] = Variable<String>(rebalancePeriod);
    }
    if (!nullToAbsent || nextRebalanceDate != null) {
      map['next_rebalance_date'] = Variable<DateTime>(nextRebalanceDate);
    }
    map['deviation_threshold'] = Variable<double>(deviationThreshold);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PortfoliosCompanion toCompanion(bool nullToAbsent) {
    return PortfoliosCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      baseCurrency: Value(baseCurrency),
      rebalancePeriod: rebalancePeriod == null && nullToAbsent
          ? const Value.absent()
          : Value(rebalancePeriod),
      nextRebalanceDate: nextRebalanceDate == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRebalanceDate),
      deviationThreshold: Value(deviationThreshold),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PortfolioRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortfolioRecord(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      baseCurrency: serializer.fromJson<String>(json['baseCurrency']),
      rebalancePeriod: serializer.fromJson<String?>(json['rebalancePeriod']),
      nextRebalanceDate:
          serializer.fromJson<DateTime?>(json['nextRebalanceDate']),
      deviationThreshold:
          serializer.fromJson<double>(json['deviationThreshold']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'baseCurrency': serializer.toJson<String>(baseCurrency),
      'rebalancePeriod': serializer.toJson<String?>(rebalancePeriod),
      'nextRebalanceDate': serializer.toJson<DateTime?>(nextRebalanceDate),
      'deviationThreshold': serializer.toJson<double>(deviationThreshold),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PortfolioRecord copyWith(
          {int? id,
          String? name,
          Value<String?> description = const Value.absent(),
          String? baseCurrency,
          Value<String?> rebalancePeriod = const Value.absent(),
          Value<DateTime?> nextRebalanceDate = const Value.absent(),
          double? deviationThreshold,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      PortfolioRecord(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        baseCurrency: baseCurrency ?? this.baseCurrency,
        rebalancePeriod: rebalancePeriod.present
            ? rebalancePeriod.value
            : this.rebalancePeriod,
        nextRebalanceDate: nextRebalanceDate.present
            ? nextRebalanceDate.value
            : this.nextRebalanceDate,
        deviationThreshold: deviationThreshold ?? this.deviationThreshold,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PortfolioRecord copyWithCompanion(PortfoliosCompanion data) {
    return PortfolioRecord(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      baseCurrency: data.baseCurrency.present
          ? data.baseCurrency.value
          : this.baseCurrency,
      rebalancePeriod: data.rebalancePeriod.present
          ? data.rebalancePeriod.value
          : this.rebalancePeriod,
      nextRebalanceDate: data.nextRebalanceDate.present
          ? data.nextRebalanceDate.value
          : this.nextRebalanceDate,
      deviationThreshold: data.deviationThreshold.present
          ? data.deviationThreshold.value
          : this.deviationThreshold,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioRecord(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('rebalancePeriod: $rebalancePeriod, ')
          ..write('nextRebalanceDate: $nextRebalanceDate, ')
          ..write('deviationThreshold: $deviationThreshold, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      description,
      baseCurrency,
      rebalancePeriod,
      nextRebalanceDate,
      deviationThreshold,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortfolioRecord &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.baseCurrency == this.baseCurrency &&
          other.rebalancePeriod == this.rebalancePeriod &&
          other.nextRebalanceDate == this.nextRebalanceDate &&
          other.deviationThreshold == this.deviationThreshold &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PortfoliosCompanion extends UpdateCompanion<PortfolioRecord> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> baseCurrency;
  final Value<String?> rebalancePeriod;
  final Value<DateTime?> nextRebalanceDate;
  final Value<double> deviationThreshold;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PortfoliosCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.baseCurrency = const Value.absent(),
    this.rebalancePeriod = const Value.absent(),
    this.nextRebalanceDate = const Value.absent(),
    this.deviationThreshold = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PortfoliosCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.baseCurrency = const Value.absent(),
    this.rebalancePeriod = const Value.absent(),
    this.nextRebalanceDate = const Value.absent(),
    this.deviationThreshold = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<PortfolioRecord> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? baseCurrency,
    Expression<String>? rebalancePeriod,
    Expression<DateTime>? nextRebalanceDate,
    Expression<double>? deviationThreshold,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (baseCurrency != null) 'base_currency': baseCurrency,
      if (rebalancePeriod != null) 'rebalance_period': rebalancePeriod,
      if (nextRebalanceDate != null) 'next_rebalance_date': nextRebalanceDate,
      if (deviationThreshold != null) 'deviation_threshold': deviationThreshold,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PortfoliosCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<String>? baseCurrency,
      Value<String?>? rebalancePeriod,
      Value<DateTime?>? nextRebalanceDate,
      Value<double>? deviationThreshold,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return PortfoliosCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      rebalancePeriod: rebalancePeriod ?? this.rebalancePeriod,
      nextRebalanceDate: nextRebalanceDate ?? this.nextRebalanceDate,
      deviationThreshold: deviationThreshold ?? this.deviationThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (baseCurrency.present) {
      map['base_currency'] = Variable<String>(baseCurrency.value);
    }
    if (rebalancePeriod.present) {
      map['rebalance_period'] = Variable<String>(rebalancePeriod.value);
    }
    if (nextRebalanceDate.present) {
      map['next_rebalance_date'] = Variable<DateTime>(nextRebalanceDate.value);
    }
    if (deviationThreshold.present) {
      map['deviation_threshold'] = Variable<double>(deviationThreshold.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortfoliosCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('rebalancePeriod: $rebalancePeriod, ')
          ..write('nextRebalanceDate: $nextRebalanceDate, ')
          ..write('deviationThreshold: $deviationThreshold, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AssetsTable extends Assets with TableInfo<$AssetsTable, AssetRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
      'symbol', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _assetTypeMeta =
      const VerificationMeta('assetType');
  @override
  late final GeneratedColumn<String> assetType = GeneratedColumn<String>(
      'asset_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fundCodeMeta =
      const VerificationMeta('fundCode');
  @override
  late final GeneratedColumn<String> fundCode = GeneratedColumn<String>(
      'fund_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastPriceMeta =
      const VerificationMeta('lastPrice');
  @override
  late final GeneratedColumn<double> lastPrice = GeneratedColumn<double>(
      'last_price', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _lastPriceUpdatedAtMeta =
      const VerificationMeta('lastPriceUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> lastPriceUpdatedAt =
      GeneratedColumn<DateTime>('last_price_updated_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        symbol,
        name,
        assetType,
        currency,
        fundCode,
        lastPrice,
        lastPriceUpdatedAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assets';
  @override
  VerificationContext validateIntegrity(Insertable<AssetRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('symbol')) {
      context.handle(_symbolMeta,
          symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta));
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('asset_type')) {
      context.handle(_assetTypeMeta,
          assetType.isAcceptableOrUnknown(data['asset_type']!, _assetTypeMeta));
    } else if (isInserting) {
      context.missing(_assetTypeMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('fund_code')) {
      context.handle(_fundCodeMeta,
          fundCode.isAcceptableOrUnknown(data['fund_code']!, _fundCodeMeta));
    }
    if (data.containsKey('last_price')) {
      context.handle(_lastPriceMeta,
          lastPrice.isAcceptableOrUnknown(data['last_price']!, _lastPriceMeta));
    }
    if (data.containsKey('last_price_updated_at')) {
      context.handle(
          _lastPriceUpdatedAtMeta,
          lastPriceUpdatedAt.isAcceptableOrUnknown(
              data['last_price_updated_at']!, _lastPriceUpdatedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {symbol, assetType},
      ];
  @override
  AssetRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      symbol: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}symbol'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      assetType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}asset_type'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      fundCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fund_code']),
      lastPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}last_price']),
      lastPriceUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}last_price_updated_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AssetsTable createAlias(String alias) {
    return $AssetsTable(attachedDatabase, alias);
  }
}

class AssetRecord extends DataClass implements Insertable<AssetRecord> {
  final int id;
  final String symbol;
  final String name;
  final String assetType;
  final String currency;
  final String? fundCode;
  final double? lastPrice;
  final DateTime? lastPriceUpdatedAt;
  final DateTime createdAt;
  const AssetRecord(
      {required this.id,
      required this.symbol,
      required this.name,
      required this.assetType,
      required this.currency,
      this.fundCode,
      this.lastPrice,
      this.lastPriceUpdatedAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['symbol'] = Variable<String>(symbol);
    map['name'] = Variable<String>(name);
    map['asset_type'] = Variable<String>(assetType);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || fundCode != null) {
      map['fund_code'] = Variable<String>(fundCode);
    }
    if (!nullToAbsent || lastPrice != null) {
      map['last_price'] = Variable<double>(lastPrice);
    }
    if (!nullToAbsent || lastPriceUpdatedAt != null) {
      map['last_price_updated_at'] = Variable<DateTime>(lastPriceUpdatedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AssetsCompanion toCompanion(bool nullToAbsent) {
    return AssetsCompanion(
      id: Value(id),
      symbol: Value(symbol),
      name: Value(name),
      assetType: Value(assetType),
      currency: Value(currency),
      fundCode: fundCode == null && nullToAbsent
          ? const Value.absent()
          : Value(fundCode),
      lastPrice: lastPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPrice),
      lastPriceUpdatedAt: lastPriceUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPriceUpdatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory AssetRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetRecord(
      id: serializer.fromJson<int>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      name: serializer.fromJson<String>(json['name']),
      assetType: serializer.fromJson<String>(json['assetType']),
      currency: serializer.fromJson<String>(json['currency']),
      fundCode: serializer.fromJson<String?>(json['fundCode']),
      lastPrice: serializer.fromJson<double?>(json['lastPrice']),
      lastPriceUpdatedAt:
          serializer.fromJson<DateTime?>(json['lastPriceUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'symbol': serializer.toJson<String>(symbol),
      'name': serializer.toJson<String>(name),
      'assetType': serializer.toJson<String>(assetType),
      'currency': serializer.toJson<String>(currency),
      'fundCode': serializer.toJson<String?>(fundCode),
      'lastPrice': serializer.toJson<double?>(lastPrice),
      'lastPriceUpdatedAt': serializer.toJson<DateTime?>(lastPriceUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AssetRecord copyWith(
          {int? id,
          String? symbol,
          String? name,
          String? assetType,
          String? currency,
          Value<String?> fundCode = const Value.absent(),
          Value<double?> lastPrice = const Value.absent(),
          Value<DateTime?> lastPriceUpdatedAt = const Value.absent(),
          DateTime? createdAt}) =>
      AssetRecord(
        id: id ?? this.id,
        symbol: symbol ?? this.symbol,
        name: name ?? this.name,
        assetType: assetType ?? this.assetType,
        currency: currency ?? this.currency,
        fundCode: fundCode.present ? fundCode.value : this.fundCode,
        lastPrice: lastPrice.present ? lastPrice.value : this.lastPrice,
        lastPriceUpdatedAt: lastPriceUpdatedAt.present
            ? lastPriceUpdatedAt.value
            : this.lastPriceUpdatedAt,
        createdAt: createdAt ?? this.createdAt,
      );
  AssetRecord copyWithCompanion(AssetsCompanion data) {
    return AssetRecord(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      name: data.name.present ? data.name.value : this.name,
      assetType: data.assetType.present ? data.assetType.value : this.assetType,
      currency: data.currency.present ? data.currency.value : this.currency,
      fundCode: data.fundCode.present ? data.fundCode.value : this.fundCode,
      lastPrice: data.lastPrice.present ? data.lastPrice.value : this.lastPrice,
      lastPriceUpdatedAt: data.lastPriceUpdatedAt.present
          ? data.lastPriceUpdatedAt.value
          : this.lastPriceUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetRecord(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('assetType: $assetType, ')
          ..write('currency: $currency, ')
          ..write('fundCode: $fundCode, ')
          ..write('lastPrice: $lastPrice, ')
          ..write('lastPriceUpdatedAt: $lastPriceUpdatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, symbol, name, assetType, currency,
      fundCode, lastPrice, lastPriceUpdatedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetRecord &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.name == this.name &&
          other.assetType == this.assetType &&
          other.currency == this.currency &&
          other.fundCode == this.fundCode &&
          other.lastPrice == this.lastPrice &&
          other.lastPriceUpdatedAt == this.lastPriceUpdatedAt &&
          other.createdAt == this.createdAt);
}

class AssetsCompanion extends UpdateCompanion<AssetRecord> {
  final Value<int> id;
  final Value<String> symbol;
  final Value<String> name;
  final Value<String> assetType;
  final Value<String> currency;
  final Value<String?> fundCode;
  final Value<double?> lastPrice;
  final Value<DateTime?> lastPriceUpdatedAt;
  final Value<DateTime> createdAt;
  const AssetsCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.name = const Value.absent(),
    this.assetType = const Value.absent(),
    this.currency = const Value.absent(),
    this.fundCode = const Value.absent(),
    this.lastPrice = const Value.absent(),
    this.lastPriceUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AssetsCompanion.insert({
    this.id = const Value.absent(),
    required String symbol,
    required String name,
    required String assetType,
    required String currency,
    this.fundCode = const Value.absent(),
    this.lastPrice = const Value.absent(),
    this.lastPriceUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : symbol = Value(symbol),
        name = Value(name),
        assetType = Value(assetType),
        currency = Value(currency);
  static Insertable<AssetRecord> custom({
    Expression<int>? id,
    Expression<String>? symbol,
    Expression<String>? name,
    Expression<String>? assetType,
    Expression<String>? currency,
    Expression<String>? fundCode,
    Expression<double>? lastPrice,
    Expression<DateTime>? lastPriceUpdatedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (name != null) 'name': name,
      if (assetType != null) 'asset_type': assetType,
      if (currency != null) 'currency': currency,
      if (fundCode != null) 'fund_code': fundCode,
      if (lastPrice != null) 'last_price': lastPrice,
      if (lastPriceUpdatedAt != null)
        'last_price_updated_at': lastPriceUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AssetsCompanion copyWith(
      {Value<int>? id,
      Value<String>? symbol,
      Value<String>? name,
      Value<String>? assetType,
      Value<String>? currency,
      Value<String?>? fundCode,
      Value<double?>? lastPrice,
      Value<DateTime?>? lastPriceUpdatedAt,
      Value<DateTime>? createdAt}) {
    return AssetsCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      assetType: assetType ?? this.assetType,
      currency: currency ?? this.currency,
      fundCode: fundCode ?? this.fundCode,
      lastPrice: lastPrice ?? this.lastPrice,
      lastPriceUpdatedAt: lastPriceUpdatedAt ?? this.lastPriceUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (assetType.present) {
      map['asset_type'] = Variable<String>(assetType.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (fundCode.present) {
      map['fund_code'] = Variable<String>(fundCode.value);
    }
    if (lastPrice.present) {
      map['last_price'] = Variable<double>(lastPrice.value);
    }
    if (lastPriceUpdatedAt.present) {
      map['last_price_updated_at'] =
          Variable<DateTime>(lastPriceUpdatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetsCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('assetType: $assetType, ')
          ..write('currency: $currency, ')
          ..write('fundCode: $fundCode, ')
          ..write('lastPrice: $lastPrice, ')
          ..write('lastPriceUpdatedAt: $lastPriceUpdatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PortfolioAssetsTable extends PortfolioAssets
    with TableInfo<$PortfolioAssetsTable, PortfolioAssetRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfolioAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _portfolioIdMeta =
      const VerificationMeta('portfolioId');
  @override
  late final GeneratedColumn<int> portfolioId = GeneratedColumn<int>(
      'portfolio_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES portfolios (id)'));
  static const VerificationMeta _assetIdMeta =
      const VerificationMeta('assetId');
  @override
  late final GeneratedColumn<int> assetId = GeneratedColumn<int>(
      'asset_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES assets (id)'));
  static const VerificationMeta _targetWeightMeta =
      const VerificationMeta('targetWeight');
  @override
  late final GeneratedColumn<double> targetWeight = GeneratedColumn<double>(
      'target_weight', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, portfolioId, assetId, targetWeight, sortOrder, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'portfolio_assets';
  @override
  VerificationContext validateIntegrity(
      Insertable<PortfolioAssetRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('portfolio_id')) {
      context.handle(
          _portfolioIdMeta,
          portfolioId.isAcceptableOrUnknown(
              data['portfolio_id']!, _portfolioIdMeta));
    } else if (isInserting) {
      context.missing(_portfolioIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(_assetIdMeta,
          assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta));
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('target_weight')) {
      context.handle(
          _targetWeightMeta,
          targetWeight.isAcceptableOrUnknown(
              data['target_weight']!, _targetWeightMeta));
    } else if (isInserting) {
      context.missing(_targetWeightMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {portfolioId, assetId},
      ];
  @override
  PortfolioAssetRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortfolioAssetRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      portfolioId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}portfolio_id'])!,
      assetId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}asset_id'])!,
      targetWeight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}target_weight'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $PortfolioAssetsTable createAlias(String alias) {
    return $PortfolioAssetsTable(attachedDatabase, alias);
  }
}

class PortfolioAssetRecord extends DataClass
    implements Insertable<PortfolioAssetRecord> {
  final int id;
  final int portfolioId;
  final int assetId;
  final double targetWeight;
  final int sortOrder;
  final DateTime addedAt;
  const PortfolioAssetRecord(
      {required this.id,
      required this.portfolioId,
      required this.assetId,
      required this.targetWeight,
      required this.sortOrder,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['portfolio_id'] = Variable<int>(portfolioId);
    map['asset_id'] = Variable<int>(assetId);
    map['target_weight'] = Variable<double>(targetWeight);
    map['sort_order'] = Variable<int>(sortOrder);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  PortfolioAssetsCompanion toCompanion(bool nullToAbsent) {
    return PortfolioAssetsCompanion(
      id: Value(id),
      portfolioId: Value(portfolioId),
      assetId: Value(assetId),
      targetWeight: Value(targetWeight),
      sortOrder: Value(sortOrder),
      addedAt: Value(addedAt),
    );
  }

  factory PortfolioAssetRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortfolioAssetRecord(
      id: serializer.fromJson<int>(json['id']),
      portfolioId: serializer.fromJson<int>(json['portfolioId']),
      assetId: serializer.fromJson<int>(json['assetId']),
      targetWeight: serializer.fromJson<double>(json['targetWeight']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'portfolioId': serializer.toJson<int>(portfolioId),
      'assetId': serializer.toJson<int>(assetId),
      'targetWeight': serializer.toJson<double>(targetWeight),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  PortfolioAssetRecord copyWith(
          {int? id,
          int? portfolioId,
          int? assetId,
          double? targetWeight,
          int? sortOrder,
          DateTime? addedAt}) =>
      PortfolioAssetRecord(
        id: id ?? this.id,
        portfolioId: portfolioId ?? this.portfolioId,
        assetId: assetId ?? this.assetId,
        targetWeight: targetWeight ?? this.targetWeight,
        sortOrder: sortOrder ?? this.sortOrder,
        addedAt: addedAt ?? this.addedAt,
      );
  PortfolioAssetRecord copyWithCompanion(PortfolioAssetsCompanion data) {
    return PortfolioAssetRecord(
      id: data.id.present ? data.id.value : this.id,
      portfolioId:
          data.portfolioId.present ? data.portfolioId.value : this.portfolioId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      targetWeight: data.targetWeight.present
          ? data.targetWeight.value
          : this.targetWeight,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioAssetRecord(')
          ..write('id: $id, ')
          ..write('portfolioId: $portfolioId, ')
          ..write('assetId: $assetId, ')
          ..write('targetWeight: $targetWeight, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, portfolioId, assetId, targetWeight, sortOrder, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortfolioAssetRecord &&
          other.id == this.id &&
          other.portfolioId == this.portfolioId &&
          other.assetId == this.assetId &&
          other.targetWeight == this.targetWeight &&
          other.sortOrder == this.sortOrder &&
          other.addedAt == this.addedAt);
}

class PortfolioAssetsCompanion extends UpdateCompanion<PortfolioAssetRecord> {
  final Value<int> id;
  final Value<int> portfolioId;
  final Value<int> assetId;
  final Value<double> targetWeight;
  final Value<int> sortOrder;
  final Value<DateTime> addedAt;
  const PortfolioAssetsCompanion({
    this.id = const Value.absent(),
    this.portfolioId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.targetWeight = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  PortfolioAssetsCompanion.insert({
    this.id = const Value.absent(),
    required int portfolioId,
    required int assetId,
    required double targetWeight,
    this.sortOrder = const Value.absent(),
    this.addedAt = const Value.absent(),
  })  : portfolioId = Value(portfolioId),
        assetId = Value(assetId),
        targetWeight = Value(targetWeight);
  static Insertable<PortfolioAssetRecord> custom({
    Expression<int>? id,
    Expression<int>? portfolioId,
    Expression<int>? assetId,
    Expression<double>? targetWeight,
    Expression<int>? sortOrder,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (portfolioId != null) 'portfolio_id': portfolioId,
      if (assetId != null) 'asset_id': assetId,
      if (targetWeight != null) 'target_weight': targetWeight,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  PortfolioAssetsCompanion copyWith(
      {Value<int>? id,
      Value<int>? portfolioId,
      Value<int>? assetId,
      Value<double>? targetWeight,
      Value<int>? sortOrder,
      Value<DateTime>? addedAt}) {
    return PortfolioAssetsCompanion(
      id: id ?? this.id,
      portfolioId: portfolioId ?? this.portfolioId,
      assetId: assetId ?? this.assetId,
      targetWeight: targetWeight ?? this.targetWeight,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (portfolioId.present) {
      map['portfolio_id'] = Variable<int>(portfolioId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<int>(assetId.value);
    }
    if (targetWeight.present) {
      map['target_weight'] = Variable<double>(targetWeight.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioAssetsCompanion(')
          ..write('id: $id, ')
          ..write('portfolioId: $portfolioId, ')
          ..write('assetId: $assetId, ')
          ..write('targetWeight: $targetWeight, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, TransactionRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _portfolioAssetIdMeta =
      const VerificationMeta('portfolioAssetId');
  @override
  late final GeneratedColumn<int> portfolioAssetId = GeneratedColumn<int>(
      'portfolio_asset_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES portfolio_assets (id)'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
      'price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _exchangeRateMeta =
      const VerificationMeta('exchangeRate');
  @override
  late final GeneratedColumn<double> exchangeRate = GeneratedColumn<double>(
      'exchange_rate', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _feeMeta = const VerificationMeta('fee');
  @override
  late final GeneratedColumn<double> fee = GeneratedColumn<double>(
      'fee', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _transactionDateMeta =
      const VerificationMeta('transactionDate');
  @override
  late final GeneratedColumn<DateTime> transactionDate =
      GeneratedColumn<DateTime>('transaction_date', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
      'memo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        portfolioAssetId,
        type,
        quantity,
        price,
        exchangeRate,
        fee,
        transactionDate,
        memo,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(Insertable<TransactionRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('portfolio_asset_id')) {
      context.handle(
          _portfolioAssetIdMeta,
          portfolioAssetId.isAcceptableOrUnknown(
              data['portfolio_asset_id']!, _portfolioAssetIdMeta));
    } else if (isInserting) {
      context.missing(_portfolioAssetIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
          _priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('exchange_rate')) {
      context.handle(
          _exchangeRateMeta,
          exchangeRate.isAcceptableOrUnknown(
              data['exchange_rate']!, _exchangeRateMeta));
    }
    if (data.containsKey('fee')) {
      context.handle(
          _feeMeta, fee.isAcceptableOrUnknown(data['fee']!, _feeMeta));
    }
    if (data.containsKey('transaction_date')) {
      context.handle(
          _transactionDateMeta,
          transactionDate.isAcceptableOrUnknown(
              data['transaction_date']!, _transactionDateMeta));
    } else if (isInserting) {
      context.missing(_transactionDateMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
          _memoMeta, memo.isAcceptableOrUnknown(data['memo']!, _memoMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      portfolioAssetId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}portfolio_asset_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      price: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price'])!,
      exchangeRate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}exchange_rate'])!,
      fee: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fee'])!,
      transactionDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}transaction_date'])!,
      memo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memo']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class TransactionRecord extends DataClass
    implements Insertable<TransactionRecord> {
  final int id;
  final int portfolioAssetId;
  final String type;
  final double quantity;
  final double price;
  final double exchangeRate;
  final double fee;
  final DateTime transactionDate;
  final String? memo;
  final DateTime createdAt;
  const TransactionRecord(
      {required this.id,
      required this.portfolioAssetId,
      required this.type,
      required this.quantity,
      required this.price,
      required this.exchangeRate,
      required this.fee,
      required this.transactionDate,
      this.memo,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['portfolio_asset_id'] = Variable<int>(portfolioAssetId);
    map['type'] = Variable<String>(type);
    map['quantity'] = Variable<double>(quantity);
    map['price'] = Variable<double>(price);
    map['exchange_rate'] = Variable<double>(exchangeRate);
    map['fee'] = Variable<double>(fee);
    map['transaction_date'] = Variable<DateTime>(transactionDate);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      portfolioAssetId: Value(portfolioAssetId),
      type: Value(type),
      quantity: Value(quantity),
      price: Value(price),
      exchangeRate: Value(exchangeRate),
      fee: Value(fee),
      transactionDate: Value(transactionDate),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      createdAt: Value(createdAt),
    );
  }

  factory TransactionRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionRecord(
      id: serializer.fromJson<int>(json['id']),
      portfolioAssetId: serializer.fromJson<int>(json['portfolioAssetId']),
      type: serializer.fromJson<String>(json['type']),
      quantity: serializer.fromJson<double>(json['quantity']),
      price: serializer.fromJson<double>(json['price']),
      exchangeRate: serializer.fromJson<double>(json['exchangeRate']),
      fee: serializer.fromJson<double>(json['fee']),
      transactionDate: serializer.fromJson<DateTime>(json['transactionDate']),
      memo: serializer.fromJson<String?>(json['memo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'portfolioAssetId': serializer.toJson<int>(portfolioAssetId),
      'type': serializer.toJson<String>(type),
      'quantity': serializer.toJson<double>(quantity),
      'price': serializer.toJson<double>(price),
      'exchangeRate': serializer.toJson<double>(exchangeRate),
      'fee': serializer.toJson<double>(fee),
      'transactionDate': serializer.toJson<DateTime>(transactionDate),
      'memo': serializer.toJson<String?>(memo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TransactionRecord copyWith(
          {int? id,
          int? portfolioAssetId,
          String? type,
          double? quantity,
          double? price,
          double? exchangeRate,
          double? fee,
          DateTime? transactionDate,
          Value<String?> memo = const Value.absent(),
          DateTime? createdAt}) =>
      TransactionRecord(
        id: id ?? this.id,
        portfolioAssetId: portfolioAssetId ?? this.portfolioAssetId,
        type: type ?? this.type,
        quantity: quantity ?? this.quantity,
        price: price ?? this.price,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        fee: fee ?? this.fee,
        transactionDate: transactionDate ?? this.transactionDate,
        memo: memo.present ? memo.value : this.memo,
        createdAt: createdAt ?? this.createdAt,
      );
  TransactionRecord copyWithCompanion(TransactionsCompanion data) {
    return TransactionRecord(
      id: data.id.present ? data.id.value : this.id,
      portfolioAssetId: data.portfolioAssetId.present
          ? data.portfolioAssetId.value
          : this.portfolioAssetId,
      type: data.type.present ? data.type.value : this.type,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      price: data.price.present ? data.price.value : this.price,
      exchangeRate: data.exchangeRate.present
          ? data.exchangeRate.value
          : this.exchangeRate,
      fee: data.fee.present ? data.fee.value : this.fee,
      transactionDate: data.transactionDate.present
          ? data.transactionDate.value
          : this.transactionDate,
      memo: data.memo.present ? data.memo.value : this.memo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionRecord(')
          ..write('id: $id, ')
          ..write('portfolioAssetId: $portfolioAssetId, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('fee: $fee, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, portfolioAssetId, type, quantity, price,
      exchangeRate, fee, transactionDate, memo, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionRecord &&
          other.id == this.id &&
          other.portfolioAssetId == this.portfolioAssetId &&
          other.type == this.type &&
          other.quantity == this.quantity &&
          other.price == this.price &&
          other.exchangeRate == this.exchangeRate &&
          other.fee == this.fee &&
          other.transactionDate == this.transactionDate &&
          other.memo == this.memo &&
          other.createdAt == this.createdAt);
}

class TransactionsCompanion extends UpdateCompanion<TransactionRecord> {
  final Value<int> id;
  final Value<int> portfolioAssetId;
  final Value<String> type;
  final Value<double> quantity;
  final Value<double> price;
  final Value<double> exchangeRate;
  final Value<double> fee;
  final Value<DateTime> transactionDate;
  final Value<String?> memo;
  final Value<DateTime> createdAt;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.portfolioAssetId = const Value.absent(),
    this.type = const Value.absent(),
    this.quantity = const Value.absent(),
    this.price = const Value.absent(),
    this.exchangeRate = const Value.absent(),
    this.fee = const Value.absent(),
    this.transactionDate = const Value.absent(),
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int portfolioAssetId,
    required String type,
    required double quantity,
    required double price,
    this.exchangeRate = const Value.absent(),
    this.fee = const Value.absent(),
    required DateTime transactionDate,
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : portfolioAssetId = Value(portfolioAssetId),
        type = Value(type),
        quantity = Value(quantity),
        price = Value(price),
        transactionDate = Value(transactionDate);
  static Insertable<TransactionRecord> custom({
    Expression<int>? id,
    Expression<int>? portfolioAssetId,
    Expression<String>? type,
    Expression<double>? quantity,
    Expression<double>? price,
    Expression<double>? exchangeRate,
    Expression<double>? fee,
    Expression<DateTime>? transactionDate,
    Expression<String>? memo,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (portfolioAssetId != null) 'portfolio_asset_id': portfolioAssetId,
      if (type != null) 'type': type,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
      if (exchangeRate != null) 'exchange_rate': exchangeRate,
      if (fee != null) 'fee': fee,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (memo != null) 'memo': memo,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TransactionsCompanion copyWith(
      {Value<int>? id,
      Value<int>? portfolioAssetId,
      Value<String>? type,
      Value<double>? quantity,
      Value<double>? price,
      Value<double>? exchangeRate,
      Value<double>? fee,
      Value<DateTime>? transactionDate,
      Value<String?>? memo,
      Value<DateTime>? createdAt}) {
    return TransactionsCompanion(
      id: id ?? this.id,
      portfolioAssetId: portfolioAssetId ?? this.portfolioAssetId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      fee: fee ?? this.fee,
      transactionDate: transactionDate ?? this.transactionDate,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (portfolioAssetId.present) {
      map['portfolio_asset_id'] = Variable<int>(portfolioAssetId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (exchangeRate.present) {
      map['exchange_rate'] = Variable<double>(exchangeRate.value);
    }
    if (fee.present) {
      map['fee'] = Variable<double>(fee.value);
    }
    if (transactionDate.present) {
      map['transaction_date'] = Variable<DateTime>(transactionDate.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('portfolioAssetId: $portfolioAssetId, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('fee: $fee, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PriceHistoryTable extends PriceHistory
    with TableInfo<$PriceHistoryTable, PriceHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriceHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _assetIdMeta =
      const VerificationMeta('assetId');
  @override
  late final GeneratedColumn<int> assetId = GeneratedColumn<int>(
      'asset_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES assets (id)'));
  static const VerificationMeta _closePriceMeta =
      const VerificationMeta('closePrice');
  @override
  late final GeneratedColumn<double> closePrice = GeneratedColumn<double>(
      'close_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, assetId, closePrice, date, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'price_history';
  @override
  VerificationContext validateIntegrity(Insertable<PriceHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('asset_id')) {
      context.handle(_assetIdMeta,
          assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta));
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('close_price')) {
      context.handle(
          _closePriceMeta,
          closePrice.isAcceptableOrUnknown(
              data['close_price']!, _closePriceMeta));
    } else if (isInserting) {
      context.missing(_closePriceMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {assetId, date},
      ];
  @override
  PriceHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceHistoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      assetId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}asset_id'])!,
      closePrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}close_price'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $PriceHistoryTable createAlias(String alias) {
    return $PriceHistoryTable(attachedDatabase, alias);
  }
}

class PriceHistoryData extends DataClass
    implements Insertable<PriceHistoryData> {
  final int id;
  final int assetId;
  final double closePrice;
  final DateTime date;
  final DateTime fetchedAt;
  const PriceHistoryData(
      {required this.id,
      required this.assetId,
      required this.closePrice,
      required this.date,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['asset_id'] = Variable<int>(assetId);
    map['close_price'] = Variable<double>(closePrice);
    map['date'] = Variable<DateTime>(date);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  PriceHistoryCompanion toCompanion(bool nullToAbsent) {
    return PriceHistoryCompanion(
      id: Value(id),
      assetId: Value(assetId),
      closePrice: Value(closePrice),
      date: Value(date),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory PriceHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceHistoryData(
      id: serializer.fromJson<int>(json['id']),
      assetId: serializer.fromJson<int>(json['assetId']),
      closePrice: serializer.fromJson<double>(json['closePrice']),
      date: serializer.fromJson<DateTime>(json['date']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'assetId': serializer.toJson<int>(assetId),
      'closePrice': serializer.toJson<double>(closePrice),
      'date': serializer.toJson<DateTime>(date),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  PriceHistoryData copyWith(
          {int? id,
          int? assetId,
          double? closePrice,
          DateTime? date,
          DateTime? fetchedAt}) =>
      PriceHistoryData(
        id: id ?? this.id,
        assetId: assetId ?? this.assetId,
        closePrice: closePrice ?? this.closePrice,
        date: date ?? this.date,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  PriceHistoryData copyWithCompanion(PriceHistoryCompanion data) {
    return PriceHistoryData(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      closePrice:
          data.closePrice.present ? data.closePrice.value : this.closePrice,
      date: data.date.present ? data.date.value : this.date,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceHistoryData(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('closePrice: $closePrice, ')
          ..write('date: $date, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, assetId, closePrice, date, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceHistoryData &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.closePrice == this.closePrice &&
          other.date == this.date &&
          other.fetchedAt == this.fetchedAt);
}

class PriceHistoryCompanion extends UpdateCompanion<PriceHistoryData> {
  final Value<int> id;
  final Value<int> assetId;
  final Value<double> closePrice;
  final Value<DateTime> date;
  final Value<DateTime> fetchedAt;
  const PriceHistoryCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.closePrice = const Value.absent(),
    this.date = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  PriceHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int assetId,
    required double closePrice,
    required DateTime date,
    this.fetchedAt = const Value.absent(),
  })  : assetId = Value(assetId),
        closePrice = Value(closePrice),
        date = Value(date);
  static Insertable<PriceHistoryData> custom({
    Expression<int>? id,
    Expression<int>? assetId,
    Expression<double>? closePrice,
    Expression<DateTime>? date,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (closePrice != null) 'close_price': closePrice,
      if (date != null) 'date': date,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  PriceHistoryCompanion copyWith(
      {Value<int>? id,
      Value<int>? assetId,
      Value<double>? closePrice,
      Value<DateTime>? date,
      Value<DateTime>? fetchedAt}) {
    return PriceHistoryCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      closePrice: closePrice ?? this.closePrice,
      date: date ?? this.date,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<int>(assetId.value);
    }
    if (closePrice.present) {
      map['close_price'] = Variable<double>(closePrice.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PriceHistoryCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('closePrice: $closePrice, ')
          ..write('date: $date, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

class $InvestmentsTable extends Investments
    with TableInfo<$InvestmentsTable, InvestmentRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvestmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _portfolioIdMeta =
      const VerificationMeta('portfolioId');
  @override
  late final GeneratedColumn<int> portfolioId = GeneratedColumn<int>(
      'portfolio_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES portfolios (id)'));
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _investmentDateMeta =
      const VerificationMeta('investmentDate');
  @override
  late final GeneratedColumn<DateTime> investmentDate =
      GeneratedColumn<DateTime>('investment_date', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
      'memo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, portfolioId, amount, investmentDate, memo, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'investments';
  @override
  VerificationContext validateIntegrity(Insertable<InvestmentRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('portfolio_id')) {
      context.handle(
          _portfolioIdMeta,
          portfolioId.isAcceptableOrUnknown(
              data['portfolio_id']!, _portfolioIdMeta));
    } else if (isInserting) {
      context.missing(_portfolioIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('investment_date')) {
      context.handle(
          _investmentDateMeta,
          investmentDate.isAcceptableOrUnknown(
              data['investment_date']!, _investmentDateMeta));
    } else if (isInserting) {
      context.missing(_investmentDateMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
          _memoMeta, memo.isAcceptableOrUnknown(data['memo']!, _memoMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvestmentRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvestmentRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      portfolioId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}portfolio_id'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      investmentDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}investment_date'])!,
      memo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}memo']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $InvestmentsTable createAlias(String alias) {
    return $InvestmentsTable(attachedDatabase, alias);
  }
}

class InvestmentRecord extends DataClass
    implements Insertable<InvestmentRecord> {
  final int id;
  final int portfolioId;
  final double amount;
  final DateTime investmentDate;
  final String? memo;
  final DateTime createdAt;
  const InvestmentRecord(
      {required this.id,
      required this.portfolioId,
      required this.amount,
      required this.investmentDate,
      this.memo,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['portfolio_id'] = Variable<int>(portfolioId);
    map['amount'] = Variable<double>(amount);
    map['investment_date'] = Variable<DateTime>(investmentDate);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  InvestmentsCompanion toCompanion(bool nullToAbsent) {
    return InvestmentsCompanion(
      id: Value(id),
      portfolioId: Value(portfolioId),
      amount: Value(amount),
      investmentDate: Value(investmentDate),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      createdAt: Value(createdAt),
    );
  }

  factory InvestmentRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvestmentRecord(
      id: serializer.fromJson<int>(json['id']),
      portfolioId: serializer.fromJson<int>(json['portfolioId']),
      amount: serializer.fromJson<double>(json['amount']),
      investmentDate: serializer.fromJson<DateTime>(json['investmentDate']),
      memo: serializer.fromJson<String?>(json['memo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'portfolioId': serializer.toJson<int>(portfolioId),
      'amount': serializer.toJson<double>(amount),
      'investmentDate': serializer.toJson<DateTime>(investmentDate),
      'memo': serializer.toJson<String?>(memo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  InvestmentRecord copyWith(
          {int? id,
          int? portfolioId,
          double? amount,
          DateTime? investmentDate,
          Value<String?> memo = const Value.absent(),
          DateTime? createdAt}) =>
      InvestmentRecord(
        id: id ?? this.id,
        portfolioId: portfolioId ?? this.portfolioId,
        amount: amount ?? this.amount,
        investmentDate: investmentDate ?? this.investmentDate,
        memo: memo.present ? memo.value : this.memo,
        createdAt: createdAt ?? this.createdAt,
      );
  InvestmentRecord copyWithCompanion(InvestmentsCompanion data) {
    return InvestmentRecord(
      id: data.id.present ? data.id.value : this.id,
      portfolioId:
          data.portfolioId.present ? data.portfolioId.value : this.portfolioId,
      amount: data.amount.present ? data.amount.value : this.amount,
      investmentDate: data.investmentDate.present
          ? data.investmentDate.value
          : this.investmentDate,
      memo: data.memo.present ? data.memo.value : this.memo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentRecord(')
          ..write('id: $id, ')
          ..write('portfolioId: $portfolioId, ')
          ..write('amount: $amount, ')
          ..write('investmentDate: $investmentDate, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, portfolioId, amount, investmentDate, memo, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvestmentRecord &&
          other.id == this.id &&
          other.portfolioId == this.portfolioId &&
          other.amount == this.amount &&
          other.investmentDate == this.investmentDate &&
          other.memo == this.memo &&
          other.createdAt == this.createdAt);
}

class InvestmentsCompanion extends UpdateCompanion<InvestmentRecord> {
  final Value<int> id;
  final Value<int> portfolioId;
  final Value<double> amount;
  final Value<DateTime> investmentDate;
  final Value<String?> memo;
  final Value<DateTime> createdAt;
  const InvestmentsCompanion({
    this.id = const Value.absent(),
    this.portfolioId = const Value.absent(),
    this.amount = const Value.absent(),
    this.investmentDate = const Value.absent(),
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  InvestmentsCompanion.insert({
    this.id = const Value.absent(),
    required int portfolioId,
    required double amount,
    required DateTime investmentDate,
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : portfolioId = Value(portfolioId),
        amount = Value(amount),
        investmentDate = Value(investmentDate);
  static Insertable<InvestmentRecord> custom({
    Expression<int>? id,
    Expression<int>? portfolioId,
    Expression<double>? amount,
    Expression<DateTime>? investmentDate,
    Expression<String>? memo,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (portfolioId != null) 'portfolio_id': portfolioId,
      if (amount != null) 'amount': amount,
      if (investmentDate != null) 'investment_date': investmentDate,
      if (memo != null) 'memo': memo,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  InvestmentsCompanion copyWith(
      {Value<int>? id,
      Value<int>? portfolioId,
      Value<double>? amount,
      Value<DateTime>? investmentDate,
      Value<String?>? memo,
      Value<DateTime>? createdAt}) {
    return InvestmentsCompanion(
      id: id ?? this.id,
      portfolioId: portfolioId ?? this.portfolioId,
      amount: amount ?? this.amount,
      investmentDate: investmentDate ?? this.investmentDate,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (portfolioId.present) {
      map['portfolio_id'] = Variable<int>(portfolioId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (investmentDate.present) {
      map['investment_date'] = Variable<DateTime>(investmentDate.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvestmentsCompanion(')
          ..write('id: $id, ')
          ..write('portfolioId: $portfolioId, ')
          ..write('amount: $amount, ')
          ..write('investmentDate: $investmentDate, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PortfoliosTable portfolios = $PortfoliosTable(this);
  late final $AssetsTable assets = $AssetsTable(this);
  late final $PortfolioAssetsTable portfolioAssets =
      $PortfolioAssetsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $PriceHistoryTable priceHistory = $PriceHistoryTable(this);
  late final $InvestmentsTable investments = $InvestmentsTable(this);
  late final PortfolioDao portfolioDao = PortfolioDao(this as AppDatabase);
  late final AssetDao assetDao = AssetDao(this as AppDatabase);
  late final PortfolioAssetDao portfolioAssetDao =
      PortfolioAssetDao(this as AppDatabase);
  late final TransactionDao transactionDao =
      TransactionDao(this as AppDatabase);
  late final PriceHistoryDao priceHistoryDao =
      PriceHistoryDao(this as AppDatabase);
  late final InvestmentDao investmentDao = InvestmentDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        portfolios,
        assets,
        portfolioAssets,
        transactions,
        priceHistory,
        investments
      ];
}

typedef $$PortfoliosTableCreateCompanionBuilder = PortfoliosCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> description,
  Value<String> baseCurrency,
  Value<String?> rebalancePeriod,
  Value<DateTime?> nextRebalanceDate,
  Value<double> deviationThreshold,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$PortfoliosTableUpdateCompanionBuilder = PortfoliosCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> description,
  Value<String> baseCurrency,
  Value<String?> rebalancePeriod,
  Value<DateTime?> nextRebalanceDate,
  Value<double> deviationThreshold,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$PortfoliosTableReferences
    extends BaseReferences<_$AppDatabase, $PortfoliosTable, PortfolioRecord> {
  $$PortfoliosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PortfolioAssetsTable, List<PortfolioAssetRecord>>
      _portfolioAssetsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.portfolioAssets,
              aliasName: $_aliasNameGenerator(
                  db.portfolios.id, db.portfolioAssets.portfolioId));

  $$PortfolioAssetsTableProcessedTableManager get portfolioAssetsRefs {
    final manager = $$PortfolioAssetsTableTableManager(
            $_db, $_db.portfolioAssets)
        .filter((f) => f.portfolioId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_portfolioAssetsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$InvestmentsTable, List<InvestmentRecord>>
      _investmentsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.investments,
              aliasName: $_aliasNameGenerator(
                  db.portfolios.id, db.investments.portfolioId));

  $$InvestmentsTableProcessedTableManager get investmentsRefs {
    final manager = $$InvestmentsTableTableManager($_db, $_db.investments)
        .filter((f) => f.portfolioId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_investmentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PortfoliosTableFilterComposer
    extends Composer<_$AppDatabase, $PortfoliosTable> {
  $$PortfoliosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get baseCurrency => $composableBuilder(
      column: $table.baseCurrency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rebalancePeriod => $composableBuilder(
      column: $table.rebalancePeriod,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextRebalanceDate => $composableBuilder(
      column: $table.nextRebalanceDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get deviationThreshold => $composableBuilder(
      column: $table.deviationThreshold,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> portfolioAssetsRefs(
      Expression<bool> Function($$PortfolioAssetsTableFilterComposer f) f) {
    final $$PortfolioAssetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.portfolioAssets,
        getReferencedColumn: (t) => t.portfolioId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfolioAssetsTableFilterComposer(
              $db: $db,
              $table: $db.portfolioAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> investmentsRefs(
      Expression<bool> Function($$InvestmentsTableFilterComposer f) f) {
    final $$InvestmentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.investments,
        getReferencedColumn: (t) => t.portfolioId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$InvestmentsTableFilterComposer(
              $db: $db,
              $table: $db.investments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PortfoliosTableOrderingComposer
    extends Composer<_$AppDatabase, $PortfoliosTable> {
  $$PortfoliosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get baseCurrency => $composableBuilder(
      column: $table.baseCurrency,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rebalancePeriod => $composableBuilder(
      column: $table.rebalancePeriod,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextRebalanceDate => $composableBuilder(
      column: $table.nextRebalanceDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get deviationThreshold => $composableBuilder(
      column: $table.deviationThreshold,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PortfoliosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortfoliosTable> {
  $$PortfoliosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get baseCurrency => $composableBuilder(
      column: $table.baseCurrency, builder: (column) => column);

  GeneratedColumn<String> get rebalancePeriod => $composableBuilder(
      column: $table.rebalancePeriod, builder: (column) => column);

  GeneratedColumn<DateTime> get nextRebalanceDate => $composableBuilder(
      column: $table.nextRebalanceDate, builder: (column) => column);

  GeneratedColumn<double> get deviationThreshold => $composableBuilder(
      column: $table.deviationThreshold, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> portfolioAssetsRefs<T extends Object>(
      Expression<T> Function($$PortfolioAssetsTableAnnotationComposer a) f) {
    final $$PortfolioAssetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.portfolioAssets,
        getReferencedColumn: (t) => t.portfolioId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfolioAssetsTableAnnotationComposer(
              $db: $db,
              $table: $db.portfolioAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> investmentsRefs<T extends Object>(
      Expression<T> Function($$InvestmentsTableAnnotationComposer a) f) {
    final $$InvestmentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.investments,
        getReferencedColumn: (t) => t.portfolioId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$InvestmentsTableAnnotationComposer(
              $db: $db,
              $table: $db.investments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PortfoliosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PortfoliosTable,
    PortfolioRecord,
    $$PortfoliosTableFilterComposer,
    $$PortfoliosTableOrderingComposer,
    $$PortfoliosTableAnnotationComposer,
    $$PortfoliosTableCreateCompanionBuilder,
    $$PortfoliosTableUpdateCompanionBuilder,
    (PortfolioRecord, $$PortfoliosTableReferences),
    PortfolioRecord,
    PrefetchHooks Function({bool portfolioAssetsRefs, bool investmentsRefs})> {
  $$PortfoliosTableTableManager(_$AppDatabase db, $PortfoliosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortfoliosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortfoliosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortfoliosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> baseCurrency = const Value.absent(),
            Value<String?> rebalancePeriod = const Value.absent(),
            Value<DateTime?> nextRebalanceDate = const Value.absent(),
            Value<double> deviationThreshold = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              PortfoliosCompanion(
            id: id,
            name: name,
            description: description,
            baseCurrency: baseCurrency,
            rebalancePeriod: rebalancePeriod,
            nextRebalanceDate: nextRebalanceDate,
            deviationThreshold: deviationThreshold,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> description = const Value.absent(),
            Value<String> baseCurrency = const Value.absent(),
            Value<String?> rebalancePeriod = const Value.absent(),
            Value<DateTime?> nextRebalanceDate = const Value.absent(),
            Value<double> deviationThreshold = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              PortfoliosCompanion.insert(
            id: id,
            name: name,
            description: description,
            baseCurrency: baseCurrency,
            rebalancePeriod: rebalancePeriod,
            nextRebalanceDate: nextRebalanceDate,
            deviationThreshold: deviationThreshold,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PortfoliosTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {portfolioAssetsRefs = false, investmentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (portfolioAssetsRefs) db.portfolioAssets,
                if (investmentsRefs) db.investments
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (portfolioAssetsRefs)
                    await $_getPrefetchedData<PortfolioRecord, $PortfoliosTable,
                            PortfolioAssetRecord>(
                        currentTable: table,
                        referencedTable: $$PortfoliosTableReferences
                            ._portfolioAssetsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PortfoliosTableReferences(db, table, p0)
                                .portfolioAssetsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.portfolioId == item.id),
                        typedResults: items),
                  if (investmentsRefs)
                    await $_getPrefetchedData<PortfolioRecord, $PortfoliosTable,
                            InvestmentRecord>(
                        currentTable: table,
                        referencedTable: $$PortfoliosTableReferences
                            ._investmentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PortfoliosTableReferences(db, table, p0)
                                .investmentsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.portfolioId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PortfoliosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PortfoliosTable,
    PortfolioRecord,
    $$PortfoliosTableFilterComposer,
    $$PortfoliosTableOrderingComposer,
    $$PortfoliosTableAnnotationComposer,
    $$PortfoliosTableCreateCompanionBuilder,
    $$PortfoliosTableUpdateCompanionBuilder,
    (PortfolioRecord, $$PortfoliosTableReferences),
    PortfolioRecord,
    PrefetchHooks Function({bool portfolioAssetsRefs, bool investmentsRefs})>;
typedef $$AssetsTableCreateCompanionBuilder = AssetsCompanion Function({
  Value<int> id,
  required String symbol,
  required String name,
  required String assetType,
  required String currency,
  Value<String?> fundCode,
  Value<double?> lastPrice,
  Value<DateTime?> lastPriceUpdatedAt,
  Value<DateTime> createdAt,
});
typedef $$AssetsTableUpdateCompanionBuilder = AssetsCompanion Function({
  Value<int> id,
  Value<String> symbol,
  Value<String> name,
  Value<String> assetType,
  Value<String> currency,
  Value<String?> fundCode,
  Value<double?> lastPrice,
  Value<DateTime?> lastPriceUpdatedAt,
  Value<DateTime> createdAt,
});

final class $$AssetsTableReferences
    extends BaseReferences<_$AppDatabase, $AssetsTable, AssetRecord> {
  $$AssetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PortfolioAssetsTable, List<PortfolioAssetRecord>>
      _portfolioAssetsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.portfolioAssets,
              aliasName: $_aliasNameGenerator(
                  db.assets.id, db.portfolioAssets.assetId));

  $$PortfolioAssetsTableProcessedTableManager get portfolioAssetsRefs {
    final manager =
        $$PortfolioAssetsTableTableManager($_db, $_db.portfolioAssets)
            .filter((f) => f.assetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_portfolioAssetsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PriceHistoryTable, List<PriceHistoryData>>
      _priceHistoryRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.priceHistory,
              aliasName:
                  $_aliasNameGenerator(db.assets.id, db.priceHistory.assetId));

  $$PriceHistoryTableProcessedTableManager get priceHistoryRefs {
    final manager = $$PriceHistoryTableTableManager($_db, $_db.priceHistory)
        .filter((f) => f.assetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_priceHistoryRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AssetsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assetType => $composableBuilder(
      column: $table.assetType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fundCode => $composableBuilder(
      column: $table.fundCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lastPrice => $composableBuilder(
      column: $table.lastPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPriceUpdatedAt => $composableBuilder(
      column: $table.lastPriceUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> portfolioAssetsRefs(
      Expression<bool> Function($$PortfolioAssetsTableFilterComposer f) f) {
    final $$PortfolioAssetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.portfolioAssets,
        getReferencedColumn: (t) => t.assetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfolioAssetsTableFilterComposer(
              $db: $db,
              $table: $db.portfolioAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> priceHistoryRefs(
      Expression<bool> Function($$PriceHistoryTableFilterComposer f) f) {
    final $$PriceHistoryTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.priceHistory,
        getReferencedColumn: (t) => t.assetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PriceHistoryTableFilterComposer(
              $db: $db,
              $table: $db.priceHistory,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assetType => $composableBuilder(
      column: $table.assetType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fundCode => $composableBuilder(
      column: $table.fundCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lastPrice => $composableBuilder(
      column: $table.lastPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPriceUpdatedAt => $composableBuilder(
      column: $table.lastPriceUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get assetType =>
      $composableBuilder(column: $table.assetType, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get fundCode =>
      $composableBuilder(column: $table.fundCode, builder: (column) => column);

  GeneratedColumn<double> get lastPrice =>
      $composableBuilder(column: $table.lastPrice, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPriceUpdatedAt => $composableBuilder(
      column: $table.lastPriceUpdatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> portfolioAssetsRefs<T extends Object>(
      Expression<T> Function($$PortfolioAssetsTableAnnotationComposer a) f) {
    final $$PortfolioAssetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.portfolioAssets,
        getReferencedColumn: (t) => t.assetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfolioAssetsTableAnnotationComposer(
              $db: $db,
              $table: $db.portfolioAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> priceHistoryRefs<T extends Object>(
      Expression<T> Function($$PriceHistoryTableAnnotationComposer a) f) {
    final $$PriceHistoryTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.priceHistory,
        getReferencedColumn: (t) => t.assetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PriceHistoryTableAnnotationComposer(
              $db: $db,
              $table: $db.priceHistory,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AssetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssetsTable,
    AssetRecord,
    $$AssetsTableFilterComposer,
    $$AssetsTableOrderingComposer,
    $$AssetsTableAnnotationComposer,
    $$AssetsTableCreateCompanionBuilder,
    $$AssetsTableUpdateCompanionBuilder,
    (AssetRecord, $$AssetsTableReferences),
    AssetRecord,
    PrefetchHooks Function({bool portfolioAssetsRefs, bool priceHistoryRefs})> {
  $$AssetsTableTableManager(_$AppDatabase db, $AssetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> symbol = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> assetType = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> fundCode = const Value.absent(),
            Value<double?> lastPrice = const Value.absent(),
            Value<DateTime?> lastPriceUpdatedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AssetsCompanion(
            id: id,
            symbol: symbol,
            name: name,
            assetType: assetType,
            currency: currency,
            fundCode: fundCode,
            lastPrice: lastPrice,
            lastPriceUpdatedAt: lastPriceUpdatedAt,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String symbol,
            required String name,
            required String assetType,
            required String currency,
            Value<String?> fundCode = const Value.absent(),
            Value<double?> lastPrice = const Value.absent(),
            Value<DateTime?> lastPriceUpdatedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AssetsCompanion.insert(
            id: id,
            symbol: symbol,
            name: name,
            assetType: assetType,
            currency: currency,
            fundCode: fundCode,
            lastPrice: lastPrice,
            lastPriceUpdatedAt: lastPriceUpdatedAt,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$AssetsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {portfolioAssetsRefs = false, priceHistoryRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (portfolioAssetsRefs) db.portfolioAssets,
                if (priceHistoryRefs) db.priceHistory
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (portfolioAssetsRefs)
                    await $_getPrefetchedData<AssetRecord, $AssetsTable, PortfolioAssetRecord>(
                        currentTable: table,
                        referencedTable: $$AssetsTableReferences
                            ._portfolioAssetsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AssetsTableReferences(db, table, p0)
                                .portfolioAssetsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.assetId == item.id),
                        typedResults: items),
                  if (priceHistoryRefs)
                    await $_getPrefetchedData<AssetRecord, $AssetsTable,
                            PriceHistoryData>(
                        currentTable: table,
                        referencedTable:
                            $$AssetsTableReferences._priceHistoryRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AssetsTableReferences(db, table, p0)
                                .priceHistoryRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.assetId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$AssetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AssetsTable,
    AssetRecord,
    $$AssetsTableFilterComposer,
    $$AssetsTableOrderingComposer,
    $$AssetsTableAnnotationComposer,
    $$AssetsTableCreateCompanionBuilder,
    $$AssetsTableUpdateCompanionBuilder,
    (AssetRecord, $$AssetsTableReferences),
    AssetRecord,
    PrefetchHooks Function({bool portfolioAssetsRefs, bool priceHistoryRefs})>;
typedef $$PortfolioAssetsTableCreateCompanionBuilder = PortfolioAssetsCompanion
    Function({
  Value<int> id,
  required int portfolioId,
  required int assetId,
  required double targetWeight,
  Value<int> sortOrder,
  Value<DateTime> addedAt,
});
typedef $$PortfolioAssetsTableUpdateCompanionBuilder = PortfolioAssetsCompanion
    Function({
  Value<int> id,
  Value<int> portfolioId,
  Value<int> assetId,
  Value<double> targetWeight,
  Value<int> sortOrder,
  Value<DateTime> addedAt,
});

final class $$PortfolioAssetsTableReferences extends BaseReferences<
    _$AppDatabase, $PortfolioAssetsTable, PortfolioAssetRecord> {
  $$PortfolioAssetsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PortfoliosTable _portfolioIdTable(_$AppDatabase db) =>
      db.portfolios.createAlias($_aliasNameGenerator(
          db.portfolioAssets.portfolioId, db.portfolios.id));

  $$PortfoliosTableProcessedTableManager get portfolioId {
    final $_column = $_itemColumn<int>('portfolio_id')!;

    final manager = $$PortfoliosTableTableManager($_db, $_db.portfolios)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_portfolioIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $AssetsTable _assetIdTable(_$AppDatabase db) => db.assets.createAlias(
      $_aliasNameGenerator(db.portfolioAssets.assetId, db.assets.id));

  $$AssetsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<int>('asset_id')!;

    final manager = $$AssetsTableTableManager($_db, $_db.assets)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$TransactionsTable, List<TransactionRecord>>
      _transactionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.transactions,
              aliasName: $_aliasNameGenerator(
                  db.portfolioAssets.id, db.transactions.portfolioAssetId));

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager($_db, $_db.transactions)
        .filter(
            (f) => f.portfolioAssetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PortfolioAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $PortfolioAssetsTable> {
  $$PortfolioAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get targetWeight => $composableBuilder(
      column: $table.targetWeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));

  $$PortfoliosTableFilterComposer get portfolioId {
    final $$PortfoliosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.portfolioId,
        referencedTable: $db.portfolios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfoliosTableFilterComposer(
              $db: $db,
              $table: $db.portfolios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$AssetsTableFilterComposer get assetId {
    final $$AssetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assetId,
        referencedTable: $db.assets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetsTableFilterComposer(
              $db: $db,
              $table: $db.assets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> transactionsRefs(
      Expression<bool> Function($$TransactionsTableFilterComposer f) f) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.portfolioAssetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableFilterComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PortfolioAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $PortfolioAssetsTable> {
  $$PortfolioAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get targetWeight => $composableBuilder(
      column: $table.targetWeight,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));

  $$PortfoliosTableOrderingComposer get portfolioId {
    final $$PortfoliosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.portfolioId,
        referencedTable: $db.portfolios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfoliosTableOrderingComposer(
              $db: $db,
              $table: $db.portfolios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$AssetsTableOrderingComposer get assetId {
    final $$AssetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assetId,
        referencedTable: $db.assets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetsTableOrderingComposer(
              $db: $db,
              $table: $db.assets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PortfolioAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortfolioAssetsTable> {
  $$PortfolioAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get targetWeight => $composableBuilder(
      column: $table.targetWeight, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$PortfoliosTableAnnotationComposer get portfolioId {
    final $$PortfoliosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.portfolioId,
        referencedTable: $db.portfolios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfoliosTableAnnotationComposer(
              $db: $db,
              $table: $db.portfolios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$AssetsTableAnnotationComposer get assetId {
    final $$AssetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assetId,
        referencedTable: $db.assets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetsTableAnnotationComposer(
              $db: $db,
              $table: $db.assets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
      Expression<T> Function($$TransactionsTableAnnotationComposer a) f) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.transactions,
        getReferencedColumn: (t) => t.portfolioAssetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TransactionsTableAnnotationComposer(
              $db: $db,
              $table: $db.transactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PortfolioAssetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PortfolioAssetsTable,
    PortfolioAssetRecord,
    $$PortfolioAssetsTableFilterComposer,
    $$PortfolioAssetsTableOrderingComposer,
    $$PortfolioAssetsTableAnnotationComposer,
    $$PortfolioAssetsTableCreateCompanionBuilder,
    $$PortfolioAssetsTableUpdateCompanionBuilder,
    (PortfolioAssetRecord, $$PortfolioAssetsTableReferences),
    PortfolioAssetRecord,
    PrefetchHooks Function(
        {bool portfolioId, bool assetId, bool transactionsRefs})> {
  $$PortfolioAssetsTableTableManager(
      _$AppDatabase db, $PortfolioAssetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortfolioAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortfolioAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortfolioAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> portfolioId = const Value.absent(),
            Value<int> assetId = const Value.absent(),
            Value<double> targetWeight = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
          }) =>
              PortfolioAssetsCompanion(
            id: id,
            portfolioId: portfolioId,
            assetId: assetId,
            targetWeight: targetWeight,
            sortOrder: sortOrder,
            addedAt: addedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int portfolioId,
            required int assetId,
            required double targetWeight,
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
          }) =>
              PortfolioAssetsCompanion.insert(
            id: id,
            portfolioId: portfolioId,
            assetId: assetId,
            targetWeight: targetWeight,
            sortOrder: sortOrder,
            addedAt: addedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PortfolioAssetsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {portfolioId = false,
              assetId = false,
              transactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transactionsRefs) db.transactions],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (portfolioId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.portfolioId,
                    referencedTable:
                        $$PortfolioAssetsTableReferences._portfolioIdTable(db),
                    referencedColumn: $$PortfolioAssetsTableReferences
                        ._portfolioIdTable(db)
                        .id,
                  ) as T;
                }
                if (assetId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.assetId,
                    referencedTable:
                        $$PortfolioAssetsTableReferences._assetIdTable(db),
                    referencedColumn:
                        $$PortfolioAssetsTableReferences._assetIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedData<PortfolioAssetRecord,
                            $PortfolioAssetsTable, TransactionRecord>(
                        currentTable: table,
                        referencedTable: $$PortfolioAssetsTableReferences
                            ._transactionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PortfolioAssetsTableReferences(db, table, p0)
                                .transactionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.portfolioAssetId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PortfolioAssetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PortfolioAssetsTable,
    PortfolioAssetRecord,
    $$PortfolioAssetsTableFilterComposer,
    $$PortfolioAssetsTableOrderingComposer,
    $$PortfolioAssetsTableAnnotationComposer,
    $$PortfolioAssetsTableCreateCompanionBuilder,
    $$PortfolioAssetsTableUpdateCompanionBuilder,
    (PortfolioAssetRecord, $$PortfolioAssetsTableReferences),
    PortfolioAssetRecord,
    PrefetchHooks Function(
        {bool portfolioId, bool assetId, bool transactionsRefs})>;
typedef $$TransactionsTableCreateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  required int portfolioAssetId,
  required String type,
  required double quantity,
  required double price,
  Value<double> exchangeRate,
  Value<double> fee,
  required DateTime transactionDate,
  Value<String?> memo,
  Value<DateTime> createdAt,
});
typedef $$TransactionsTableUpdateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  Value<int> portfolioAssetId,
  Value<String> type,
  Value<double> quantity,
  Value<double> price,
  Value<double> exchangeRate,
  Value<double> fee,
  Value<DateTime> transactionDate,
  Value<String?> memo,
  Value<DateTime> createdAt,
});

final class $$TransactionsTableReferences extends BaseReferences<_$AppDatabase,
    $TransactionsTable, TransactionRecord> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PortfolioAssetsTable _portfolioAssetIdTable(_$AppDatabase db) =>
      db.portfolioAssets.createAlias($_aliasNameGenerator(
          db.transactions.portfolioAssetId, db.portfolioAssets.id));

  $$PortfolioAssetsTableProcessedTableManager get portfolioAssetId {
    final $_column = $_itemColumn<int>('portfolio_asset_id')!;

    final manager =
        $$PortfolioAssetsTableTableManager($_db, $_db.portfolioAssets)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_portfolioAssetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get exchangeRate => $composableBuilder(
      column: $table.exchangeRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fee => $composableBuilder(
      column: $table.fee, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get transactionDate => $composableBuilder(
      column: $table.transactionDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$PortfolioAssetsTableFilterComposer get portfolioAssetId {
    final $$PortfolioAssetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.portfolioAssetId,
        referencedTable: $db.portfolioAssets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfolioAssetsTableFilterComposer(
              $db: $db,
              $table: $db.portfolioAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get exchangeRate => $composableBuilder(
      column: $table.exchangeRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fee => $composableBuilder(
      column: $table.fee, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get transactionDate => $composableBuilder(
      column: $table.transactionDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$PortfolioAssetsTableOrderingComposer get portfolioAssetId {
    final $$PortfolioAssetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.portfolioAssetId,
        referencedTable: $db.portfolioAssets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfolioAssetsTableOrderingComposer(
              $db: $db,
              $table: $db.portfolioAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<double> get exchangeRate => $composableBuilder(
      column: $table.exchangeRate, builder: (column) => column);

  GeneratedColumn<double> get fee =>
      $composableBuilder(column: $table.fee, builder: (column) => column);

  GeneratedColumn<DateTime> get transactionDate => $composableBuilder(
      column: $table.transactionDate, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PortfolioAssetsTableAnnotationComposer get portfolioAssetId {
    final $$PortfolioAssetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.portfolioAssetId,
        referencedTable: $db.portfolioAssets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfolioAssetsTableAnnotationComposer(
              $db: $db,
              $table: $db.portfolioAssets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TransactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TransactionsTable,
    TransactionRecord,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (TransactionRecord, $$TransactionsTableReferences),
    TransactionRecord,
    PrefetchHooks Function({bool portfolioAssetId})> {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> portfolioAssetId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<double> price = const Value.absent(),
            Value<double> exchangeRate = const Value.absent(),
            Value<double> fee = const Value.absent(),
            Value<DateTime> transactionDate = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TransactionsCompanion(
            id: id,
            portfolioAssetId: portfolioAssetId,
            type: type,
            quantity: quantity,
            price: price,
            exchangeRate: exchangeRate,
            fee: fee,
            transactionDate: transactionDate,
            memo: memo,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int portfolioAssetId,
            required String type,
            required double quantity,
            required double price,
            Value<double> exchangeRate = const Value.absent(),
            Value<double> fee = const Value.absent(),
            required DateTime transactionDate,
            Value<String?> memo = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TransactionsCompanion.insert(
            id: id,
            portfolioAssetId: portfolioAssetId,
            type: type,
            quantity: quantity,
            price: price,
            exchangeRate: exchangeRate,
            fee: fee,
            transactionDate: transactionDate,
            memo: memo,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TransactionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({portfolioAssetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (portfolioAssetId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.portfolioAssetId,
                    referencedTable: $$TransactionsTableReferences
                        ._portfolioAssetIdTable(db),
                    referencedColumn: $$TransactionsTableReferences
                        ._portfolioAssetIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TransactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TransactionsTable,
    TransactionRecord,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (TransactionRecord, $$TransactionsTableReferences),
    TransactionRecord,
    PrefetchHooks Function({bool portfolioAssetId})>;
typedef $$PriceHistoryTableCreateCompanionBuilder = PriceHistoryCompanion
    Function({
  Value<int> id,
  required int assetId,
  required double closePrice,
  required DateTime date,
  Value<DateTime> fetchedAt,
});
typedef $$PriceHistoryTableUpdateCompanionBuilder = PriceHistoryCompanion
    Function({
  Value<int> id,
  Value<int> assetId,
  Value<double> closePrice,
  Value<DateTime> date,
  Value<DateTime> fetchedAt,
});

final class $$PriceHistoryTableReferences extends BaseReferences<_$AppDatabase,
    $PriceHistoryTable, PriceHistoryData> {
  $$PriceHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AssetsTable _assetIdTable(_$AppDatabase db) => db.assets
      .createAlias($_aliasNameGenerator(db.priceHistory.assetId, db.assets.id));

  $$AssetsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<int>('asset_id')!;

    final manager = $$AssetsTableTableManager($_db, $_db.assets)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PriceHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $PriceHistoryTable> {
  $$PriceHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get closePrice => $composableBuilder(
      column: $table.closePrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));

  $$AssetsTableFilterComposer get assetId {
    final $$AssetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assetId,
        referencedTable: $db.assets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetsTableFilterComposer(
              $db: $db,
              $table: $db.assets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PriceHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $PriceHistoryTable> {
  $$PriceHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get closePrice => $composableBuilder(
      column: $table.closePrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));

  $$AssetsTableOrderingComposer get assetId {
    final $$AssetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assetId,
        referencedTable: $db.assets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetsTableOrderingComposer(
              $db: $db,
              $table: $db.assets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PriceHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $PriceHistoryTable> {
  $$PriceHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get closePrice => $composableBuilder(
      column: $table.closePrice, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  $$AssetsTableAnnotationComposer get assetId {
    final $$AssetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.assetId,
        referencedTable: $db.assets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetsTableAnnotationComposer(
              $db: $db,
              $table: $db.assets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PriceHistoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PriceHistoryTable,
    PriceHistoryData,
    $$PriceHistoryTableFilterComposer,
    $$PriceHistoryTableOrderingComposer,
    $$PriceHistoryTableAnnotationComposer,
    $$PriceHistoryTableCreateCompanionBuilder,
    $$PriceHistoryTableUpdateCompanionBuilder,
    (PriceHistoryData, $$PriceHistoryTableReferences),
    PriceHistoryData,
    PrefetchHooks Function({bool assetId})> {
  $$PriceHistoryTableTableManager(_$AppDatabase db, $PriceHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PriceHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PriceHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PriceHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> assetId = const Value.absent(),
            Value<double> closePrice = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
          }) =>
              PriceHistoryCompanion(
            id: id,
            assetId: assetId,
            closePrice: closePrice,
            date: date,
            fetchedAt: fetchedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int assetId,
            required double closePrice,
            required DateTime date,
            Value<DateTime> fetchedAt = const Value.absent(),
          }) =>
              PriceHistoryCompanion.insert(
            id: id,
            assetId: assetId,
            closePrice: closePrice,
            date: date,
            fetchedAt: fetchedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PriceHistoryTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({assetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (assetId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.assetId,
                    referencedTable:
                        $$PriceHistoryTableReferences._assetIdTable(db),
                    referencedColumn:
                        $$PriceHistoryTableReferences._assetIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PriceHistoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PriceHistoryTable,
    PriceHistoryData,
    $$PriceHistoryTableFilterComposer,
    $$PriceHistoryTableOrderingComposer,
    $$PriceHistoryTableAnnotationComposer,
    $$PriceHistoryTableCreateCompanionBuilder,
    $$PriceHistoryTableUpdateCompanionBuilder,
    (PriceHistoryData, $$PriceHistoryTableReferences),
    PriceHistoryData,
    PrefetchHooks Function({bool assetId})>;
typedef $$InvestmentsTableCreateCompanionBuilder = InvestmentsCompanion
    Function({
  Value<int> id,
  required int portfolioId,
  required double amount,
  required DateTime investmentDate,
  Value<String?> memo,
  Value<DateTime> createdAt,
});
typedef $$InvestmentsTableUpdateCompanionBuilder = InvestmentsCompanion
    Function({
  Value<int> id,
  Value<int> portfolioId,
  Value<double> amount,
  Value<DateTime> investmentDate,
  Value<String?> memo,
  Value<DateTime> createdAt,
});

final class $$InvestmentsTableReferences
    extends BaseReferences<_$AppDatabase, $InvestmentsTable, InvestmentRecord> {
  $$InvestmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PortfoliosTable _portfolioIdTable(_$AppDatabase db) =>
      db.portfolios.createAlias(
          $_aliasNameGenerator(db.investments.portfolioId, db.portfolios.id));

  $$PortfoliosTableProcessedTableManager get portfolioId {
    final $_column = $_itemColumn<int>('portfolio_id')!;

    final manager = $$PortfoliosTableTableManager($_db, $_db.portfolios)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_portfolioIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$InvestmentsTableFilterComposer
    extends Composer<_$AppDatabase, $InvestmentsTable> {
  $$InvestmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get investmentDate => $composableBuilder(
      column: $table.investmentDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$PortfoliosTableFilterComposer get portfolioId {
    final $$PortfoliosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.portfolioId,
        referencedTable: $db.portfolios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfoliosTableFilterComposer(
              $db: $db,
              $table: $db.portfolios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$InvestmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $InvestmentsTable> {
  $$InvestmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get investmentDate => $composableBuilder(
      column: $table.investmentDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memo => $composableBuilder(
      column: $table.memo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$PortfoliosTableOrderingComposer get portfolioId {
    final $$PortfoliosTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.portfolioId,
        referencedTable: $db.portfolios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfoliosTableOrderingComposer(
              $db: $db,
              $table: $db.portfolios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$InvestmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvestmentsTable> {
  $$InvestmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get investmentDate => $composableBuilder(
      column: $table.investmentDate, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PortfoliosTableAnnotationComposer get portfolioId {
    final $$PortfoliosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.portfolioId,
        referencedTable: $db.portfolios,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PortfoliosTableAnnotationComposer(
              $db: $db,
              $table: $db.portfolios,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$InvestmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InvestmentsTable,
    InvestmentRecord,
    $$InvestmentsTableFilterComposer,
    $$InvestmentsTableOrderingComposer,
    $$InvestmentsTableAnnotationComposer,
    $$InvestmentsTableCreateCompanionBuilder,
    $$InvestmentsTableUpdateCompanionBuilder,
    (InvestmentRecord, $$InvestmentsTableReferences),
    InvestmentRecord,
    PrefetchHooks Function({bool portfolioId})> {
  $$InvestmentsTableTableManager(_$AppDatabase db, $InvestmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvestmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvestmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvestmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> portfolioId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<DateTime> investmentDate = const Value.absent(),
            Value<String?> memo = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              InvestmentsCompanion(
            id: id,
            portfolioId: portfolioId,
            amount: amount,
            investmentDate: investmentDate,
            memo: memo,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int portfolioId,
            required double amount,
            required DateTime investmentDate,
            Value<String?> memo = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              InvestmentsCompanion.insert(
            id: id,
            portfolioId: portfolioId,
            amount: amount,
            investmentDate: investmentDate,
            memo: memo,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$InvestmentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({portfolioId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (portfolioId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.portfolioId,
                    referencedTable:
                        $$InvestmentsTableReferences._portfolioIdTable(db),
                    referencedColumn:
                        $$InvestmentsTableReferences._portfolioIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$InvestmentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InvestmentsTable,
    InvestmentRecord,
    $$InvestmentsTableFilterComposer,
    $$InvestmentsTableOrderingComposer,
    $$InvestmentsTableAnnotationComposer,
    $$InvestmentsTableCreateCompanionBuilder,
    $$InvestmentsTableUpdateCompanionBuilder,
    (InvestmentRecord, $$InvestmentsTableReferences),
    InvestmentRecord,
    PrefetchHooks Function({bool portfolioId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PortfoliosTableTableManager get portfolios =>
      $$PortfoliosTableTableManager(_db, _db.portfolios);
  $$AssetsTableTableManager get assets =>
      $$AssetsTableTableManager(_db, _db.assets);
  $$PortfolioAssetsTableTableManager get portfolioAssets =>
      $$PortfolioAssetsTableTableManager(_db, _db.portfolioAssets);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$PriceHistoryTableTableManager get priceHistory =>
      $$PriceHistoryTableTableManager(_db, _db.priceHistory);
  $$InvestmentsTableTableManager get investments =>
      $$InvestmentsTableTableManager(_db, _db.investments);
}
