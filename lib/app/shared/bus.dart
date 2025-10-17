import 'package:event_bus/event_bus.dart';

@Deprecated("不建议使用")
class SettingEvent {
  bool nsfw;

  SettingEvent({this.nsfw = false});
}

class ShowNsfwSettingEvent {
  bool flag;
  ShowNsfwSettingEvent(this.flag);
}

EventBus $bus = EventBus();
