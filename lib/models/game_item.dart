class GameItem {
  final String title;
  final String console;
  final String pageUrl;
  final String? coverUrl;
  final String? inGamePreviewUrl;
  final String? localRomPath;
  final bool isDownloaded;
  final String? fileSize;
  final bool isFavorite;
  final bool hasSaveState;
  final DateTime? lastPlayed;

  GameItem({
    required this.title,
    required this.console,
    required this.pageUrl,
    this.coverUrl,
    this.inGamePreviewUrl,
    this.localRomPath,
    this.isDownloaded = false,
    this.fileSize,
    this.isFavorite = false,
    this.hasSaveState = false,
    this.lastPlayed,
  });

  GameItem copyWith({
    String? title,
    String? console,
    String? pageUrl,
    String? coverUrl,
    String? inGamePreviewUrl,
    String? localRomPath,
    bool? isDownloaded,
    String? fileSize,
    bool? isFavorite,
    bool? hasSaveState,
    DateTime? lastPlayed,
  }) {
    return GameItem(
      title: title ?? this.title,
      console: console ?? this.console,
      pageUrl: pageUrl ?? this.pageUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      inGamePreviewUrl: inGamePreviewUrl ?? this.inGamePreviewUrl,
      localRomPath: localRomPath ?? this.localRomPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      fileSize: fileSize ?? this.fileSize,
      isFavorite: isFavorite ?? this.isFavorite,
      hasSaveState: hasSaveState ?? this.hasSaveState,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'console': console,
    'pageUrl': pageUrl,
    'coverUrl': coverUrl,
    'inGamePreviewUrl': inGamePreviewUrl,
    'localRomPath': localRomPath,
    'isDownloaded': isDownloaded,
    'fileSize': fileSize,
    'isFavorite': isFavorite,
    'hasSaveState': hasSaveState,
    'lastPlayed': lastPlayed?.toIso8601String(),
  };

  factory GameItem.fromJson(Map<String, dynamic> json) => GameItem(
    title: json['title'] ?? '',
    console: json['console'] ?? 'nes',
    pageUrl: json['pageUrl'] ?? '',
    coverUrl: json['coverUrl'],
    inGamePreviewUrl: json['inGamePreviewUrl'],
    localRomPath: json['localRomPath'],
    isDownloaded: json['isDownloaded'] ?? false,
    fileSize: json['fileSize'],
    isFavorite: json['isFavorite'] ?? false,
    hasSaveState: json['hasSaveState'] ?? false,
    lastPlayed: json['lastPlayed'] != null ? DateTime.tryParse(json['lastPlayed']) : null,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameItem &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          console == other.console &&
          localRomPath == other.localRomPath;

  @override
  int get hashCode => Object.hash(title, console, localRomPath);
}
