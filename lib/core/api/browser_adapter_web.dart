import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Web: let the browser manage cookies natively (withCredentials).
void configureBrowserAdapter(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}
