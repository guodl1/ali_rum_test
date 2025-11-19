import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:alibabacloud_rum_flutter_plugin/src/agent/alibabacloud_rum_agent_impl.dart';
import 'package:alibabacloud_rum_flutter_plugin/src/agent/http/alibabacloud_rum_http_trace_model.dart';
import 'package:uuid/uuid.dart';

import '../utils/utils.dart';

class AlibabaCloudRUMHttpTool {
  static Map<String, List<AlibabaCloudRUMRequestHeaderRule>> hostInsertKeyCache = {};
  static Map<String, Set<String>> hostRemoveKeyCache = {};

  //清缓存
  static void clearnTraceInsertCache() {
    hostInsertKeyCache.clear();
    hostRemoveKeyCache.clear();
  }

  static void insertKeyInRequest(HttpClientRequest request) {
    if (AlibabaCloudRUMImpl().isNetworkTraceEnabled) {
      if (request.uri.host.isNotEmpty) {
        List<AlibabaCloudRUMRequestHeaderRule>? hostRuleArr = hostInsertKeyCache[request.uri.host];
        if (hostRuleArr != null) {
          if (hostRuleArr.length > 0) {
            insertHeaderwithruleArr(request, hostRuleArr, hostRuleArr, false);
          }
          Set<String>? removeKeySet = hostRemoveKeyCache[request.uri.host];
          if (removeKeySet != null) {
            removeHeaderKeyWithBlackDicCache(request, removeKeySet);
          }
        } else {
          List<AlibabaCloudRUMRequestHeaderRule> insertCacheList = [];

          AlibabaCloudRUMHttpTraceConfigModel? trace = AlibabaCloudRUMImpl().traceConfigModel;
          if (trace != null) {
            List<AlibabaCloudRUMRequestHeaderRule>? totalList = trace.utl;
            //total insert
            if (totalList != null) {
              insertHeaderwithruleArr(request, totalList, insertCacheList, true);
            }
            List<AlibabaCloudRUMHostRule>? whiteList = trace.uwl;
            //whiteList insert
            if (whiteList != null) {
              insertHeaderKeyWithHostRuleList(request, whiteList, false, insertCacheList);
            }
            List<AlibabaCloudRUMHostRule>? blackList = trace.ubl;
            //blackList insert
            if (blackList != null) {
              insertHeaderKeyWithHostRuleList(request, blackList, true, insertCacheList);
            }
            hostInsertKeyCache[request.uri.host] = insertCacheList;

            Set<String>? removeKeySet = hostRemoveKeyCache[request.uri.host];
            if (removeKeySet != null) {
              removeHeaderKeyWithBlackDicCache(request, removeKeySet);
            }
          }
        }
      }
    }
  }

  static void removeHeaderKeyWithBlackDicCache(HttpClientRequest request, Set<String> removeKeySet) {
    if (removeKeySet.length > 0) {
      for (String keyString in removeKeySet) {
        String? keyValue = request.headers.value(keyString);
        if (keyValue != null) request.headers.remove(keyString, keyValue);
      }
    }
  }

  static void insertHeaderKeyWithHostRuleList(HttpClientRequest request, List<AlibabaCloudRUMHostRule> hostlist,
      bool isBlackList, List<AlibabaCloudRUMRequestHeaderRule> cacheList) {
    if (hostlist.length > 0) {
      for (AlibabaCloudRUMHostRule item in hostlist) {
        if (item.r.isEmpty) continue;
        if (item.t < 0 || item.t > 4) continue;
        bool match = matchRulesInHost(item, request.uri.host);
        bool canInsertKey = false;
        if (match && !isBlackList) canInsertKey = true;
        if (!match && isBlackList) canInsertKey = true;
        //域名规则匹配了黑名单这个域名就不要再插对应规则的键key
        if (match && isBlackList) {
          //把key存起来，最后移除
          Set<String>? hostRemoveKeySet = hostRemoveKeyCache[request.uri.host];
          if (hostRemoveKeySet == null) hostRemoveKeySet = Set();
          if (item.rhr != null) {
            for (AlibabaCloudRUMRequestHeaderRule headerRule in item.rhr!) {
              hostRemoveKeySet.add(headerRule.rhk);
            }
            hostRemoveKeyCache[request.uri.host] = hostRemoveKeySet;
          }
        }
        if (canInsertKey) {
          insertHeaderwithruleArr(request, item.rhr, cacheList, true);
        }
      }
    }
  }

  static bool matchRulesInHost(AlibabaCloudRUMHostRule rule, String host) {
    if (rule.t == 0) return host == rule.r; //全匹配
    if (rule.t == 1) return host.startsWith(rule.r); //前缀
    if (rule.t == 2) return host.endsWith(rule.r); //后缀
    if (rule.t == 3) {
      RegExp exp = RegExp(rule.r);
      return exp.hasMatch(host);
    }
    if (rule.t == 4) return host.contains(rule.r); //包含
    return false;
  }

  static void insertHeaderwithruleArr(HttpClientRequest request, List<AlibabaCloudRUMRequestHeaderRule>? headerRuleList,
      List<AlibabaCloudRUMRequestHeaderRule> ruleCacheList, bool cache) {
    if (headerRuleList != null) {
      if (headerRuleList.isNotEmpty) {
        for (AlibabaCloudRUMRequestHeaderRule rule in headerRuleList) {
          if (rule.rhk.isNotEmpty) {
            RegExp exp = RegExp('^[0-9a-zA-Z_-]{1,256}\$');
            if (!exp.hasMatch(rule.rhk)) continue;
            String headValue = returnValueAccordingGivenRequestHeaderRule(rule, request, rule.rhsr);
            RegExp expValue = RegExp('^[\x09\x20-\x7E]{1,512}\$');
            if (expValue.hasMatch(headValue)) {
              request.headers.set(rule.rhk, headValue);
              if (cache) ruleCacheList.add(rule);
            }
          }
        }
      }
    }
  }

  static String returnValueAccordingGivenRequestHeaderRule(
      AlibabaCloudRUMRequestHeaderRule rule, HttpClientRequest request, int? sampleRate) {
    switch (rule.rht) {
      case 1: //固定值
        return rule.rhv ?? "";
      case 2: //16uuid
        return getRandomNumberStr(16);
      case 3: //32uuid
        return getRandomNumberStr(32);
      case 4: //skywalking
        return getSkyWalkingKey(request, sampleRate);
      case 5: //traceparent
        return getTraceParentKey(sampleRate);
      case 6: //tracestate
        return getTraceStateKey("iOS");
      default:
        break;
    }
    return "";
  }

  //获取插件版本
  static String getPluginVersion() {
    return "3.3.0";
  }

  //getTraceParentKey
  static String getTraceParentKey(int? sampleRate) {
    String uuid = Uuid().v1().replaceAll("-", "");
    String randomStr = getRandomNumberStr(16);

    // traceparent规则下，采样率未下发或下发值不在[0,100]范围内，按不采样处理
    String sampleStr = "00";
    int rate = sampleRate ?? -1;
    if (rate >= 0 && rate <= 100) {
      sampleStr = isHitProbability(rate) ? "01" : "00";
    }

    return "00-$uuid-$randomStr-$sampleStr";
  }

  //getTraceStateKey
  static String getTraceStateKey(String brnoHead) {
    return "bnro=${brnoHead}_flutter-plugin/" + getPluginVersion() + "_HttpClient";
  }

  static String getSkyWalkingKey(HttpClientRequest request, int? sampleRate) {
    // skywalking规则下，采样率未下发或下发值不在[0,100]范围内，按采样处理
    String sample = "1";
    int rate = sampleRate ?? -1;
    if (rate >= 0 && rate <= 100) {
      sample = isHitProbability(rate) ? "1" : "0";
    }

    String base64traceId = base64Encode(utf8.encode(Uuid().v1()));
    String base64SegmentId = base64Encode(utf8.encode(Uuid().v1()));
    String base64Service = base64Encode(utf8.encode("app"));
    String base64Instance = base64Encode(utf8.encode("1.0"));
    String path = request.uri.path.isEmpty ? "/" : request.uri.path;
    String base64EndPoint = base64Encode(utf8.encode(path));

    String base64Host = base64Encode(utf8.encode(request.uri.host.isEmpty ? " " : request.uri.host));
    return "$sample-$base64traceId-$base64SegmentId-0-$base64Service-$base64Instance-$base64EndPoint-$base64Host";
  }

  static String getRandomNumberStr(int length) {
    String alphabet = 'abcdef123456789';

    /// 生成的字符串固定长度
    String randomStr = '';
    for (var i = 0; i < length; i++) {
      randomStr = randomStr + alphabet[Random().nextInt(alphabet.length)];
    }
    return randomStr;
  }
}
