class CricketMatch {
  final String id;
  final String teamA;
  final String teamB;
  final String? status;
  final String? venue;
  final String? score;
  final String? overs;
  final DateTime? startTime;
  final bool isIndiaMatch;

  CricketMatch({
    required this.id,
    required this.teamA,
    required this.teamB,
    this.status,
    this.venue,
    this.score,
    this.overs,
    this.startTime,
    required this.isIndiaMatch,
  });

  factory CricketMatch.fromCricApiJson(Map<String, dynamic> json) {
    final teamInfo = json['teams'] as List<dynamic>? ?? [];
    final teamA = teamInfo.isNotEmpty ? teamInfo.first as String : 'Team A';
    final teamB = teamInfo.length > 1 ? teamInfo[1] as String : 'Team B';

    final isIndia = teamA.toLowerCase().contains('india') ||
        teamB.toLowerCase().contains('india');

    final scores = json['score'] as List<dynamic>? ?? [];
    String? scoreStr;
    String? oversStr;
    if (scores.isNotEmpty) {
      final s = scores.first as Map<String, dynamic>;
      scoreStr = s['r'] != null && s['w'] != null
          ? '${s['r']}/${s['w']}'
          : null;
      oversStr = s['o']?.toString();
    }

    return CricketMatch(
      id: json['id']?.toString() ?? '',
      teamA: teamA,
      teamB: teamB,
      status: json['status'] as String?,
      venue: json['venue'] as String?,
      score: scoreStr,
      overs: oversStr,
      startTime: json['dateTimeGMT'] != null
          ? DateTime.tryParse(json['dateTimeGMT'] as String)
          : null,
      isIndiaMatch: isIndia,
    );
  }
}


