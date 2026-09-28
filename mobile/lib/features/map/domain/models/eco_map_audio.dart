class EcoMapAudioGuide {
  const EcoMapAudioGuide({required this.title, required this.audioUrl});
  final String title;
  final String audioUrl;

  factory EcoMapAudioGuide.fromJson(Map<String, dynamic> json) =>
      EcoMapAudioGuide(
        title: json["title"] as String? ?? "Аудиогид",
        audioUrl: json["audio_url"] as String? ?? "",
      );
}

class EcoMapAudioQuizQuestion {
  const EcoMapAudioQuizQuestion({
    required this.question,
    required this.options,
    required this.correctOption,
  });
  final String question;
  final List<String> options;
  final int correctOption;

  factory EcoMapAudioQuizQuestion.fromJson(Map<String, dynamic> json) =>
      EcoMapAudioQuizQuestion(
        question: json["question"] as String? ?? "",
        options: (json["options"] as List<dynamic>? ?? const []).cast<String>(),
        correctOption: json["correct_option"] as int? ?? 0,
      );
}
