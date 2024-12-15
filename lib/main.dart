import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(BluetoothHeartRateApp());

class BluetoothHeartRateApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HeartRateMonitor(),
    );
  }
}

class HeartRateMonitor extends StatefulWidget {
  @override
  _HeartRateMonitorState createState() => _HeartRateMonitorState();
}

class _HeartRateMonitorState extends State<HeartRateMonitor> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  late DiscoveredDevice _selectedDevice;
  late Stream<ConnectionStateUpdate> _connectionStream;

  final List<DiscoveredDevice> _devices = [];
  String _status = "Searching for devices...";
  int? _heartRate;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      _ble.scanForDevices(withServices: []).listen((device) {
        if (!_devices.any((d) => d.id == device.id)) {
          setState(() {
            _devices.add(device);
          });
        }
      }, onError: (error) {
        setState(() {
          _status = "Error: $error";
        });
      });
    } else {
      setState(() {
        _status = "Location permission denied. Cannot scan for devices.";
      });
    }
  }

  void _connectToDevice(DiscoveredDevice device) {
    setState(() {
      _status = "Connecting to ${device.name}...";
    });

    _connectionStream = _ble.connectToDevice(id: device.id);
    _connectionStream.listen((connectionState) {
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        setState(() {
          _status = "Connected to ${device.name}";
          _selectedDevice = device;
        });
        _subscribeToHeartRate(device);
      } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
        setState(() {
          _status = "Disconnected from ${device.name}";
        });
      }
    }, onError: (error) {
      setState(() {
        _status = "Connection error: $error";
      });
    });
  }

  void _subscribeToHeartRate(DiscoveredDevice device) {

    Uuid heartRateService = Uuid.parse("0000180d-0000-1000-8000-00805f9b34fb");
    Uuid heartRateCharacteristic = Uuid.parse("00002a37-0000-1000-8000-00805f9b34fb");

    _ble.subscribeToCharacteristic(
      QualifiedCharacteristic(
        serviceId: heartRateService,
        characteristicId: heartRateCharacteristic,
        deviceId: device.id,
      ),
    ).listen((data) {
      // Decode heart rate value (first byte of data)
      setState(() {
        _heartRate = data[1];
      });
    }, onError: (error) {
      setState(() {
        _status = "Error receiving heart rate: $error";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Heart Rate Monitor")),
      body: Column(
        children: [
          Text(_status),
          if (_heartRate != null) Text("Heart Rate: $_heartRate bpm"),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  title: Text(device.name.isEmpty ? "Unknown Device" : device.name),
                  subtitle: Text(device.id),
                  onTap: () => _connectToDevice(device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
