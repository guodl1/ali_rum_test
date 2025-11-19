# 1.0.5
* added null checks in http response handling

# 1.0.4
# 1.0.4-beta.1
* removed v1 embedding support
* upgrade Android sdk to 1.0.9
* upgrade iOS sdk to 1.0.9

# 1.0.3
# 1.0.3-beta.1
* correct setCustomLog parameter order
* upgrade iOS sdk to 1.0.8
* upgrade Android sdk to 1.0.7
  
# 1.0.2
# 1.0.2-beta.1
* upgrade iOS sdk to 1.0.6
* upgrade Android sdk to 1.0.5

# 1.0.1
* upgrade iOS sdk to 1.0.5
* upgrade Android sdk to 1.0.4

# 1.0.1-beta.1
* downgrade Android compileSdk sdk 30

## 1.0.0
## 1.0.0-beta.1
* added support rum sdk 1.x

## 0.2.7-beta.1
### Enhancement
* upgrade Android sdk to 0.3.13
* upgrade iOS sdk to 0.3.7

### build
* upgrade Android compileSdkVersion to 35

## 0.2.6
### Enhancement
* Add returned bool value for error callback
* Add setDumpError for enable/disable dump flutter error to console
* Add addUserExtraInfo, setExtraInfo, addExtraInfo for custom settings

## 0.2.5
## 0.2.5-beta.2
### Enhancement
* Add getDeviceId method

## 0.2.5-beta.1
### Fixes
* Fix `Namespace not specified. Specify a namespace in the module's build file` when AGP version is 8.x

## 0.2.4
### Enhancement
* Init HttpOverrides.global before runApp called.

## 0.2.3
### Enhancement
* Adding await while calling beforeRunApp, you can do something asynchronous in the beforeRunApp block

## 0.2.2
### Fixes
* Fix onRUMErrorCallback may not called under some scenarios

## 0.2.1
### Features
* Add beforeRunApp callback for starting sdk

### Fixes
* Trace config not update on iOS platform
* Crashed while sending event or log data

## 0.2.0
* Add sampling rate configuration for sw8 & otel
* Add user custom exception & events

## 0.1.0
* Refine version & README

## 0.1.0-dev.3
* Refine README

## 0.1.0-dev.2
* Refine README
* Refine setUserXXX api

## 0.1.0-dev.1

* The AlibabaCloudRUM Flutter plugin working with SDK for Android and iOS, assists in measuring the performance of the Flutter application.
