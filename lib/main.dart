import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

void main() {
  runApp(const PWMControllerApp());
}

class PWMControllerApp extends StatelessWidget {
  const PWMControllerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PWM Controller',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const PWMControllerHome(),
    );
  }
}

class PWMControllerHome extends StatefulWidget {
  const PWMControllerHome({Key? key}) : super(key: key);

  @override
  State<PWMControllerHome> createState() => _PWMControllerHomeState();
}

class _PWMControllerHomeState extends State<PWMControllerHome> {
  // BLE Variables
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeCharacteristic;
  bool isScanning = false;
  bool isConnected = false;
  List<ScanResult> scanResults = [];

  // PWM Settings
  double frequency = 10.0; // Slider value (1-200, represents x100 Hz)
  double dutyCycle = 50.0; // Slider value (0-100%)

  // TODO: Replace these with your actual UUIDs from STM32
  // You can find these in your STM32 BLE service configuration
  final String serviceUUID = "0000fe40-cc7a-482a-984a-7f2ed5b3e58f"; // P2P Service UUID
  final String characteristicUUID = "0000fe41-8e22-4541-9d4c-21edae82ed19"; // LED Characteristic UUID

  @override
  void initState() {
    super.initState();
    // Check if Bluetooth is available
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        // Bluetooth is ready
      }
    });
  }

  // Start scanning for BLE devices
  void startScan() async {
    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    // Start scanning for 4 seconds
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      // Filter results to only show devices containing "P2P" in the name
      // OR devices with your specific service UUID
      List<ScanResult> filteredResults = results.where((result) {
        String deviceName = result.device.name.toLowerCase();
        // Show devices with "p2p" in name OR your service UUID
        bool hasP2PName = deviceName.contains('p2p');
        bool hasServiceUUID = result.advertisementData.serviceUuids
            .any((uuid) => uuid.toString().toLowerCase().contains('fe40'));
        return hasP2PName || hasServiceUUID || deviceName.contains('stm32');
      }).toList();
      
      setState(() {
        scanResults = filteredResults;
      });
    });

    // Stop scanning after timeout
    await Future.delayed(const Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
    });
    
    // Auto-connect if only one device found
    if (scanResults.length == 1) {
      showSnackBar("Found ${scanResults[0].device.name}, connecting...");
      connectToDevice(scanResults[0].device);
    }
  }

  // Connect to a device
  void connectToDevice(BluetoothDevice device) async {
    try {
      // Connect to device
      await device.connect();
      setState(() {
        connectedDevice = device;
        isConnected = true;
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find the write characteristic
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == characteristicUUID.toLowerCase()) {
              setState(() {
                writeCharacteristic = characteristic;
              });
              print("Found write characteristic!");
              break;
            }
          }
        }
      }

      if (writeCharacteristic == null) {
        print("Warning: Could not find write characteristic");
        showSnackBar("Connected, but could not find write characteristic");
      } else {
        showSnackBar("Connected to ${device.name}");
      }
    } catch (e) {
      print("Error connecting: $e");
      showSnackBar("Connection failed: $e");
    }
  }

  // Disconnect from device
  void disconnectDevice() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      setState(() {
        connectedDevice = null;
        writeCharacteristic = null;
        isConnected = false;
      });
      showSnackBar("Disconnected");
    }
  }

  // Send PWM frequency command (0xF0 + value)
  void sendFrequency(int value) async {
    if (writeCharacteristic == null) {
      showSnackBar("Not connected!");
      return;
    }

    try {
      // Send command: 0xF0 followed by frequency value
      List<int> command = [0xF0, value];
      await writeCharacteristic!.write(command, withoutResponse: true);
      print("Sent frequency: 0xF0 0x${value.toRadixString(16)}");
    } catch (e) {
      print("Error sending frequency: $e");
      showSnackBar("Error sending data");
    }
  }

  // Send PWM duty cycle command (0xF1 + value)
  void sendDutyCycle(int value) async {
    if (writeCharacteristic == null) {
      showSnackBar("Not connected!");
      return;
    }

    try {
      // Send command: 0xF1 followed by duty cycle value
      List<int> command = [0xF1, value];
      await writeCharacteristic!.write(command, withoutResponse: true);
      print("Sent duty cycle: 0xF1 0x${value.toRadixString(16)}");
    } catch (e) {
      print("Error sending duty cycle: $e");
      showSnackBar("Error sending data");
    }
  }

  // Show snackbar message
  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PWM Controller'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      size: 48,
                      color: isConnected ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isConnected
                          ? 'Connected to ${connectedDevice?.name ?? "Device"}'
                          : 'Not Connected',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (!isConnected)
                      ElevatedButton.icon(
                        onPressed: isScanning ? null : startScan,
                        icon: Icon(isScanning ? Icons.hourglass_empty : Icons.search),
                        label: Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: disconnectDevice,
                        icon: const Icon(Icons.bluetooth_disabled),
                        label: const Text('Disconnect'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Device List (when scanning)
            if (isScanning || scanResults.isNotEmpty)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Devices',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ...scanResults.map((result) {
                        return ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(result.device.name.isEmpty
                              ? 'Unknown Device'
                              : result.device.name),
                          subtitle: Text(result.device.id.toString()),
                          trailing: Text('${result.rssi} dBm'),
                          onTap: () => connectToDevice(result.device),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Frequency Control
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '⚡ Frequency',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${(frequency * 100).toInt()} Hz',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Slider(
                      value: frequency,
                      min: 1,
                      max: 200,
                      divisions: 199,
                      label: '${(frequency * 100).toInt()} Hz',
                      onChanged: isConnected
                          ? (value) {
                              setState(() {
                                frequency = value;
                              });
                            }
                          : null,
                      onChangeEnd: (value) {
                        sendFrequency(value.toInt());
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('100 Hz', style: TextStyle(fontSize: 12)),
                        Text('20 kHz', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _presetButton('1 kHz', 10, isFrequency: true),
                        _presetButton('5 kHz', 50, isFrequency: true),
                        _presetButton('10 kHz', 100, isFrequency: true),
                        _presetButton('20 kHz', 200, isFrequency: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Duty Cycle Control
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📊 Duty Cycle',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${dutyCycle.toInt()}%',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Slider(
                      value: dutyCycle,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: '${dutyCycle.toInt()}%',
                      onChanged: isConnected
                          ? (value) {
                              setState(() {
                                dutyCycle = value;
                              });
                            }
                          : null,
                      onChangeEnd: (value) {
                        sendDutyCycle(value.toInt());
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('0%', style: TextStyle(fontSize: 12)),
                        Text('100%', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _presetButton('25%', 25, isFrequency: false),
                        _presetButton('50%', 50, isFrequency: false),
                        _presetButton('75%', 75, isFrequency: false),
                        _presetButton('100%', 100, isFrequency: false),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for preset buttons
  Widget _presetButton(String label, double value, {required bool isFrequency}) {
    return ElevatedButton(
      onPressed: isConnected
          ? () {
              setState(() {
                if (isFrequency) {
                  frequency = value;
                  sendFrequency(value.toInt());
                } else {
                  dutyCycle = value;
                  sendDutyCycle(value.toInt());
                }
              });
            }
          : null,
      child: Text(label),
    );
  }

  @override
  void dispose() {
    disconnectDevice();
    super.dispose();
  }
}