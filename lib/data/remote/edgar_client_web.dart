/// Web SEC EDGAR client: browsers cannot set the User-Agent header the SEC
/// requires, and CORS blocks data.sec.gov, so this build reports the feed as
/// unavailable rather than attempting a request that must fail.
library;

import '../models/fundamentals.dart';
import 'edgar_client.dart';

class WebEdgarClient implements EdgarClient {
  @override
  bool get supported => false;

  @override
  Future<String?> resolveCik(String ticker) async => null;

  @override
  Future<FundamentalSnapshot> fetchFundamentals(String ticker, {required String userAgent}) async {
    throw const DataFeedUnavailable(
      'SEC EDGAR',
      'Browsers cannot set the User-Agent header the SEC requires, so fundamentals are only fetched in the Android and Windows builds.',
    );
  }
}
