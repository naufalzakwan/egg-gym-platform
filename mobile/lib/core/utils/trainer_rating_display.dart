String trainerRatingDisplay({
  required double rating,
  required int reviewsCount,
}) {
  if (reviewsCount < 0) {
    throw ArgumentError.value(reviewsCount, 'reviewsCount', 'must be >= 0');
  }
  if (reviewsCount == 0) return 'Belum ada rating';
  if (!rating.isFinite || rating <= 0 || rating > 5) {
    throw ArgumentError.value(rating, 'rating', 'must be between 0 and 5');
  }

  return '${rating.toStringAsFixed(1)} • ${trainerReviewsLabel(reviewsCount)}';
}

String trainerReviewsLabel(int reviewsCount) {
  if (reviewsCount < 0) {
    throw ArgumentError.value(reviewsCount, 'reviewsCount', 'must be >= 0');
  }
  return '$reviewsCount ${reviewsCount == 1 ? 'review' : 'reviews'}';
}

String trainerOwnProfileRatingDisplay(double? rating) {
  if (rating == null || !rating.isFinite || rating <= 0 || rating > 5) {
    return '-';
  }
  return rating.toStringAsFixed(1);
}
