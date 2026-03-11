class Survey {
  final String id;
  final String siteId;
  final String title;
  final String? description;
  final DateTime? expiresAt;
  final bool isClosed;
  final List<SurveyOption> options;
  final DateTime createdAt;
  final String? siteName;

  Survey({
    required this.id,
    required this.siteId,
    required this.title,
    this.description,
    this.expiresAt,
    this.isClosed = false,
    this.options = const [],
    required this.createdAt,
    this.siteName,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isActive => !isClosed && !isExpired;

  factory Survey.fromMap(Map<String, dynamic> map, List<SurveyOption> options) {
    return Survey(
      id: map['id'],
      siteId: map['site_id'],
      title: map['title'],
      description: map['description'],
      expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at']).toLocal() : null,
      isClosed: map['is_closed'] ?? false,
      options: options,
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      siteName: map['sites']?['name'],
    );
  }
}

class SurveyOption {
  final String id;
  final String surveyId;
  final String text;
  final int voteCount;

  SurveyOption({
    required this.id,
    required this.surveyId,
    required this.text,
    this.voteCount = 0,
  });

  factory SurveyOption.fromMap(Map<String, dynamic> map) {
    return SurveyOption(
      id: map['id'],
      surveyId: map['survey_id'],
      text: map['text'],
      voteCount: map['vote_count'] ?? 0,
    );
  }
}
