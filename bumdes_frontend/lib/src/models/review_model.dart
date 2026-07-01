class ReviewModel {
  final int id;
  final String reviewerName;
  final String comment;
  final int rating;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.reviewerName,
    required this.comment,
    required this.rating,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as int? ?? 0,
      reviewerName: json['reviewer_name'] as String? ?? 'Anonim',
      comment: json['comment'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
