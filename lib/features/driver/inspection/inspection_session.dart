/// Simple in-memory store shared between checklist → review screens.
/// No state management library needed.
class InspectionSession {
  InspectionSession._();
  static final InspectionSession _i = InspectionSession._();
  static InspectionSession get instance => _i;

  int?   truckId;
  String truckUnit = '';
  String inspectionType = 'pre_trip';

  // Set when editing a previously submitted inspection (non-null = edit mode)
  int?   existingInspectionId;

  // [{category, label, status (true/false/null), note}]
  List<Map<String, dynamic>> checklistItems = [];

  // [{label, severity, note}]
  List<Map<String, dynamic>> issues = [];

  int get totalItems  => checklistItems.length;
  int get passedItems => checklistItems.where((i) => i['status'] == true).length;
  int get failedItems => checklistItems.where((i) => i['status'] == false).length;

  void clear() {
    truckId             = null;
    truckUnit           = '';
    inspectionType      = 'pre_trip';
    existingInspectionId = null;
    checklistItems      = [];
    issues              = [];
  }
}
