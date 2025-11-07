import 'dart:async';
import 'package:phone_state/phone_state.dart';

class CallStateManager {
  Timer? _answerDetectionTimer;
  StreamSubscription<PhoneState>? _phoneSub;

  void dispose() {
    _answerDetectionTimer?.cancel();
    _phoneSub?.cancel();
  }

  void setAnswerDetectionTimer(Timer timer) {
    _answerDetectionTimer = timer;
  }

  void cancelAnswerDetectionTimer() {
    _answerDetectionTimer?.cancel();
  }

  void setPhoneSubscription(StreamSubscription<PhoneState> sub) {
    _phoneSub = sub;
  }
}