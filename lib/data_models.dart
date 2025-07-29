// data_models.dart

import 'package:collection/collection.dart';

enum PoActionStatus {
  geenActie,
  mustFix,
  couldFix,
  wontFix,
  geparkeerd,
  backlogTicket,
  nietVanToepassing,
}

String poActionStatusToString(PoActionStatus status) {
  switch (status) {
    case PoActionStatus.geenActie:
      return 'Geen Actie';
    case PoActionStatus.mustFix:
      return 'Must Fix';
    case PoActionStatus.couldFix:
      return 'Could Fix';
    case PoActionStatus.wontFix:
      return 'Won\'t Fix';
    case PoActionStatus.geparkeerd:
      return 'Geparkeerd';
    case PoActionStatus.backlogTicket:
      return 'Backlog Ticket';
    case PoActionStatus.nietVanToepassing:
      return 'Niet van Toepassing';
    default:
      return '';
  }
}

class TestStep {
  int id;
  String title;
  String description;
  String finding;
  String category;
  List<String> poImageUrls;
  List<String> testerImageUrls;
  PoActionStatus poAction;
  String? result;

  TestStep({
    required this.id,
    required this.title,
    required this.description,
    this.finding = '',
    this.category = 'Algemeen',
    this.poAction = PoActionStatus.geenActie,
    this.poImageUrls = const [],
    this.testerImageUrls = const [],
    this.result,
  });

  factory TestStep.fromJson(Map<String, dynamic> json) {
    return TestStep(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      finding: json['finding'] ?? '',
      category: json['category'] ?? 'Algemeen',
      poImageUrls: List<String>.from(json['po_image_urls'] ?? []),
      testerImageUrls: List<String>.from(json['tester_image_urls'] ?? []),
      poAction: PoActionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['po_action'],
        orElse: () => PoActionStatus.geenActie,
      ),
      result: json['result'],
    );
  }

  TestStep copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
  }) {
    return TestStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      poImageUrls: List<String>.from(poImageUrls),
      finding: '',
      testerImageUrls: [],
      result: null,
      poAction: PoActionStatus.geenActie,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'finding': finding,
      'category': category,
      'po_image_urls': poImageUrls,
      'tester_image_urls': testerImageUrls,
      'po_action': poAction.toString().split('.').last,
      'result': result,
    };
  }
}

class TestPlan {
  int? id; // Nullable for new plans, Supabase generates it
  String productName;
  String version;
  String testDate;
  String testerName;
  String? testerId;
  String ownerId; // UUID of the PO who created it
  List<TestStep> steps;
  List<String> createdTestAccounts;

  TestPlan({
    this.id,
    required this.productName,
    required this.version,
    this.testDate = '',
    this.testerName = '',
    this.testerId,
    this.ownerId = '',
    required this.steps,
    this.createdTestAccounts = const [],
  });

  factory TestPlan.fromJson(Map<String, dynamic> json) {
    return TestPlan(
      id: json['id'],
      productName: json['product_name'] ?? '',
      version: json['version'] ?? '',
      testDate: json['test_date'] ?? '',
      testerName: json['tester_name'] ?? '',
      testerId: json['tester_id'],
      ownerId: json['owner_id'] ?? '',
      steps: (json['steps'] as List<dynamic>?)
              ?.map((stepJson) => TestStep.fromJson(stepJson as Map<String, dynamic>))
              .toList() ??
          [],
      createdTestAccounts: List<String>.from(json['created_test_accounts'] ?? []),
    );
  }

  // Aparte toJson voor Supabase om snake_case te gebruiken en de ID weg te laten bij insert
  Map<String, dynamic> toSupabaseJson() {
    final data = {
      'product_name': productName,
      'version': version,
      'test_date': testDate,
      'tester_name': testerName,
      'tester_id': testerId,
      'owner_id': ownerId,
      'steps': steps.map((step) => step.toJson()).toList(),
      'created_test_accounts': createdTestAccounts,
    };
    // Voeg ID alleen toe als het bestaat (voor updates)
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }
}
