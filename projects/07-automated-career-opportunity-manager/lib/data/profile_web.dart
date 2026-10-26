import 'dart:js_interop';

@JS('careerProfile')
external JSPromise<JSString> request(
  JSString method,
  JSString path,
  JSString body,
);
@JS('careerUpload')
external JSPromise<JSString> upload(JSString category);
@JS('careerOpen')
external void open(JSString url);
Future<String> profileRequest(String method, String path, String body) async =>
    (await request(method.toJS, path.toJS, body.toJS).toDart).toDart;
Future<String> uploadDocument(String category) async =>
    (await upload(category.toJS).toDart).toDart;
void openDocument(String url) => open(url.toJS);

@JS('careerPhoto')
external JSPromise<JSString> photo();
Future<String> uploadPhoto() async => (await photo().toDart).toDart;
