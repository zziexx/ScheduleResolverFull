import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/task_model.dart';
import '../models/schedule_analysis.dart';

class AiScheduleService extends ChangeNotifier{

  ScheduleAnalysis? _currentAnalysis;
  bool _isLoading = false;
  String? _errorMessage;

  ScheduleAnalysis? get currentAnalysis => _currentAnalysis;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final String _apiKey = 'AIzaSyBoYFn7zSybLyimzmj_CUVscir7VXwbWy4';

  Future<void> analyzeSchedule(List<TaskModel> tasks) async {

    if(_apiKey.isEmpty || tasks.isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      final tasksJson = jsonEncode(tasks.map((t) => t.toJson()).toList());
      final prompt = '''
        
        You are an expert student scheduling assistant. The user has provided the following tasks for their day in JSON format: $tasksJson
        
        Your job is to analyze these tasks, identify any overlaps or conflicts in their start and end time and suggest a better balanced schedule.
        Consider their urgency, importance, and required energy level.
      
        Please provide exactly 4 sections of markdown text:
        ### Detected Conflicts
        List any Scheduling conflicts.
        ### Ranked Tasks
        Rank which tasks need attention first based on the urgency, importance and energy. Provide a brief reason on each.
        ### Recommended Schedule
        Provide a revised daily timeline view adjusting the task time.
        ### Explanation
        Explain why this Recommendation was made.
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      _currentAnalysis = _parseResponse(response.text ?? '');

    } catch (e) {
      _errorMessage = 'Failed: $e';
      } finally {
          _isLoading = false;
          notifyListeners();
    }
  }

  ScheduleAnalysis _parseResponse (String fullText) {
    String conflicts = "No conflicts detected.",
        rankedTasks = "No tasks ranked.",
        recommendedSchedule ="No recommendations.",
        explanation = "No explanation available.";

    final sections = fullText.split('### ');

    for (var section in sections) {
      String sectionLower = section.toLowerCase();
      if (sectionLower.startsWith('detected conflicts')) {
        conflicts = section.replaceFirst(RegExp(r'detected conflicts', caseSensitive: false), '').trim();
      } else if (sectionLower.startsWith('ranked tasks')) {
        rankedTasks = section.replaceFirst(RegExp(r'ranked tasks', caseSensitive: false), '').trim();
      } else if (sectionLower.startsWith('recommended schedule')) {
        recommendedSchedule = section.replaceFirst(RegExp(r'recommended schedule', caseSensitive: false), '').trim();
      } else if (sectionLower.startsWith('explanation')) {
        explanation = section.replaceFirst(RegExp(r'explanation', caseSensitive: false), '').trim();
      }
    }

    return ScheduleAnalysis(
        conflicts: conflicts,
        rankedTasks: rankedTasks,
        recommendedSchedule: recommendedSchedule,
        explanation: explanation
    );
  }
}