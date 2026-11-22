# CSV·엑셀 표 업로드로 보유 종목 가져오기 — 설계

작성 2026-11-22 · 검토 1회 반영

## 의도와 이유

사용자가 증권사나 엑셀에서 받은 표 파일을 올리면 보유 종목을 포트폴리오에
한 번에 등록한다. 종목이 많을 때 앱에서 한 줄씩 입력하는 수고를 없애는 것이
목적이다.

핵심 제약은 **증권사마다 파일 형식이 전부 다르다**는 것이다. 열 이름도, 열
순서도, 상단에 붙는 머리글 줄도 다르다. 그래서 "정해진 양식만 받는다"는 설계는
이 기능의 이유를 무너뜨린다. 어떤 형식이든 받아야 한다.

부수 효과로 파일 가져오기는 API 키를 요구하지 않는다. 계좌 가져오기(KIS)는
App Key/Secret 입력란 때문에 Play Console이 로그인 정보를 요구하는데, 파일
경로에는 그 문제가 없다. 목표는 아니지만 알아둘 만하다.

## 목표

- `.csv`, `.xlsx`에서 종목코드·종목명·수량·평균단가·(있으면)매수일을 읽어 등록
- 열 이름을 자동으로 맞추고, 틀린 것만 사용자가 드롭다운으로 고침
- 고친 매핑을 **파일 모양**으로 기억 → 같은 증권사 파일은 다음부터 그냥 통과
- 가져오기 전 미리보기로 사용자가 눈으로 확인하고 확정
- EUC-KR과 UTF-8 둘 다 읽기
- 가져온 직후 포트폴리오 화면의 수익률·연평균이 제대로 보일 것

## 목표가 아닌 것

- **거래 내역(매매 이력) 가져오기.** 이번은 "현재 보유 종목"만. 매핑 기계는
  그대로 재사용할 수 있으므로 다음 확장으로 남긴다.
- **구형 `.xls` 지원.** 실제 내용이 HTML이거나 옛 바이너리인 경우가 많다.
  "엑셀에서 열어 .xlsx로 저장해 주세요"로 안내한다.
- **종목명으로 종목코드를 조회하는 것.** 네트워크 단계·오프라인 상태·행별
  "못 찾음" 처리가 붙어 화면이 크게 불어난다. 다른 기능이다.
- 서버·클라우드 파싱, 주기적 자동 재가져오기

## 실패로 보는 것 (anti-goals)

1. **조용히 틀린 수치가 들어가는 것.** 형식이 다양할 때 가장 위험하다. 애매하면
   넣지 않고 "N줄 건너뜀"으로 센다.
2. **시세가 영영 안 붙는 종목을 만드는 것.** 종목코드 없이 등록하면 평가액이
   계속 0으로 남는다.
3. 기존 포트폴리오·거래 데이터를 덮어쓰거나 지우는 것. 가져오기는 **추가만** 한다.
4. 계좌 가져오기·추이 등 기존 기능이 깨지는 것.

## 제약

| 항목 | 내용 |
|---|---|
| 패키지 추가 | `csv 8.0.0`, `excel 4.0.6`, `charset 2.0.1` |
| 부수 효과 | `archive` 4.0.9→3.6.1, `image` 4.8.0→4.3.0. 둘 다 `flutter_launcher_icons`(**dev** 의존)만 쓰므로 배포 앱 영향 없음 |
| 이미 있는 것 | `file_picker 8.1.7` (`withData: true`로 바이트 직접 수령) |
| DB 유니크 | `Assets` unique = `{symbol, assetType}` |
| **DB 쓰기 주의** | `insertOnConflictUpdate`는 **기본 타깃이 PK**라 `{symbol, assetType}` 충돌을 못 막는다. 아래 "중복 처리" 참조 |
| 상태 관리 | plain Riverpod providers. `riverpod_generator` 금지(freezed 2.x 충돌) |
| 도메인 모델 | 새 모델은 plain Dart. build_runner 돌릴 필요 없게 |
| 자산 유형 값 | `AssetType`: `usStock` `krStock` `crypto` `krFund` `gold` `cash` |
| 현재 스키마 | `schemaVersion = 3`, `onUpgrade` 선례 있음 |

## 검토한 방법들

**A. 앱이 양식을 제공** — 빈 CSV 양식을 받아 옮겨 적고 올린다. 구현이 가장
단순하지만 증권사 파일을 그대로 못 쓴다. 20종목이면 20줄을 손으로 옮겨야 하는데
그 정도면 앱에서 직접 입력하는 것과 차이가 없어 **기능의 이유가 사라진다.**

**B. 열을 사용자가 직접 연결** — 어떤 형식이든 되지만 올릴 때마다 5~6개를
고르는 게 번거롭다.

**C. 자동으로 맞춰보고 사용자가 확인·수정 — 채택** — 사전으로 자동 매핑 →
미리보기와 함께 보여주고 틀린 것만 고침 → 고친 매핑을 파일 모양으로 기억.
B를 안에 품고 있어 어떤 형식이든 되고 대부분 자동으로 끝난다. 사전은 "편의"이지
"정확성의 근거"가 아니다 — 부족해도 사용자가 고치면 기억되므로 기능은 동작한다.

사용자가 C를 선택했다.

## 흐름

```
설정 → 파일에서 가져오기
  → 파일 선택 (.csv / .xlsx)
  → [자동] 형식·인코딩 판별 · 헤더 행 찾기 · 열 매핑 추측 (기억된 매핑 우선)
  → 확인·수정 화면 (드롭다운 + 취득일 + 미리보기 + 경고)
  → 포트폴리오 선택 (기존 / 새로 만들기)
  → 가져오기 (단일 DB 트랜잭션)
  → 완료
```

```
┌─ 파일에서 가져오기 ─────────────────┐
│ 삼성증권_잔고.xlsx   12행 인식        │
│                                     │
│  종목코드 ←  [ 단축코드       ▼ ]   │
│  종목명   ←  [ 상품명         ▼ ]   │
│  수량     ←  [ 보유수량       ▼ ]   │
│  평균단가 ←  [ 매입단가       ▼ ]   │
│  매수일   ←  [ 없음           ▼ ]   │
│  유형     ←  [ 자동           ▼ ]   │
│                                     │
│  취득일   [ 2026-11-22      📅 ]    │
│   매수일 열이 없어 이 날짜를 씁니다   │
│ ─────────────────────────────────── │
│  미리보기                            │
│  삼성전자        10주    71,200원    │
│  TIGER미국나스닥  5주    18,450원    │
│  …                                  │
│  합계 투자원금          1,284만원    │
│  ⚠ 종목코드 없음 — 2줄 건너뜁니다     │
│  ⚠ 이미 보유 중 — 1줄 건너뜁니다      │
│                                     │
│       [  12개 종목 가져오기  ]       │
└─────────────────────────────────────┘
```

## 사용자가 정한 것

### 취득일 (매수 날짜)

파일에 매수일 열이 있으면 역할 `buyDate`로 매핑해 **줄마다** 그 날짜를 쓴다.
없으면 화면의 **취득일 날짜 선택기** 값을 **파일 전체**에 적용한다. 기본값 오늘.

이유: 전부 오늘로 적으면 추이 그래프의 투입금액 선이 오늘 갑자기 점프하고,
보유기간이 0일이라 연평균이 말이 안 되며, MDD가 오늘 이전 구간을 "그 종목이
없던 것"으로 계산한다. 종목별로 다르게는 못 넣더라도 과거 날짜 하나는 넣을 수
있어야 한다.

### 이미 보유 중인 종목이 파일에 또 있을 때

**건너뛴다.** 미리보기에 `이미 보유 중 — N줄 건너뜁니다`로 센다. 기존 수량·평단·
거래 기록에 손대지 않는다(anti-goal 3). 수량이 바뀌었으면 사용자가 직접 수정한다.

판정 기준: 그 **포트폴리오 안에** 같은 `{symbol, assetType}` 자산이 이미
`portfolio_assets`로 연결돼 있으면 보유 중으로 본다.

### 투자원금 기록

가져올 때 `Investments`에 **한 건** 기록한다.

- `amount` = 가져온 줄들의 `수량 × 평균단가` 합계, **원화**. 미국 종목은
  `usdKrwRateProvider`로 환산한다.
- `investmentDate` = 위에서 정한 취득일. 줄마다 매수일이 다르면 **가장 이른
  날짜**를 쓴다(연평균의 보유기간이 과소평가되지 않게).
- `memo` = `파일 가져오기: <파일명>`

이유: 연평균 수익률은 `FinancialCalculator.annualizedReturnFromInvestments`가
계산하는데, 투자원금 목록이 비면 `0`을 반환한다. 기록하지 않으면 12종목을
가져온 직후에도 연평균이 0%로 보여 고장 난 것처럼 보인다.

### 종목코드가 없는 줄

**가져오지 않고 센다.** 미리보기에 `종목코드 없음 — N줄 건너뜁니다`로 표시.

이유: 코드가 없으면 `price_repository_impl`이 시세를 못 찾아 평가액이 영영 0으로
남는다(anti-goal 2). 종목명을 symbol에 넣는 대체(계좌 가져오기가 하는 방식)는
**쓰지 않는다** — 한글 이름으로 야후·네이버를 영원히 조회하는 자산이 생긴다.

따라서 **`symbol`은 필수**다. `name`은 없으면 `symbol`로 채운다.

## 내가 정한 것

### EUC-KR 디코딩 — `charset 2.0.1`

`dart:convert`에 EUC-KR 코덱이 없고 `csv`·`excel`도 제공하지 않는다. 후보 중
`charset_converter`는 플랫폼 채널이라 `flutter test`에서 못 돌고, `enough_convert`는
한국어 인코딩이 없다. `charset`은 순수 Dart이고 `eucKr` 코덱을 제공한다.

UTF-8 엄격 디코드를 먼저 시도하고, 실패하면 `eucKr.decode(bytes)`로 넘어간다.

`.xlsx`는 내부가 UTF-8 XML이라 인코딩 문제가 없다. CSV에만 적용한다.
CP949는 EUC-KR의 확장집합이라 희귀 문자에서 다를 수 있다 — 구현 시 실제 바이트로
확인하고, 안 되면 그 줄을 "읽기 실패"로 센다.

### 중복 처리 — `insertOnConflictUpdate`를 그대로 쓰지 않는다

`insertOnConflictUpdate`는 ON CONFLICT 타깃이 **기본적으로 PK**다. id를 안 주면
새 id로 INSERT를 시도하므로 `{symbol, assetType}` UNIQUE 위반이 그대로 터진다.
`asset_repository_impl.dart:32` 주석이 같은 이유로 선조회를 한다.

단일 트랜잭션으로 감싸므로, **이미 보유한 종목 하나가 가져오기 전체를 실패시킨다.**
계좌 가져오기(KIS)가 바로 이 방어가 빠진 코드다.

→ 쓰기 전에 `assetDao.getBySymbolAndType(symbol, type)`으로 선조회하고
있으면 그 id를 쓴다. 없을 때만 insert 한다.

### 유형 드롭다운에 담을 값

`자동` / `한국 주식·ETF` / `미국 주식·ETF` **셋만** 둔다.

`krFund`는 `fundCode`가 있어야 시세가 붙고, `crypto`는 거래소 티커가 아니라
CoinGecko id가 필요하며, `cash`·`gold`는 symbol이 의미가 없다. 드롭다운에 넣으면
사용자가 고를 수 있고, 고르는 순간 시세가 안 붙는 자산이 생긴다(anti-goal 2).

`자동`일 때: 6자리 숫자 코드 → `krStock`, 영문 대문자 티커 → `usStock`,
판단 불가 → 그 줄을 건너뛰고 센다.
사용자가 유형을 고르면 **파일 전체에 그 유형을 적용**한다(명시적 선택 우선).

### `현재가` 열은 미리보기 전용

읽어서 보여주기만 하고 `assets.lastPrice`에 **쓰지 않는다**. 파일의 가격은 과거
시점 값인데 `lastPriceUpdatedAt`에 넣을 날짜가 없어서, 쓰면 낡은 값이 실시간
시세처럼 보인다. 미리보기 합계는 `수량 × 평균단가`(= 투자원금)로 계산한다.

### 기존 `stock_kr` 데이터 마이그레이션

계좌 가져오기가 `assetType: 'stock_kr'`로 저장해 왔는데 enum 값은 `'krStock'`이다.
`AssetType.fromValue('stock_kr')`은 `orElse`로 빠져 **`usStock`을 반환**한다.

한 줄만 고치면 기존 사용자 DB에 남은 `stock_kr` 행은 그대로 미국 주식으로 읽히고,
게다가 새로 들어오는 `krStock` 행과 **같은 종목이 중복**된다. 고치려던 문제가
그대로 생긴다.

→ `schemaVersion` 3 → 4, `onUpgrade`에 `from < 4` 분기 추가.
`assets`의 `stock_kr` → `krStock`, `currency` → `KRW`로 일괄 갱신.
같은 symbol의 `krStock` 행이 이미 있으면 그쪽으로 합치고 중복 행은 지운다.
`asset_dao.dart`의 `migrateGoldCurrencyToKrw()`가 선례다.

### 자잘한 것들

- **멀티시트 `.xlsx`**: 시트마다 헤더 행 점수를 매겨 가장 높은 시트를 쓴다
- **구분자**: 쉼표·탭·세미콜론을 후보로 첫 몇 줄에서 가장 일관된 것을 고른다
- **형식 판별**: 확장자를 믿지 않고 ZIP 매직바이트로 xlsx를 가린다.
  안드로이드 `file_picker`가 확장자 없는 이름을 줄 수 있다
- **백업**: `backup_service.dart`의 `_prefKeys`에 `import_column_mappings_v1`을
  추가한다. 안 넣으면 복원 때 기억된 매핑이 사라진다

### 헤더 행 찾기

증권사 파일은 맨 위에 제목·계좌번호·조회일시가 붙는다. 1행을 헤더로 가정하면
깨진다. → **첫 20행을 훑어 사전에 걸리는 셀이 가장 많은 행**을 헤더로 고른다.
동점이면 위쪽. 하나도 안 걸리면 첫 비어있지 않은 행을 쓰고 사용자가 매핑한다.

### 열 이름 사전 (초기값)

실제 사용자 파일을 받지 못해 흔한 이름으로 시작한다. 비교는 공백·괄호 제거 후
소문자로.

| 역할 | 후보 |
|---|---|
| symbol **(필수)** | 종목코드, 단축코드, 종목번호, 코드, 티커, symbol, ticker, code |
| name | 종목명, 상품명, 종목, 주식명, 자산명, 이름, name, item |
| quantity **(필수)** | 수량, 보유수량, 잔고수량, 주식수, 보유주수, 결제수량, qty, quantity, shares |
| avgPrice | 평균단가, 매입단가, 평단가, 매입평균단가, 취득단가, avgprice, cost |
| currentPrice | 현재가, 종가, 평가단가, 시가, price |
| buyDate | 매수일, 매수일자, 거래일, 체결일, 취득일, date |

### 값 정규화

숫자 칸에서 천 단위 쉼표, 단위 표기(원·주·달러·퍼센트), 앞뒤 공백·따옴표를
걷어낸다. 괄호로 둘러싼 값은 음수로 읽는다. 빈 칸과 붙임표는 없는 값.
날짜는 `2026-01-02`, `2026.01.02`, `20260102`, `2026/01/02`를 받는다.

### 줄 하나가 통과하는 조건

`symbol` 있음 **그리고** `quantity`가 양수로 읽힘 **그리고** 유형이 정해짐
**그리고** 그 포트폴리오에 아직 없음.

`avgPrice`가 없으면 종목만 등록하고 거래·투자원금은 만들지 않는다. 미리보기에
`평균단가 없음 — 종목만 등록`으로 표시한다. 수량이 조용히 사라지지 않게.

통과 못 한 줄은 **사유별로 세어** 미리보기에 보여준다.

### 매핑 기억

파일 모양 서명 = 헤더 셀을 정규화·정렬해 이어붙인 문자열의 해시.
SharedPreferences 키 `import_column_mappings_v1`, 서명별로 역할→열이름을 JSON에 담는다.
**기억된 매핑이 자동 매핑보다 우선**한다.

### 가져오기 쓰기 경로

전체를 **단일 DB 트랜잭션**으로 감싼다. 중간에 실패하면 반쯤 들어간 상태가 남지
않아야 하고, 종목마다 쓰기를 날리면 조인된 drift `.watch()` 스트림이 매번 다시
발화해 화면이 버벅인다(백업 복원에서 겪은 문제).

줄마다: `getBySymbolAndType` 선조회 → 없으면 `assets` insert →
`portfolio_assets` insert(`targetWeight: 0`) → `avgPrice` 있으면 `transactions`
insert(`type: 'buy'`, `transactionDate`는 취득일, `memo`는 `파일 가져오기: <파일명>`).
마지막에 `investments` 한 건.

`currency`는 `AssetType.currency`에서 가져온다. 하드코딩하지 않는다.

### 포트폴리오 선택

기존 중 선택, 또는 새로 만들기. 새로 만들 때 이름 기본값은 파일명에서 확장자를
뗀 것. 사용자가 수정 가능.

## 파일 구성

새로 만드는 것:

```
lib/domain/entities/import_table.dart                    ImportTable, ColumnRole, ColumnMapping, ImportRow, ImportPreview, SkipReason
lib/domain/services/column_matcher.dart                  헤더 행 찾기, 사전 매핑, 값 정규화, 유형 추측
lib/data/datasources/local/table_file_ds.dart            파일 선택 → 바이트 → ImportTable (csv/xlsx/인코딩/구분자)
lib/data/datasources/local/import_mapping_local_ds.dart  매핑 기억
lib/presentation/providers/file_import_providers.dart
lib/presentation/screens/file_import/file_import_screen.dart
test/column_matcher_test.dart
test/table_file_ds_test.dart
```

손대는 기존 파일:

```
pubspec.yaml                          csv, excel, charset 추가
lib/core/router/app_router.dart       /file-import 라우트
.../settings/settings_screen.dart     ListTile 1개
.../kis/kis_import_screen.dart        'stock_kr' → AssetType.krStock.value, 선조회 방어
lib/data/database/app_database.dart   schemaVersion 3→4, onUpgrade 분기
lib/data/database/daos/asset_dao.dart stock_kr 일괄 갱신 메서드
lib/services/backup_service.dart      _prefKeys에 import_column_mappings_v1
```

## 빌더에게 맡기는 것

- 화면 위젯 세부 구성, 에러·경고 문구 표현
- 사전 항목 보강
- 테스트 케이스 구체화. 단 아래는 반드시 덮을 것:
  - EUC-KR 한글 종목명이 안 깨지는지
  - 상단 쓰레기 행이 있는 파일에서 헤더 행을 제대로 찾는지
  - 쉼표·단위·괄호 음수가 섞인 숫자 파싱
  - 날짜 네 가지 형식 파싱
  - 건너뛴 줄이 사유별로 정확히 세어지는지
  - 기억된 매핑이 자동 매핑을 덮어쓰는지
  - 이미 보유한 종목이 있어도 **가져오기가 실패하지 않고** 그 줄만 건너뛰는지
  - 투자원금 금액이 미국 종목 환산을 포함해 맞는지

## 승인 시 추가된 제약 (2026-11-22)

사용자 요구: **최대한 모듈화해서 기존 코드 영향을 최소화**할 것.

이에 따라 작업을 두 단계로 **쪼갠다**. 두 단계는 서로 독립이고 따로 검증한다.

**0단계 — `stock_kr` 정합성 수정 (가져오기 기능과 무관한 선행 버그 수정)**
`app_database.dart`, `asset_dao.dart`, `kis_import_screen.dart`.
이 세 파일이 "손대는 기존 파일" 목록이 커진 원인 전부다. 가져오기 기능과
섞지 않고 먼저 끝내 따로 검증한다. 되돌리기도 따로 된다.

**1단계 — 가져오기 기능 (새 파일 8개 + 기존 파일 3곳 한 줄씩)**
`pubspec.yaml`(패키지 3개), `app_router.dart`(라우트 1개),
`settings_screen.dart`(ListTile 1개), `backup_service.dart`(키 1개).
기능 로직은 **전부 새 파일**에 들어가고 기존 파일은 등록만 한다.

**모듈 경계 (1단계 내부)**

| 모듈 | 아는 것 | 모르는 것 |
|---|---|---|
| `table_file_ds` | 바이트 → 2차원 문자열 표 | 역할·자산·DB |
| `column_matcher` | 표 → 매핑·정규화 (**순수 함수, Flutter 비의존**) | 파일·DB·화면 |
| `import_mapping_local_ds` | 서명 → 매핑 기억 | 표 내용 |
| `import_writer` | 확정된 행 → DB 쓰기 | 파일 형식·화면 |
| `file_import_screen` | 화면 | 파싱·DB 세부 |

`column_matcher`와 `import_writer`를 나누는 이유: 파싱 로직은 Flutter 없이
테스트 가능해야 하고, DB 쓰기는 거래 내역 가져오기(다음 확장)에서 재사용된다.
