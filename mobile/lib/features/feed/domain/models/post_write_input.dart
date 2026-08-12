class PostWriteInput {
  const PostWriteInput({
    required this.title,
    required this.body,
    required this.kind,
    required this.isPublished,
    required this.imageUrls,
    this.eventDate,
    this.eventStartsAt,
    this.eventEndsAt,
    this.eventLocation = "",
  });

  final String title;
  final String body;
  final String kind;
  final bool isPublished;
  final List<String> imageUrls;
  final DateTime? eventDate;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final String eventLocation;
}
