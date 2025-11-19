package com.example.tingyue

import io.flutter.app.FlutterApplication
import com.alibabacloud.rum.AlibabaCloudRum

class MyApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        
        // 初始化 Alibaba Cloud RUM SDK
        AlibabaCloudRum.withAppID("i920cij824@01c56cb410340fa") // AppID 在创建 RUM 应用时获取
            .withConfigAddress("https://i920cij824-default-cn.rum.aliyuncs.com") // ConfigAddress 在创建 RUM 应用时获取
            .start(applicationContext)
    }
}
