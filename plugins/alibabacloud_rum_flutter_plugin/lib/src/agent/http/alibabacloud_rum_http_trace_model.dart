class AlibabaCloudRUMHttpTraceConfigModel {
  List<AlibabaCloudRUMRequestHeaderRule>? utl;
  List<AlibabaCloudRUMHostRule>? uwl;
  List<AlibabaCloudRUMHostRule>? ubl;

  AlibabaCloudRUMHttpTraceConfigModel.fromJson(Map<String, dynamic> json) {
    if (json['utl'] != null)
      utl = List.from(json['utl'])
          .map((e) => AlibabaCloudRUMRequestHeaderRule.fromJson(Map<String, dynamic>.from(e)))
          .toList();

    if (json['uwl'] != null)
      uwl = List.from(json['uwl']).map((e) => AlibabaCloudRUMHostRule.fromJson(Map<String, dynamic>.from(e))).toList();
    if (json['ubl'] != null)
      ubl = List.from(json['ubl']).map((e) => AlibabaCloudRUMHostRule.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}

class AlibabaCloudRUMHostRule {
  AlibabaCloudRUMHostRule({
    this.n,
    required this.t,
    required this.r,
    this.rhr,
  });
  String? n;
  late int t;
  late String r;
  List<AlibabaCloudRUMRequestHeaderRule>? rhr;

  AlibabaCloudRUMHostRule.fromJson(Map<String, dynamic> json) {
    n = json['n'];
    t = json['t'];
    r = json['r'];
    if (json['rhr'] != null)
      rhr = List.from(json['rhr'])
          .map((e) => AlibabaCloudRUMRequestHeaderRule.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  }
}

class AlibabaCloudRUMRequestHeaderRule {
  AlibabaCloudRUMRequestHeaderRule({
    required this.rht,
    this.rhv,
    required this.rhk,
    this.rhsr,
  });
  late String rhk;
  String? rhv;
  late int rht;
  int? rhsr;

  AlibabaCloudRUMRequestHeaderRule.fromJson(Map<String, dynamic> json) {
    rhk = json['rhk'];
    rht = json['rht'];
    rhv = json['rhv'];
    rhsr = json['rhsr'];
  }
}
