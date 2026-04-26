import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../bloc/printer_bloc.dart';
import '../bloc/printer_event.dart';
import '../bloc/printer_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<PrinterBloc>().add(InitPrinterEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Section
            Container(
              width: double.infinity,
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: BlocBuilder<ShopBloc, ShopState>(
                builder: (context, state) {
                  String shopName = 'Elite Groceries';
                  String initials = 'EG';
                  if (state is ShopLoaded && state.shop.name.isNotEmpty) {
                    shopName = state.shop.name;
                    final parts = shopName.split(' ');
                    initials = parts
                        .take(2)
                        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
                        .join('');
                    if (initials.isEmpty) initials = 'S';
                  }

                  return Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.2),
                                blurRadius: 15,
                                spreadRadius: 5,
                              )
                            ]),
                        alignment: Alignment.center,
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1)),
                      ),
                      const SizedBox(height: 16),
                      Text(shopName.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Management Section
            _buildSectionHeader('Management'),
            _buildListGroup(
              children: [
                _buildListItem(
                  icon: Icons.qr_code_scanner,
                  title: 'Products',
                  subtitle: 'Manage stock and barcodes',
                  onTap: () => context.push('/products'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.receipt_long,
                  title: 'Print Z Report',
                  subtitle: 'Daily summary of sales',
                  onTap: () => context.push('/settings/z-report'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.storefront,
                  title: 'Shop Details',
                  subtitle: 'Edit business info & address',
                  onTap: () => context.push('/shop'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Printer Selection ──────────────────────────────────────────
            _buildSectionHeader('Hardware - Primary Printer'),
            BlocBuilder<PrinterBloc, PrinterState>(
              builder: (context, state) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Select which printer to use by default during checkout.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildPrimaryOption(
                            context,
                            'wifi',
                            'Wi-Fi / LAN',
                            Icons.wifi,
                            state.preferredType == 'wifi',
                          ),
                          const SizedBox(width: 8),
                          _buildPrimaryOption(
                            context,
                            'bluetooth',
                            'Bluetooth',
                            Icons.bluetooth,
                            state.preferredType == 'bluetooth',
                          ),
                          const SizedBox(width: 8),
                          _buildPrimaryOption(
                            context,
                            'none',
                            'Auto',
                            Icons.auto_awesome,
                            state.preferredType == 'none',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Wi-Fi Printer Section ──────────────────────────────────────
            _buildSectionHeader('Wi-Fi / LAN Configuration'),
            BlocConsumer<PrinterBloc, PrinterState>(
              listener: (context, state) {
                if (state.wifiStatus == PrinterStatus.error &&
                    state.wifiErrorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.wifiErrorMessage!),
                      backgroundColor: Colors.red));
                } else if (state.wifiStatus == PrinterStatus.connected &&
                    state.connectedIp != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Connected to Wi-Fi printer!'),
                      backgroundColor: Colors.green));
                }
              },
              builder: (context, state) {
                return _buildListGroup(
                  children: [
                    _buildListItem(
                      icon: Icons.print,
                      title: 'Print Device (Wi-Fi/LAN)',
                      subtitleWidget: Row(
                        children: [
                          Text(
                            state.connectedIp != null
                                ? 'IP: ${state.connectedIp}'
                                : 'No printer connected',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          if (state.connectedIp != null) ...[
                            const SizedBox(width: 8),
                            _buildBadge('CONNECTED', Colors.teal),
                          ]
                        ],
                      ),
                      trailingWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.wifiStatus == PrinterStatus.connecting)
                            const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                          else if (state.connectedIp != null)
                            IconButton(
                              icon: const Icon(Icons.link_off),
                              onPressed: () => context
                                  .read<PrinterBloc>()
                                  .add(DisconnectPrinterEvent()),
                              color: Colors.red,
                            ),
                          IconButton(
                            icon: const Icon(Icons.add_link),
                            onPressed: () => _showConnectIpDialog(context),
                            color: AppTheme.primaryColor,
                          ),
                          if (state.connectedIp != null)
                            IconButton(
                              icon: const Icon(Icons.print_outlined),
                              tooltip: 'Test Print (Wi-Fi)',
                              onPressed: () {
                                final shopState =
                                    context.read<ShopBloc>().state;
                                String shopName = 'Elite Groceries';
                                if (shopState is ShopLoaded) {
                                  shopName = shopState.shop.name;
                                }
                                context
                                    .read<PrinterBloc>()
                                    .add(TestPrintEvent(shopName));
                              },
                              color: Colors.grey[600],
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Text(
                "Tap + to configure your Thermal Printer via IP Address (e.g. 192.168.1.50). Both devices must be on the same Wi-Fi network.",
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[500]),
              ),
            ),

            const SizedBox(height: 24),

            // ── Bluetooth Printer Section ──────────────────────────────────
            _buildSectionHeader('Hardware - Printer (Bluetooth)'),
            BlocConsumer<PrinterBloc, PrinterState>(
              listenWhen: (prev, curr) =>
                  prev.btStatus != curr.btStatus ||
                  prev.connectedBtAddress != curr.connectedBtAddress,
              listener: (context, state) {
                if (state.btStatus == PrinterStatus.error &&
                    state.btErrorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.btErrorMessage!),
                      backgroundColor: Colors.red));
                } else if (state.btStatus == PrinterStatus.connected &&
                    state.connectedBtAddress != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Connected to Bluetooth printer!'),
                      backgroundColor: Colors.green));
                }
              },
              builder: (context, state) {
                return _buildListGroup(
                  children: [
                    // Status row
                    _buildListItem(
                      icon: Icons.bluetooth_connected,
                      title: 'Bluetooth Device',
                      subtitleWidget: Row(
                        children: [
                          Text(
                            state.connectedBtAddress != null
                                ? state.connectedBtName ??
                                    state.connectedBtAddress!
                                : 'No device connected',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                          if (state.connectedBtAddress != null) ...[
                            const SizedBox(width: 8),
                            _buildBadge('CONNECTED', Colors.blue),
                          ],
                          if (state.btStatus == PrinterStatus.scanning) ...[
                            const SizedBox(width: 8),
                            _buildBadge('SCANNING…', Colors.orange),
                          ],
                        ],
                      ),
                      trailingWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.btStatus == PrinterStatus.connecting ||
                              state.btStatus == PrinterStatus.scanning)
                            const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                          else ...[
                            // Scan / list paired devices
                            IconButton(
                              icon: const Icon(Icons.bluetooth_searching),
                              tooltip: 'Scan paired devices',
                              onPressed: () {
                                context
                                    .read<PrinterBloc>()
                                    .add(ScanBluetoothEvent());
                              },
                              color: AppTheme.primaryColor,
                            ),
                            if (state.connectedBtAddress != null) ...[
                              IconButton(
                                icon: const Icon(Icons.link_off),
                                tooltip: 'Disconnect Bluetooth',
                                onPressed: () => context
                                    .read<PrinterBloc>()
                                    .add(DisconnectBluetoothEvent()),
                                color: Colors.red,
                              ),
                              IconButton(
                                icon: const Icon(Icons.print_outlined),
                                tooltip: 'Test Print (Bluetooth)',
                                onPressed: () {
                                  final shopState =
                                      context.read<ShopBloc>().state;
                                  String shopName = 'Elite Groceries';
                                  if (shopState is ShopLoaded) {
                                    shopName = shopState.shop.name;
                                  }
                                  context.read<PrinterBloc>().add(
                                      TestPrintBluetoothEvent(shopName));
                                },
                                color: Colors.grey[600],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    // Device list (shown after scan)
                    if (state.availableBtDevices.isNotEmpty) ...[
                      _buildDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Paired devices',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.5)),
                        ),
                      ),
                      ...state.availableBtDevices
                          .map((device) => _buildBluetoothDeviceTile(
                              context, device, state)),
                    ],
                  ],
                );
              },
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Text(
                "Tap the Bluetooth scan icon to list paired devices. Make sure your printer is paired in Android Settings and turned on before scanning.",
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[500]),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildBluetoothDeviceTile(
      BuildContext context, BluetoothDevice device, PrinterState state) {
    final isConnected = state.connectedBtAddress == device.address;
    return InkWell(
      onTap: () {
        if (!isConnected) {
          context
              .read<PrinterBloc>()
              .add(ConnectBluetoothEvent(device));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.bluetooth,
                size: 20,
                color: isConnected
                    ? Colors.blue
                    : Colors.grey[400]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name ?? 'Unknown Device',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isConnected
                            ? FontWeight.bold
                            : FontWeight.normal),
                  ),
                  Text(device.address,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            if (isConnected)
              _buildBadge('CONNECTED', Colors.blue)
            else
              Text('Tap to connect',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color[200]!),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color[700]),
      ),
    );
  }

  void _showConnectIpDialog(BuildContext context) {
    final TextEditingController ipController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Connect Wi-Fi Printer'),
          content: TextField(
            controller: ipController,
            decoration: const InputDecoration(
              hintText: 'e.g. 192.168.1.100',
              labelText: 'Printer IP Address',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor),
              onPressed: () {
                final ip = ipController.text.trim();
                if (ip.isNotEmpty) {
                  context.read<PrinterBloc>().add(
                      ConnectPrinterEvent(ip: ip, name: 'Network Printer'));
                  Navigator.pop(context);
                }
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildListGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey[50], indent: 64);
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    Widget? trailingWidget,
    IconData? trailingIcon = Icons.chevron_right,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ],
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 4),
                    subtitleWidget,
                  ]
                ],
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (trailingIcon != null)
              Icon(trailingIcon, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryOption(BuildContext context, String type, String label,
      IconData icon, bool isSelected) {
    return Expanded(
      child: InkWell(
        onTap: () =>
            context.read<PrinterBloc>().add(SetPreferredPrinterEvent(type)),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[400]),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
