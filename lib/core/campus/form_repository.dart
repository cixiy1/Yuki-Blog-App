import '../../models/campus/campus_form.dart';
import '../../models/campus/json_utils.dart';
import '../../models/campus/paged.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

abstract interface class FormRepository {
  /// [filter] 取 `open` / `todo`（还没填的）/ `mine` / `all`。
  Future<Paged<CampusForm>> list({String filter = 'open', int page = 1});

  Future<CampusForm> detail(String id);

  Future<CampusForm> create({
    required String title,
    required List<FormFieldSpec> fields,
    String description = '',
    String? deadline,
    bool schoolWide = false,
  });

  /// 有人提交过就不能再改题目，服务端会拒（409）。
  Future<CampusForm> update(
    String id, {
    String? title,
    String? description,
    String? deadline,
    List<FormFieldSpec>? fields,
    bool? schoolWide,
  });

  Future<CampusForm> close(String id);

  /// 提交或覆盖自己那份。
  Future<CampusForm> submit(String id, Map<String, dynamic> answers);

  Future<List<FormSubmission>> submissions(String id);

  /// 给还没填的人发提醒，返回提醒了几个人。
  Future<int> remind(String id);
}

class ApiFormRepository implements FormRepository {
  ApiFormRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paged<CampusForm>> list({String filter = 'open', int page = 1}) async {
    final result = await _api.get(
      ApiPaths.forms,
      query: {'filter': filter, 'page': '$page'},
    );
    return Paged.fromJson(result, CampusForm.fromJson);
  }

  @override
  Future<CampusForm> detail(String id) async {
    final result = await _api.get(ApiPaths.formOne(id));
    return CampusForm.fromJson(asMap(result));
  }

  @override
  Future<CampusForm> create({
    required String title,
    required List<FormFieldSpec> fields,
    String description = '',
    String? deadline,
    bool schoolWide = false,
  }) async {
    final result = await _api.post(
      ApiPaths.forms,
      body: {
        'title': title,
        'description': description,
        'fields': [for (final f in fields) f.toJson()],
        'deadline': ?deadline,
        'scope': schoolWide ? 'schoolWide' : 'classOnly',
      },
    );
    return CampusForm.fromJson(asMap(result));
  }

  @override
  Future<CampusForm> update(
    String id, {
    String? title,
    String? description,
    String? deadline,
    List<FormFieldSpec>? fields,
    bool? schoolWide,
  }) async {
    final result = await _api.patch(
      ApiPaths.formOne(id),
      body: {
        'title': ?title,
        'description': ?description,
        'deadline': ?deadline,
        if (fields != null) 'fields': [for (final f in fields) f.toJson()],
        if (schoolWide != null)
          'scope': schoolWide ? 'schoolWide' : 'classOnly',
      },
    );
    return CampusForm.fromJson(asMap(result));
  }

  @override
  Future<CampusForm> close(String id) async {
    final result = await _api.post(ApiPaths.formClose(id));
    return CampusForm.fromJson(asMap(result));
  }

  @override
  Future<CampusForm> submit(String id, Map<String, dynamic> answers) async {
    final result = await _api.post(
      ApiPaths.formSubmissions(id),
      body: {'answers': answers},
    );
    return CampusForm.fromJson(asMap(result));
  }

  @override
  Future<List<FormSubmission>> submissions(String id) async {
    final result = await _api.get(ApiPaths.formSubmissions(id));
    return Paged.fromJson(result, FormSubmission.fromJson).items;
  }

  @override
  Future<int> remind(String id) async {
    final result = await _api.post(ApiPaths.formRemind(id));
    final map = asMap(result);
    return asInt(map['reminded']);
  }
}
