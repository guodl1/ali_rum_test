package com.alibabacloud.rum.flutter_plugin;

import java.util.Map;
import java.util.HashMap;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

//import com.alibabacloud.rum.AlibabaCloudRum;
import com.alibabacloud.rum.android.sdk.AlibabaCloudRum;
/**
 * AlibabaCloudRUMFlutterPlugin
 */
public class AlibabaCloudRUMFlutterPlugin implements FlutterPlugin, MethodCallHandler {

    private static MethodChannel channel;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "alibabacloud_rum_flutter_plugin");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    public static void setNetworkTraceConfig(Map map) {
        if (map == null || channel == null) {
            return;
        }
        try {
            channel.invokeMethod("setNetworkTraceConfig", map);
        } catch (Throwable e) {
        }
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        try {
            if ("reportCrash".equals(call.method)) {
                AlibabaCloudRum.flutterReportException((String) call.argument("errorValue"), (String) call.argument("reason"), (String) call.argument("stacktrace"));
            } else if ("reportView".equals(call.method)) {
                long time = call.argument("time");
                String viewId = call.argument("viewId");
                int loadTime = call.argument("loadTime");
                int model = call.argument("model");
                String name = call.argument("name");
                String method = call.argument("method");
                AlibabaCloudRum.flutterReportView(viewId, loadTime, model == 1, name, method);
            } else if ("setCustomException".equals(call.method)) {
                AlibabaCloudRum.flutterReportCustomException((String) call.argument("exceptionType"), (String) call.argument("causedBy"), (String) call.argument("errorDump"));
            } else if ("setCustomEvent".equals(call.method)) {
                AlibabaCloudRum.setCustomEvent(
                    (String) call.argument("name"),
                    null == call.argument("value") ? "0" : String.valueOf((Double)call.argument("value")),
                    (String) call.argument("group"),
                    (String) call.argument("snapshots"),
                    (Map) call.argument("attributes")
                );
            } else if ("setCustomLog".equals(call.method)) {
                AlibabaCloudRum.setCustomLog(
                    (String) call.argument("logInfo"), 
                    (String) call.argument("name"),
                    (String) call.argument("level"),
                    (String) call.argument("snapshots"),
                    (Map) call.argument("attributes")
                );
            } else if ("setUserID".equals(call.method)) {
                String id = call.argument("userID");
                AlibabaCloudRum.setUserName(id);
            } else if ("setUserExtraInfo".equals(call.method)) {
                Map<String, Object> map = call.arguments();
                AlibabaCloudRum.setUserExtraInfo(map);
            } else if ("addUserExtraInfo".equals(call.method)) {
                Map<String, Object> map = call.arguments();
                AlibabaCloudRum.addUserExtraInfo(map);
            } else if ("setExtraInfo".equals(call.method)) {
                Map<String, Object> map = call.arguments();
                AlibabaCloudRum.setExtraInfo(map);
            }  else if ("addExtraInfo".equals(call.method)) {
                Map<String, Object> map = call.arguments();
                AlibabaCloudRum.addExtraInfo(map);
            } else if ("reportNetwork".equals(call.method)) {
                AlibabaCloudRum.flutterReportResource(
                    (String) call.argument("requestUrl"), (String) call.argument("method"),
                    (Integer) call.argument("connectTimeMs"), (Integer) call.argument("responseTimeMs"),
                    (String) call.argument("resourceType"), (Integer) call.argument("responseDataSize"),
                    String.valueOf((Integer)call.argument("errorCode")), (String) call.argument("errorMessage"),
                    (Map) call.argument("httpRequestHeader"), (Map) call.argument("httpResponseHeader")
                );
            } else if ("getNetworkTraceConfig".equals(call.method)) {
                Map config = AlibabaCloudRum.getNetworkTraceConfig();
                result.success(config);
                return;
            } else if ("triggerCrash".equals(call.method)) {
                String test = null;
                test.length();
            } else if ("triggerCrash2".equals(call.method)) {
                new Thread(() -> {
                    String test1 = null;
                    test1.length();
                }).start();
            } else if ("getDeviceId".equals(call.method)) {
                String deviceId = AlibabaCloudRum.getDeviceId();
                result.success(deviceId);
                return;
            }
            result.success("success");
        } catch (Throwable e) {
            e.printStackTrace();
        }
    }
}
