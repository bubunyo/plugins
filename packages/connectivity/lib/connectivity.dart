// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Connection Status Check Result
///
/// WiFi: Device connected via Wi-Fi
/// Mobile: Device connected to cellular network
/// None: Device not connected to any network
enum ConnectionType { wifi, mobile, none }
enum ConnectionSubtype { EDGE, HSDPA, LTE, none, unknown }

class ConnectivityResult {
  ConnectivityResult(this.type, this.subtype);

  final ConnectionType type;
  final ConnectionSubtype subtype;

  static const ConnectionType wifi = ConnectionType.wifi;
  static const ConnectionType mobile = ConnectionType.mobile;
  static const ConnectionType none = ConnectionType.none;

  @override
  bool operator ==(Object object) {
    if (!(object is ConnectionType)) return false;
    return type == object;
  }

  @override
  int get hashCode => type.hashCode;
}

class Connectivity {
  /// Constructs a singleton instance of [Connectivity].
  ///
  /// [Connectivity] is designed to work as a singleton.
  // When a second instance is created, the first instance will not be able to listen to the
  // EventChannel because it is overridden. Forcing the class to be a singleton class can prevent
  // misusage of creating a second instance from a programmer.
  factory Connectivity() {
    if (_singleton == null) {
      _singleton = Connectivity._();
    }
    return _singleton;
  }

  Connectivity._();

  static Connectivity _singleton;

  Stream<ConnectivityResult> _onConnectivityChanged;

  @visibleForTesting
  static const MethodChannel methodChannel = MethodChannel(
    'plugins.flutter.io/connectivity',
  );

  @visibleForTesting
  static const EventChannel eventChannel = EventChannel(
    'plugins.flutter.io/connectivity_status',
  );

  /// Fires whenever the connectivity state changes.
  Stream<ConnectivityResult> get onConnectivityChanged {
    if (_onConnectivityChanged == null) {
      _onConnectivityChanged = eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => _parseConnectivityResult(event));
    }
    return _onConnectivityChanged;
  }

  /// Checks the connection status of the device.
  ///
  /// Do not use the result of this function to decide whether you can reliably
  /// make a network request. It only gives you the radio status.
  ///
  /// Instead listen for connectivity changes via [onConnectivityChanged] stream.
  Future<ConnectivityResult> checkConnectivity(
      {bool checkSubtype = false}) async {
    final String result = await methodChannel.invokeMethod<String>('check');
    return _parseConnectivityResult(result);
  }

  /// Checks the network mobile connection subtype of the device.
  /// Return EDGE for 2G, HSDPA for 3G and LTE for 4G depending on the connection of the mobile connection
  /// if it is connected.
  ///
  /// Return none if there is no connections
  ///
  /// Return unknown if it is connected but there is not connection subtype info. eg. Wifi
  Future<ConnectionSubtype> getNetworkSubtype() async {
    final String result = await methodChannel.invokeMethod<String>('subtype');
    return _parseConnectionSubtype(result);
  }

  /// Obtains the wifi name (SSID) of the connected network
  ///
  /// Please note that it DOESN'T WORK on emulators (returns null).
  ///
  /// From android 8.0 onwards the GPS must be ON (high accuracy)
  /// in order to be able to obtain the SSID.
  Future<String> getWifiName() async {
    String wifiName = await methodChannel.invokeMethod<String>('wifiName');
    // as Android might return <unknown ssid>, uniforming result
    // our iOS implementation will return null
    if (wifiName == '<unknown ssid>') wifiName = null;
    return wifiName;
  }

  /// Obtains the wifi BSSID of the connected network.
  ///
  /// Please note that it DOESN'T WORK on emulators (returns null).
  ///
  /// From Android 8.0 onwards the GPS must be ON (high accuracy)
  /// in order to be able to obtain the BSSID.
  Future<String> getWifiBSSID() async {
    return await methodChannel.invokeMethod<String>('wifiBSSID');
  }

  /// Obtains the IP address of the connected wifi network
  Future<String> getWifiIP() async {
    return await methodChannel.invokeMethod<String>('wifiIPAddress');
  }
}

ConnectionSubtype _parseConnectionSubtype(String state) {
  switch (state) {
    case '2G':
      return ConnectionSubtype.EDGE;
    case '3G':
      return ConnectionSubtype.HSDPA;
    case '4G':
      return ConnectionSubtype.LTE;
    case 'unknown':
      return ConnectionSubtype.unknown;
    case 'none':
    default:
      return ConnectionSubtype.none;
  }
}

ConnectivityResult _parseConnectivityResult(String state) {
  ConnectionType type = ConnectionType.none;
  ConnectionSubtype subType = ConnectionSubtype.unknown;

  final List<String> split = state.split(",");

  switch (split[0]) {
    case 'wifi':
      type = ConnectionType.wifi;
      break;
    case 'mobile':
      type = ConnectionType.mobile;
      break;
    case 'none':
    default:
      type = ConnectionType.none;
  }
  subType = _parseConnectionSubtype(split[1]);
  return ConnectivityResult(type, subType);
}
