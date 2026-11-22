import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/import_mapping_local_ds.dart';
import '../../data/repositories/import_writer.dart';
import 'database_providers.dart';

/// 파일 가져오기에서 사용자가 고친 열 매핑을 기억하는 저장소.
final importMappingDsProvider = Provider<ImportMappingLocalDataSource>(
  (ref) => ImportMappingLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

/// 확정된 줄들을 DB에 쓰는 쪽.
final importWriterProvider = Provider<ImportWriter>(
  (ref) => ImportWriter(ref.watch(appDatabaseProvider)),
);
