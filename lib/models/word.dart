/// Kelime türleri (UI'da Türkçe etiketle gösterilir).
enum PartOfSpeech {
  noun('n', 'İsim'),
  verb('v', 'Fiil'),
  adjective('adj', 'Sıfat'),
  adverb('adv', 'Zarf'),
  pronoun('pron', 'Zamir'),
  preposition('prep', 'Edat'),
  conjunction('conj', 'Bağlaç'),
  number('num', 'Sayı'),
  determiner('det', 'Belirleyici'),
  interjection('int', 'Ünlem'),
  phrase('phr', 'Kalıp');

  const PartOfSpeech(this.code, this.label);
  final String code;
  final String label;

  static PartOfSpeech fromCode(String code) =>
      values.firstWhere((p) => p.code == code, orElse: () => PartOfSpeech.phrase);

  /// Çalış ekranındaki kategori filtreleri için gruplama.
  StudyCategory get category => switch (this) {
        PartOfSpeech.noun => StudyCategory.nouns,
        PartOfSpeech.verb => StudyCategory.verbs,
        PartOfSpeech.adjective => StudyCategory.adjectives,
        PartOfSpeech.adverb => StudyCategory.adverbs,
        _ => StudyCategory.other,
      };
}

enum StudyCategory {
  nouns('İsim'),
  verbs('Fiil'),
  adjectives('Sıfat'),
  adverbs('Zarf'),
  other('Diğer');

  const StudyCategory(this.label);
  final String label;
}

const topicLabels = <String, String>{
  'greetings': 'Selamlaşma',
  'people': 'İnsanlar',
  'family': 'Aile',
  'numbers': 'Sayılar',
  'time': 'Zaman',
  'weather': 'Hava ve mevsimler',
  'colors': 'Renkler',
  'food': 'Yiyecek ve içecek',
  'home': 'Ev',
  'daily': 'Günlük hayat',
  'school': 'Okul',
  'work': 'İş',
  'shopping': 'Alışveriş',
  'clothes': 'Giyim',
  'city': 'Şehir',
  'travel': 'Seyahat',
  'nature': 'Doğa',
  'body': 'Vücut',
  'health': 'Sağlık',
  'feelings': 'Duygular',
  'general': 'Genel',
  'custom': 'Kendi kelimelerim',
};

class Word {
  const Word({
    required this.id,
    required this.en,
    required this.tr,
    required this.pos,
    required this.level,
    required this.topic,
    required this.exampleEn,
    required this.exampleTr,
    this.isCustom = false,
  });

  final String id;
  final String en;

  /// Kabul edilen Türkçe karşılıklar; ilki ana anlamdır.
  final List<String> tr;
  final PartOfSpeech pos;
  final String level; // A1, A2, ...
  final String topic;
  final String exampleEn;
  final String exampleTr;
  final bool isCustom;

  String get mainTr => tr.first;

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        id: j['id'] as String,
        en: j['en'] as String,
        tr: (j['tr'] as List).cast<String>(),
        pos: PartOfSpeech.fromCode(j['pos'] as String),
        level: j['level'] as String,
        topic: j['topic'] as String,
        exampleEn: j['exEn'] as String? ?? '',
        exampleTr: j['exTr'] as String? ?? '',
        isCustom: j['custom'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'en': en,
        'tr': tr,
        'pos': pos.code,
        'level': level,
        'topic': topic,
        'exEn': exampleEn,
        'exTr': exampleTr,
        'custom': isCustom,
      };
}
