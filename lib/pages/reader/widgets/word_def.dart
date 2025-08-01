class WordDef {
  final String word, phonetic, translation, definition, pos, exchange;
  WordDef({
    required this.word,
    required this.phonetic,
    required this.translation,
    required this.definition,
    required this.pos,
    required this.exchange,
  });

  factory WordDef.fromMap(Map<String, dynamic> m) => WordDef(
        word: m['word'],
        phonetic: m['phonetic'] ?? '',
        translation: m['translation'] ?? '',
        definition: m['definition'] ?? '',
        pos: m['pos'] ?? '',
        exchange: m['exchange'] ?? '',
      );
}
