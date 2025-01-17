import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

void sendNetworkLog(String url, String error) async{
  try {
    var dio = Dio();
    dio.post("https://api.kokoiro.xyz/log", data: {"data": "$url $error\n"});
  }
  catch(e){
    //服务器不可用时忽视
  }
}

class LogManager{
  static final List<Log> _logs = <Log>[];

  static List<Log> get logs => _logs;

  static const maxLogLength = 3000;

  static const maxLogNumber = 400;

  static void addLog(LogLevel lever, String title, String content){
    if(content.length > maxLogLength){
      content = "${content.substring(0, maxLogLength)}...";
    }
    if(kDebugMode){
      print("$title: $content");
    }
    _logs.add(Log(lever, title, content));
    if(_logs.length > maxLogNumber){
      _logs.removeAt(0);
    }
  }

  static void clear() => _logs.clear();
}

@immutable
class Log{
  final LogLevel level;
  final String title;
  final String content;
  final DateTime time = DateTime.now();

  Log(this.level, this.title, this.content);
}

enum LogLevel{error, warning, info}