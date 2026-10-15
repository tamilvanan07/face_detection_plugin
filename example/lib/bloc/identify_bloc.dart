import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../db/objectbox_store.dart';

// ── Events ─────────────────────────────────────────────────────────────────────

abstract class IdentifyEvent extends Equatable {
  const IdentifyEvent();
  @override
  List<Object?> get props => [];
}

/// Fired on every camera frame that carries an embedding.
class IdentifyFrameReceived extends IdentifyEvent {
  const IdentifyFrameReceived(this.embedding);
  final List<double> embedding;
  @override
  List<Object?> get props => [embedding];
}

/// Fired when the user taps "Scan Again" to reset.
class IdentifyReset extends IdentifyEvent {
  const IdentifyReset();
}

// ── States ─────────────────────────────────────────────────────────────────────

abstract class IdentifyState extends Equatable {
  const IdentifyState();
  @override
  List<Object?> get props => [];
}

/// Initial state — camera is running, no face seen yet.
class IdentifyScanning extends IdentifyState {
  const IdentifyScanning();
}

/// A face is in frame but similarity < 75%.
class IdentifyUnknown extends IdentifyState {
  const IdentifyUnknown();
}

/// Match ≥ 75% found. This state is terminal — the BLoC
/// ignores all further IdentifyFrameReceived events until reset.
class IdentifyMatched extends IdentifyState {
  const IdentifyMatched(this.result);
  final FaceRecognitionResult result;
  @override
  List<Object?> get props => [result.record.id, result.similarityScore];
}

// ── BLoC ───────────────────────────────────────────────────────────────────────

class IdentifyBloc extends Bloc<IdentifyEvent, IdentifyState> {
  IdentifyBloc({required this.store}) : super(const IdentifyScanning()) {
    on<IdentifyFrameReceived>(_onFrame);
    on<IdentifyReset>(_onReset);
  }

  final ObjectBoxVectorStore store;

  void _onFrame(IdentifyFrameReceived event, Emitter<IdentifyState> emit) {
    // Once matched, ignore all further frames — card stays locked.
    if (state is IdentifyMatched) return;

    final result = store.findNearestFace(event.embedding, threshold: 0.75);

    if (result != null) {
      emit(IdentifyMatched(result));
    } else {
      // Only emit IdentifyUnknown if not already in that state (avoid noise).
      if (state is! IdentifyUnknown) emit(const IdentifyUnknown());
    }
  }

  void _onReset(IdentifyReset event, Emitter<IdentifyState> emit) {
    emit(const IdentifyScanning());
  }
}
