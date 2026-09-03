import 'package:equatable/equatable.dart';

enum CampfireCardType {
  sharedPassion,     // Coincidencia directa en gustos
  curiousContrast,   // Contraste divertido / estilos opuestos
  deepConnection,    // Intención compartida o valores humanos
  discoveryWildcard, // Fallback: Cero afinidad común
  mirrorComplicity,  // Fallback: Gustos idénticos / Sin contrastes
  universalValues,   // Fallback: Intenciones de cita diferentes
}

class CampfireOption extends Equatable {
  final String id;
  final String text;
  final String emoji;

  const CampfireOption({
    required this.id,
    required this.text,
    required this.emoji,
  });

  @override
  List<Object?> get props => [id, text, emoji];
}

class CampfireCard extends Equatable {
  final String id;
  final CampfireCardType type;
  final String categoryHeader;
  final String question;
  final String? subtitle;
  final String? matchReason;
  final List<CampfireOption> options;

  const CampfireCard({
    required this.id,
    required this.type,
    required this.categoryHeader,
    required this.question,
    this.subtitle,
    this.matchReason,
    required this.options,
  });

  CampfireCard copyWith({
    String? id,
    CampfireCardType? type,
    String? categoryHeader,
    String? question,
    String? subtitle,
    String? matchReason,
    List<CampfireOption>? options,
  }) {
    return CampfireCard(
      id: id ?? this.id,
      type: type ?? this.type,
      categoryHeader: categoryHeader ?? this.categoryHeader,
      question: question ?? this.question,
      subtitle: subtitle ?? this.subtitle,
      matchReason: matchReason ?? this.matchReason,
      options: options ?? this.options,
    );
  }

  @override
  List<Object?> get props => [id, type, categoryHeader, question, subtitle, matchReason, options];
}

class CampfireAnswerState extends Equatable {
  final int currentRound; // 0, 1, 2
  final String? localSelectedOptionId;
  final String? partnerSelectedOptionId;
  final bool isRevealed;

  const CampfireAnswerState({
    this.currentRound = 0,
    this.localSelectedOptionId,
    this.partnerSelectedOptionId,
    this.isRevealed = false,
  });

  CampfireAnswerState copyWith({
    int? currentRound,
    String? localSelectedOptionId,
    String? partnerSelectedOptionId,
    bool? isRevealed,
  }) {
    return CampfireAnswerState(
      currentRound: currentRound ?? this.currentRound,
      localSelectedOptionId: localSelectedOptionId ?? this.localSelectedOptionId,
      partnerSelectedOptionId: partnerSelectedOptionId ?? this.partnerSelectedOptionId,
      isRevealed: isRevealed ?? this.isRevealed,
    );
  }

  @override
  List<Object?> get props => [
        currentRound,
        localSelectedOptionId,
        partnerSelectedOptionId,
        isRevealed,
      ];
}
