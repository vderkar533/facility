import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const FacilityServiceApp());
}

class FacilityServiceApp extends StatelessWidget {
  const FacilityServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const red = AppPalette.primaryRed;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'INTEGRATED SERVICE MANAGEMENT',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppPalette.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: red,
          brightness: Brightness.light,
          primary: red,
          secondary: AppPalette.ink,
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
              fontSize: 30, fontWeight: FontWeight.w800, color: AppPalette.ink),
          titleLarge: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, color: AppPalette.ink),
          titleMedium: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppPalette.ink),
          bodyLarge: TextStyle(fontSize: 16, color: AppPalette.ink),
          bodyMedium: TextStyle(fontSize: 14, color: AppPalette.muted),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppPalette.ink,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, color: AppPalette.ink),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppPalette.soft,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          labelStyle: const TextStyle(color: AppPalette.muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppPalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: red, width: 1.6),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: AppPalette.border),
          ),
        ),
        dividerTheme:
            const DividerThemeData(color: AppPalette.border, thickness: 1),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppPalette.redTint,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: AppPalette.ink,
            ),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class AppPalette {
  static const primaryRed = Color(0xFFC62828);
  static const deepRed = Color(0xFF8E1111);
  static const redTint = Color(0xFFFBE3E3);
  static const canvas = Color(0xFFF7F4F2);
  static const soft = Color(0xFFFDFBFA);
  static const border = Color(0xFFE7DFDC);
  static const ink = Color(0xFF171717);
  static const muted = Color(0xFF68615D);
  static const plantAccent = Color(0xFFB8C0C8);
  static const plantAccentStrong = Color(0xFF6E7781);
  static const plantAccentTint = Color(0xFFF0F3F5);
  static const guesthouseAccent = Color(0xFFD2AF8C);
  static const guesthouseAccentStrong = Color(0xFF8C6545);
  static const guesthouseAccentTint = Color(0xFFFBF1E7);
  static const colonyAccent = Color(0xFFA8D8AE);
  static const colonyAccentStrong = Color(0xFF4F8A5B);
  static const colonyAccentTint = Color(0xFFEDF8EF);
}

Color siteAccentColor(String siteArea) {
  switch (siteArea.trim().toLowerCase()) {
    case 'plant':
      return AppPalette.plantAccent;
    case 'guesthouse':
      return AppPalette.guesthouseAccent;
    case 'colony':
      return AppPalette.colonyAccent;
    case 'hostel':
      return AppPalette.primaryRed;
    default:
      return AppPalette.primaryRed;
  }
}

Color siteAccentStrongColor(String siteArea) {
  switch (siteArea.trim().toLowerCase()) {
    case 'plant':
      return AppPalette.plantAccentStrong;
    case 'guesthouse':
      return AppPalette.guesthouseAccentStrong;
    case 'colony':
      return AppPalette.colonyAccentStrong;
    case 'hostel':
      return AppPalette.primaryRed;
    default:
      return AppPalette.primaryRed;
  }
}

Color siteAccentTint(String siteArea) {
  switch (siteArea.trim().toLowerCase()) {
    case 'plant':
      return AppPalette.plantAccentTint;
    case 'guesthouse':
      return AppPalette.guesthouseAccentTint;
    case 'colony':
      return AppPalette.colonyAccentTint;
    case 'hostel':
      return AppPalette.redTint;
    default:
      return AppPalette.redTint;
  }
}

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5003/api',
  );
  static const externalAuthUrl = String.fromEnvironment(
    'EXTERNAL_AUTH_URL',
    defaultValue: 'http://45.114.143.183:83/api/auth/login',
  );
}

class AuthSession {
  static String? sessionId;
  static String? refreshToken;

  static void updateFromLogin(Map<String, dynamic> data) {
    sessionId = data['sessionId'] as String?;
    refreshToken = data['refreshToken'] as String?;
  }

  static void clear() {
    sessionId = null;
    refreshToken = null;
  }
}

class ApiService {
  Future<AppUser> login(String email, String password, String role) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'role': role}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? data['message'] ?? 'Login failed');
    }
    AuthSession.updateFromLogin(data);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final sessionId = AuthSession.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      AuthSession.clear();
      return;
    }

    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sessionId': sessionId}),
      );
    } finally {
      AuthSession.clear();
    }
  }

  Future<Map<String, dynamic>> catalog() async {
    final response =
        await http.get(Uri.parse('${ApiConfig.baseUrl}/catalog/options'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<TicketItem>> tickets(
      {required int userId, required String role, String? siteArea}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/tickets').replace(
      queryParameters: {
        'userId': '$userId',
        'role': role,
        if (siteArea != null && siteArea.isNotEmpty) 'siteArea': siteArea,
      },
    );
    final response = await http.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list =
        (data['tickets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list.map(TicketItem.fromJson).toList();
  }

  Future<TicketItem> createTicket(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tickets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to create ticket');
    }
    return TicketItem.fromJson(data['ticket'] as Map<String, dynamic>);
  }

  Future<TicketItem> updateStatus(int ticketId, String status,
      {String? adminRemark, int? adminUserId}) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/tickets/$ticketId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': status,
        'adminRemark': adminRemark,
        if (adminUserId != null) 'adminUserId': adminUserId,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to update ticket');
    }
    return TicketItem.fromJson(data['ticket'] as Map<String, dynamic>);
  }

  Future<List<AssigneePerson>> assignees({
    required String siteArea,
    required String serviceType,
    required String serviceName,
    required String locationName,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/assignees').replace(
      queryParameters: {
        'siteArea': siteArea,
        'serviceType': serviceType,
        'serviceName': serviceName,
        'locationName': locationName,
      },
    );
    final response = await http.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch assignees');
    }
    final list = (data['assignees'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return list.map(AssigneePerson.fromJson).toList();
  }

  Future<TicketItem> assignTicket({
    required int ticketId,
    required int personId,
    required int adminUserId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tickets/$ticketId/assign'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'personId': personId, 'adminUserId': adminUserId}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to assign ticket');
    }
    return TicketItem.fromJson(data['ticket'] as Map<String, dynamic>);
  }

  Future<TicketItem> reopenTicket({
    required int ticketId,
    required int userId,
    String? remark,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tickets/$ticketId/reopen'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'remark': remark}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to reopen ticket');
    }
    return TicketItem.fromJson(data['ticket'] as Map<String, dynamic>);
  }

  Future<TicketItem> requestServiceStatus({
    required int ticketId,
    required int servicePersonId,
    required String status,
    required String remark,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/tickets/$ticketId/service-status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'servicePersonId': servicePersonId,
        'status': status,
        'remark': remark,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to submit status update');
    }
    return TicketItem.fromJson(data['ticket'] as Map<String, dynamic>);
  }
}

class AppUser {
  const AppUser(
      {required this.id,
      required this.fullName,
      required this.email,
      required this.role});

  final int id;
  final String fullName;
  final String email;
  final String role;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }

  bool get isAdmin => ['admin_user', 'admin', 'super_admin'].contains(role);
  bool get isServicePerson => role == 'service_person';
  String get roleLabel {
    switch (role) {
      case 'admin_user':
        return 'Admin';
      case 'service_person':
        return 'Service Person';
      default:
        return 'User';
    }
  }
}

class TicketItem {
  const TicketItem({
    required this.id,
    required this.ticketNumber,
    required this.siteArea,
    required this.serviceType,
    required this.serviceName,
    required this.locationName,
    required this.remarks,
    required this.status,
    required this.adminRemark,
    required this.pendingServiceStatus,
    required this.pendingServiceRemark,
    required this.pendingServiceUpdatedAt,
    required this.assignedPerson,
    required this.reopenCount,
    required this.escalationLevel,
    required this.requestedBy,
    required this.requestedByEmail,
    required this.siteColor,
    required this.updatedAt,
  });

  final int id;
  final String ticketNumber;
  final String siteArea;
  final String serviceType;
  final String serviceName;
  final String locationName;
  final String remarks;
  final String status;
  final String adminRemark;
  final String pendingServiceStatus;
  final String pendingServiceRemark;
  final DateTime? pendingServiceUpdatedAt;
  final AssignedPerson? assignedPerson;
  final int reopenCount;
  final int escalationLevel;
  final String requestedBy;
  final String requestedByEmail;
  final String siteColor;
  final DateTime updatedAt;

  factory TicketItem.fromJson(Map<String, dynamic> json) {
    return TicketItem(
      id: json['id'] as int,
      ticketNumber: json['ticketNumber'] as String? ?? '',
      siteArea: json['siteArea'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      status: json['status'] as String? ?? '',
      adminRemark: json['adminRemark'] as String? ?? '',
      pendingServiceStatus: json['pendingServiceStatus'] as String? ?? '',
      pendingServiceRemark: json['pendingServiceRemark'] as String? ?? '',
      pendingServiceUpdatedAt: json['pendingServiceUpdatedAt'] == null
          ? null
          : DateTime.parse(json['pendingServiceUpdatedAt'] as String),
      assignedPerson: (json['assignedPerson'] as Map<String, dynamic>?)
          ?.let(AssignedPerson.fromJson),
      reopenCount: (json['reopenCount'] as num?)?.toInt() ?? 0,
      escalationLevel: (json['escalationLevel'] as num?)?.toInt() ?? 0,
      requestedBy: json['requestedBy'] as String? ?? '',
      requestedByEmail: json['requestedByEmail'] as String? ?? '',
      siteColor: json['siteColor'] as String? ?? '#c62828',
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

extension _JsonLet<T> on T {
  R let<R>(R Function(T it) op) => op(this);
}

class AssignedPerson {
  const AssignedPerson(
      {required this.id, required this.fullName, required this.email});

  final int id;
  final String fullName;
  final String email;

  factory AssignedPerson.fromJson(Map<String, dynamic> json) {
    return AssignedPerson(
      id: json['id'] as int,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class AssigneePerson {
  const AssigneePerson(
      {required this.id, required this.fullName, required this.email});

  final int id;
  final String fullName;
  final String email;

  factory AssigneePerson.fromJson(Map<String, dynamic> json) {
    return AssigneePerson(
      id: json['id'] as int,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

void showAppToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFF4A1212) : AppPalette.ink,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

class SectionBanner extends StatelessWidget {
  const SectionBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF171717), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1FC62828),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFF4DCDC),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class AppWebViewScreen extends StatefulWidget {
  const AppWebViewScreen({
    super.key,
    required this.title,
    required this.initialUrl,
  });

  final String title;
  final String initialUrl;

  @override
  State<AppWebViewScreen> createState() => _AppWebViewScreenState();
}

class _AppWebViewScreenState extends State<AppWebViewScreen> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const LinearProgressIndicator(
              color: AppPalette.primaryRed,
              minHeight: 3,
            ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginRoleOption {
  const _LoginRoleOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  static const _roleOptions = [
    _LoginRoleOption(
      value: 'normal_user',
      label: 'User',
      icon: Icons.person_outline,
    ),
    _LoginRoleOption(
      value: 'admin_user',
      label: 'Admin',
      icon: Icons.admin_panel_settings_outlined,
    ),
    _LoginRoleOption(
      value: 'service_person',
      label: 'Service',
      icon: Icons.engineering_outlined,
    ),
  ];
  String _loginRole = 'normal_user';
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await _api.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _loginRole,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => user.isAdmin
              ? AdminDashboard(user: user)
              : user.isServicePerson
                  ? ServiceDashboard(user: user)
                  : UserDashboard(user: user),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSignupInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 5,
              decoration: BoxDecoration(
                color: AppPalette.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Signup Access',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Accounts are currently created by the admin team. Admin, user, and service-person credentials can all sign in from this screen.',
              style: TextStyle(color: AppPalette.muted, height: 1.5),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAuthWebView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AppWebViewScreen(
          title: 'Employee Auth',
          initialUrl: ApiConfig.externalAuthUrl,
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: [
          for (final option in _roleOptions)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _loading
                      ? null
                      : () => setState(() => _loginRole = option.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 68,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: _loginRole == option.value
                          ? AppPalette.primaryRed
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _loginRole == option.value
                          ? const [
                              BoxShadow(
                                color: Color(0x24C62828),
                                blurRadius: 14,
                                offset: Offset(0, 7),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option.icon,
                          size: 20,
                          color: _loginRole == option.value
                              ? Colors.white
                              : AppPalette.muted,
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            option.label,
                            maxLines: 1,
                            style: TextStyle(
                              color: _loginRole == option.value
                                  ? Colors.white
                                  : AppPalette.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050505), Color(0xFF181010), Color(0xFF8E1111)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1AC62828),
                ),
              ),
            ),
            Positioned(
              left: -80,
              bottom: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x11000000),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 470),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.93),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 46,
                            offset: Offset(0, 24),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(22, 34, 22, 26),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF111111),
                                      Color(0xFF8E1111),
                                      Color(0xFFC62828)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 122,
                                      child: SvgPicture.asset(
                                        'assets/lloyds-metals-logo.svg',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const Text(
                                      'MY VOICE',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 31,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.8,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'User, admin, and service-person access in one place.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFFF4DCDC),
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 24, 24, 26),
                                child: Column(
                                  children: [
                                    _buildRoleSelector(),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Username',
                                        hintText: 'Enter registered email',
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                              ? 'Enter username'
                                              : null,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                              ? 'Enter password'
                                              : null,
                                    ),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _loading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppPalette.primaryRed,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 18),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                        ),
                                        child: _loading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Login',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: _showSignupInfo,
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: AppPalette.ink),
                                          foregroundColor: AppPalette.ink,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 18),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                        ),
                                        child: const Text(
                                          'Signup',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed:
                                          _loading ? null : _openAuthWebView,
                                      icon: const Icon(Icons.open_in_browser),
                                      label: const Text(
                                          'Open employee auth in app'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final _api = ApiService();
  Map<String, dynamic> _catalog = const {};
  List<TicketItem> _tickets = [];
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = await _api.catalog();
    final tickets =
        await _api.tickets(userId: widget.user.id, role: widget.user.role);
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _tickets = tickets;
      _loading = false;
    });
  }

  Future<void> _refreshTickets() async {
    final tickets =
        await _api.tickets(userId: widget.user.id, role: widget.user.role);
    if (!mounted) return;
    setState(() => _tickets = tickets);
  }

  Future<void> _reopenTicket(TicketItem ticket) async {
    if (ticket.reopenCount >= 3) {
      showAppToast(context, 'Maximum escalation level reached (3).',
          error: true);
      return;
    }

    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var remarkDraft = '';
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Reopen Ticket'),
            content: TextField(
              minLines: 3,
              maxLines: 4,
              onChanged: (value) {
                setDialogState(() {
                  remarkDraft = value.trim();
                });
              },
              decoration: const InputDecoration(
                labelText: 'Remark (required)',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: remarkDraft.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, remarkDraft),
                child: const Text('Reopen'),
              ),
            ],
          ),
        );
      },
    );
    if (remark == null) return;

    try {
      await _api.reopenTicket(
        ticketId: ticket.id,
        userId: widget.user.id,
        remark: remark,
      );
      if (!mounted) return;
      await _refreshTickets();
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<void> _openCreateTicket([String? initialSite]) async {
    if (_catalog.isEmpty) return;
    final created = await Navigator.of(context).push<TicketItem>(
      MaterialPageRoute(
        builder: (_) => CreateTicketScreen(
          user: widget.user,
          catalog: _catalog,
          initialSite: initialSite,
        ),
      ),
    );
    if (created != null) {
      await _refreshTickets();
      if (mounted) setState(() => _tab = 1);
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      UserHome(user: widget.user, onCreate: _openCreateTicket),
      TicketHistory(
          tickets: _tickets,
          loading: _loading,
          onRefresh: _refreshTickets,
          showRequestedBy: false,
          onReopen: _reopenTicket),
      UserProfile(user: widget.user, onLogout: _logout),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('User Dashboard')),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.confirmation_num_outlined), label: 'Tickets'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class UserHome extends StatelessWidget {
  const UserHome({super.key, required this.user, required this.onCreate});

  final AppUser user;
  final Future<void> Function(String site) onCreate;

  @override
  Widget build(BuildContext context) {
    const sites = ['Plant', 'Guesthouse', 'Colony', 'Hostel'];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionBanner(
          title: 'Welcome,\n${user.fullName}',
          subtitle:
              'Choose Plant, Guesthouse, Colony, or Hostel and raise a neatly tracked service request.',
          trailing: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoPill(label: '4 Areas'),
              SizedBox(height: 10),
              InfoPill(label: 'Tracked Tickets'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...sites.map((site) => Card(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: siteAccentColor(site).withValues(alpha: 0.55)),
                  gradient: LinearGradient(
                    colors: [siteAccentTint(site), Colors.white],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  leading: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: siteAccentColor(site),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: siteAccentStrongColor(site)
                              .withValues(alpha: 0.28)),
                    ),
                    child: Center(
                      child: Text(
                        site[0],
                        style: TextStyle(
                            color: siteAccentStrongColor(site),
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                    ),
                  ),
                  title: Text(site,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                        'Open services, locations, remarks, and ticket submission'),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded,
                      color: siteAccentStrongColor(site)),
                  onTap: () => onCreate(site),
                ),
              ),
            )),
      ],
    );
  }
}

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen(
      {super.key, required this.user, required this.catalog, this.initialSite});

  final AppUser user;
  final Map<String, dynamic> catalog;
  final String? initialSite;

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final _api = ApiService();
  bool _saving = false;
  String? site;
  String? serviceType;
  String? serviceName;
  String? location;

  List<String> get sites =>
      (widget.catalog['sites'] as List<dynamic>).cast<String>();
  Map<String, dynamic> get serviceCatalog =>
      widget.catalog['serviceCatalog'] as Map<String, dynamic>;
  Map<String, dynamic> get locationCatalog =>
      widget.catalog['locationCatalog'] as Map<String, dynamic>;

  List<String> get serviceTypes {
    if (site == null) return [];
    final types = (serviceCatalog[site] as Map<String, dynamic>)
        .keys
        .cast<String>()
        .toList();
    if (!types.contains('Others')) {
      types.add('Others');
    } else {
      // Keep "Others" at the bottom for better UX.
      types
        ..remove('Others')
        ..add('Others');
    }
    return types;
  }

  List<String> get serviceNames {
    if (site == null || serviceType == null) return [];
    return (serviceCatalog[site][serviceType] as List<dynamic>).cast<String>();
  }

  List<String> get locations {
    if (site == null) return [];
    return (locationCatalog[site] as List<dynamic>).cast<String>();
  }

  @override
  void initState() {
    super.initState();
    final initialSite = widget.initialSite;
    if (initialSite != null) {
      site = initialSite;
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final ticket = await _api.createTicket({
        'userId': widget.user.id,
        'siteArea': site,
        'serviceType': serviceType,
        'serviceName': serviceName,
        'locationName': location,
        'remarks': _remarksController.text.trim(),
      });
      if (!mounted) return;
      showAppToast(
          context, 'Ticket ${ticket.ticketNumber} created successfully.');
      Navigator.pop(context, ticket);
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockSite = widget.initialSite != null;
    final isServiceTypeOthers = serviceType == 'Others';
    final areaItems = lockSite && site != null ? [site!] : sites;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Ticket')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionBanner(
            title: 'Create Ticket',
            subtitle:
                'Choose the service area, service type, exact location, and remarks for a cleaner handoff to the team.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Register Service Request',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                        'Select site, service type, specific service, location, and optional remarks.',
                        style: TextStyle(color: AppPalette.muted)),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: site,
                      decoration: const InputDecoration(labelText: 'Area'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppPalette.ink,
                      ),
                      items: areaItems
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: lockSite
                          ? null
                          : (value) => setState(() {
                                site = value;
                                serviceType = null;
                                serviceName = null;
                                location = null;
                              }),
                      validator: (value) =>
                          value == null ? 'Select area' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: serviceType,
                      decoration:
                          const InputDecoration(labelText: 'Service Type'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppPalette.ink,
                      ),
                      items: serviceTypes
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() {
                        serviceType = value;
                        if (value == 'Others') {
                          serviceName = 'Others';
                        } else {
                          serviceName = null;
                        }
                      }),
                      validator: (value) =>
                          value == null ? 'Select service type' : null,
                    ),
                    const SizedBox(height: 16),
                    if (!isServiceTypeOthers) ...[
                      DropdownButtonFormField<String>(
                        initialValue: serviceName,
                        decoration: const InputDecoration(
                            labelText: 'Specific Service'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w400,
                          color: AppPalette.ink,
                        ),
                        items: serviceNames
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => serviceName = value),
                        validator: (value) =>
                            value == null ? 'Select specific service' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: location,
                      decoration: const InputDecoration(labelText: 'Location'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppPalette.ink,
                      ),
                      items: locations
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => location = value),
                      validator: (value) =>
                          value == null ? 'Select location' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarksController,
                      minLines: 4,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: serviceName == 'Others'
                            ? 'Remarks (required for Others)'
                            : 'Remarks',
                        hintText:
                            'Specify location, service, and other remarks.',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (serviceName == 'Others' &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please describe your requirement in remarks';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Ticket'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TicketHistory extends StatelessWidget {
  const TicketHistory(
      {super.key,
      required this.tickets,
      required this.loading,
      required this.onRefresh,
      required this.showRequestedBy,
      this.onReopen});

  final List<TicketItem> tickets;
  final bool loading;
  final Future<void> Function() onRefresh;
  final bool showRequestedBy;
  final Future<void> Function(TicketItem ticket)? onReopen;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionBanner(
            title: 'Ticket History',
            subtitle:
                'See previous registered tickets with live status updates and admin remarks.',
          ),
          const SizedBox(height: 16),
          if (tickets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text('No tickets found.',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ...tickets.map(
            (ticket) => TicketCard(
              ticket: ticket,
              showRequestedBy: showRequestedBy,
              collapsible: true,
              initiallyExpanded: false,
              onReopen: onReopen,
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceDashboard extends StatefulWidget {
  const ServiceDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<ServiceDashboard> createState() => _ServiceDashboardState();
}

class _ServiceDashboardState extends State<ServiceDashboard> {
  final _api = ApiService();
  List<TicketItem> _tickets = [];
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final tickets =
        await _api.tickets(userId: widget.user.id, role: widget.user.role);
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _loading = false;
    });
  }

  Future<void> _submitServiceUpdate(TicketItem ticket) async {
    final result = await showDialog<_ServiceStatusDraft>(
      context: context,
      builder: (dialogContext) => ServiceStatusDialog(
        initialStatus: ticket.pendingServiceStatus.isNotEmpty
            ? ticket.pendingServiceStatus
            : 'Resolved',
        initialRemark: ticket.pendingServiceRemark,
      ),
    );

    if (result == null) return;
    final remark = result.remark;
    if (remark.trim().isEmpty) {
      if (!mounted) return;
      showAppToast(context, 'Remark is required.', error: true);
      return;
    }

    try {
      await _api.requestServiceStatus(
        ticketId: ticket.id,
        servicePersonId: widget.user.id,
        status: result.status,
        remark: remark,
      );
      if (!mounted) return;
      await _loadTickets();
      if (!mounted) return;
      showAppToast(context, 'Update submitted for admin approval.');
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final openCount =
        _tickets.where((ticket) => ticket.status == 'Open').length;
    final escalatedCount = _tickets
        .where((ticket) => ticket.reopenCount > 0 || ticket.escalationLevel > 0)
        .length;

    final pages = [
      ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionBanner(
            title: 'Service Desk\n${widget.user.fullName}',
            subtitle:
                'View only the tickets assigned to you and send resolution updates to admin for approval.',
            trailing: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InfoPill(label: 'Assigned Only'),
                SizedBox(height: 10),
                InfoPill(label: 'Admin Approval'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Open Tickets',
                            style: TextStyle(color: AppPalette.muted)),
                        const SizedBox(height: 8),
                        Text('$openCount',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Escalations',
                            style: TextStyle(color: AppPalette.muted)),
                        const SizedBox(height: 8),
                        Text('$escalatedCount',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTickets,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SectionBanner(
                    title: 'Assigned Tickets',
                    subtitle:
                        'Submit Resolved or Not Resolved updates with remarks. Admin can approve or change the final status.',
                  ),
                  const SizedBox(height: 16),
                  if (_tickets.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Text(
                          'No tickets are assigned to you right now.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ..._tickets.map(
                    (ticket) => TicketCard(
                      ticket: ticket,
                      showRequestedBy: true,
                      collapsible: true,
                      initiallyExpanded: false,
                      footer: ['Open', 'Hold'].contains(ticket.status)
                          ? SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _submitServiceUpdate(ticket),
                                icon: const Icon(
                                    Icons.assignment_turned_in_outlined),
                                label: Text(
                                  ticket.pendingServiceStatus.isNotEmpty
                                      ? 'Update Request'
                                      : 'Submit Update',
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
      UserProfile(user: widget.user, onLogout: _logout),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Service Dashboard')),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_circle_outlined),
            label: 'Tickets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ServiceStatusDraft {
  const _ServiceStatusDraft({required this.status, required this.remark});

  final String status;
  final String remark;
}

class ServiceStatusDialog extends StatefulWidget {
  const ServiceStatusDialog({
    super.key,
    required this.initialStatus,
    required this.initialRemark,
  });

  final String initialStatus;
  final String initialRemark;

  @override
  State<ServiceStatusDialog> createState() => _ServiceStatusDialogState();
}

class _ServiceStatusDialogState extends State<ServiceStatusDialog> {
  late final TextEditingController _remarkController;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _remarkController = TextEditingController(text: widget.initialRemark);
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Ticket Update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration:
                const InputDecoration(labelText: 'Update for admin approval'),
            items: const [
              DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
              DropdownMenuItem(
                value: 'Not Resolved',
                child: Text('Not Resolved'),
              ),
            ],
            onChanged: (value) => setState(() {
              _status = value ?? 'Resolved';
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _remarkController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Remark',
              hintText: 'Describe what was done or why it is still pending.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _ServiceStatusDraft(
              status: _status,
              remark: _remarkController.text.trim(),
            ),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class UserProfile extends StatelessWidget {
  const UserProfile({super.key, required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profile Details',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                _ProfileRow(label: 'Name', value: user.fullName),
                const SizedBox(height: 12),
                _ProfileRow(label: 'Email', value: user.email),
                const SizedBox(height: 12),
                _ProfileRow(label: 'Role', value: user.roleLabel),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.ink,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppPalette.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppPalette.muted, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: AppPalette.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _api = ApiService();
  List<TicketItem> _tickets = [];
  bool _loading = true;
  String _selectedSite = '';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final tickets = await _api.tickets(
        userId: widget.user.id,
        role: widget.user.role,
        siteArea: _selectedSite.isEmpty ? null : _selectedSite);
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _loading = false;
    });
  }

  Future<void> _changeStatus(TicketItem ticket, String status) async {
    String? remark;
    if (status == 'Cancelled') {
      remark = await _cancelDialog();
      if (remark == null || remark.trim().isEmpty) return;
    }
    if (status == 'Hold') {
      remark = await _holdDialog();
      if (remark == null || remark.trim().isEmpty) return;
    }
    try {
      await _api.updateStatus(
        ticket.id,
        status,
        adminRemark: remark,
        adminUserId: widget.user.id,
      );
      await _loadTickets();
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<String?> _cancelDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ticket'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Cancellation remark'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Submit')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _holdDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Put Ticket on Hold'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Hold remark'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _assignTicket(TicketItem ticket) async {
    final nav = Navigator.of(context);
    bool showingLoader = false;

    try {
      showingLoader = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final options = await _api.assignees(
        siteArea: ticket.siteArea,
        serviceType: ticket.serviceType,
        serviceName: ticket.serviceName,
        locationName: ticket.locationName,
      );

      if (!mounted) {
        if (showingLoader) nav.pop();
        return;
      }
      if (showingLoader) {
        nav.pop();
        showingLoader = false;
      }
      if (options.isEmpty) {
        showAppToast(context, 'No assignees configured for this service.',
            error: true);
        return;
      }

      AssigneePerson selected = options.first;
      final personId = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Assign Ticket'),
          content: StatefulBuilder(
            builder: (context, setState) =>
                DropdownButtonFormField<AssigneePerson>(
              key: ValueKey(selected.id),
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Assign to'),
              items: options
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.fullName),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                if (value != null) selected = value;
              }),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected.id),
              child: const Text('Assign'),
            ),
          ],
        ),
      );

      if (personId == null) return;
      await _api.assignTicket(
        ticketId: ticket.id,
        personId: personId,
        adminUserId: widget.user.id,
      );
      await _loadTickets();
    } catch (error) {
      if (!mounted) return;
      if (showingLoader) {
        nav.pop();
        showingLoader = false;
      }
      showAppToast(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  List<Widget> _buildAdminActions(TicketItem ticket) {
    switch (ticket.status) {
      case 'Resolved':
        return const [];
      case 'Cancelled':
        return const [];
      case 'Hold':
        return [
          OutlinedButton(
            onPressed: () => _assignTicket(ticket),
            child: const Text('Assign'),
          ),
          OutlinedButton(
            onPressed: () => _changeStatus(ticket, 'Resolved'),
            child: const Text('Solve'),
          ),
          const OutlinedButton(
            onPressed: null,
            child: Text('Hold'),
          ),
          ElevatedButton(
            onPressed: () => _changeStatus(ticket, 'Cancelled'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.ink,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Cancel'),
          ),
        ];
      default:
        return [
          OutlinedButton(
            onPressed: () => _assignTicket(ticket),
            child: const Text('Assign'),
          ),
          OutlinedButton(
            onPressed: () => _changeStatus(ticket, 'Resolved'),
            child: const Text('Solve'),
          ),
          OutlinedButton(
            onPressed: () => _changeStatus(ticket, 'Hold'),
            child: const Text('Hold'),
          ),
          ElevatedButton(
            onPressed: () => _changeStatus(ticket, 'Cancelled'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.ink,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Cancel'),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppPalette.ink, AppPalette.primaryRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Ticket Filters',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(widget.user.fullName,
                      style: const TextStyle(color: Color(0xFFF2D8D8))),
                ],
              ),
            ),
            ListTile(
              selected: _selectedSite.isEmpty,
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('All Tickets'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedSite = '';
                  _loading = true;
                });
                _loadTickets();
              },
            ),
            ...['Plant', 'Guesthouse', 'Colony', 'Hostel'].map(
              (site) => ListTile(
                selected: _selectedSite == site,
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: siteAccentTint(site),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: siteAccentColor(site).withValues(alpha: 0.7)),
                  ),
                  child: Icon(Icons.location_city_outlined,
                      color: siteAccentStrongColor(site), size: 18),
                ),
                title: Text(site),
                tileColor: _selectedSite == site ? siteAccentTint(site) : null,
                selectedTileColor: siteAccentTint(site),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedSite = site;
                    _loading = true;
                  });
                  _loadTickets();
                },
              ),
            ),
            const Divider(),
            ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: _logout),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTickets,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SectionBanner(
                    title: _selectedSite.isEmpty
                        ? 'Latest Tickets'
                        : 'Latest $_selectedSite Tickets',
                    subtitle:
                        'Tap a ticket to view full details and admin actions.',
                    trailing: InfoPill(
                        label: _selectedSite.isEmpty
                            ? 'All Areas'
                            : _selectedSite),
                  ),
                  const SizedBox(height: 16),
                  if (_tickets.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Text('No tickets available for this filter.',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ..._tickets.map(
                    (ticket) {
                      final actions = _buildAdminActions(ticket);
                      return TicketCard(
                        ticket: ticket,
                        showRequestedBy: true,
                        collapsible: true,
                        initiallyExpanded: false,
                        footer: actions.isEmpty
                            ? null
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: actions,
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class TicketCard extends StatefulWidget {
  const TicketCard({
    super.key,
    required this.ticket,
    required this.showRequestedBy,
    this.footer,
    this.onReopen,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  final TicketItem ticket;
  final bool showRequestedBy;
  final Widget? footer;
  final Future<void> Function(TicketItem ticket)? onReopen;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF2E7D32);
      case 'Hold':
        return const Color(0xFFEF6C00);
      case 'Cancelled':
        return AppPalette.ink;
      default:
        return AppPalette.primaryRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final accent = siteAccentColor(ticket.siteArea);
    final accentStrong = siteAccentStrongColor(ticket.siteArea);
    final accentTint = siteAccentTint(ticket.siteArea);
    final pendingRequestVisible = ticket.pendingServiceStatus.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: widget.collapsible
            ? () {
                setState(() {
                  _expanded = !_expanded;
                });
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [Colors.white, accentTint.withValues(alpha: 0.42)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(left: BorderSide(color: accentStrong, width: 7)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticket.ticketNumber,
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: accentTint,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.8)),
                            ),
                            child: Text(
                              ticket.siteArea,
                              style: TextStyle(
                                color: accentStrong,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(ticket.status,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      backgroundColor: _statusColor(ticket.status),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('${ticket.serviceType} - ${ticket.serviceName}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  _MetaLine(label: 'Location', value: ticket.locationName),
                  if (ticket.assignedPerson != null) ...[
                    const SizedBox(height: 8),
                    _MetaLine(
                      label: 'Assigned To',
                      value: ticket.assignedPerson!.fullName,
                    ),
                  ],
                  if (ticket.reopenCount > 0 || ticket.escalationLevel > 0) ...[
                    const SizedBox(height: 8),
                    _MetaLine(
                      label: 'Escalation',
                      value: 'Level ${ticket.escalationLevel}',
                    ),
                  ],
                  if (ticket.remarks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetaLine(label: 'User Remark', value: ticket.remarks),
                  ],
                  if (ticket.adminRemark.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetaLine(label: 'Admin Remark', value: ticket.adminRemark),
                  ],
                  if (pendingRequestVisible) ...[
                    const SizedBox(height: 8),
                    _MetaLine(
                      label: 'Service Update',
                      value: ticket.pendingServiceStatus,
                    ),
                    if (ticket.pendingServiceRemark.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _MetaLine(
                        label: 'Service Remark',
                        value: ticket.pendingServiceRemark,
                      ),
                    ],
                  ],
                  if (widget.showRequestedBy) ...[
                    const SizedBox(height: 8),
                    _MetaLine(
                        label: 'Requested By',
                        value:
                            '${ticket.requestedBy} (${ticket.requestedByEmail})'),
                  ],
                  if (!widget.showRequestedBy &&
                      widget.onReopen != null &&
                      ticket.status == 'Resolved' &&
                      ticket.reopenCount < 3) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onReopen!(ticket),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reopen'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Updated: ${ticket.updatedAt.toLocal()}',
                      style: const TextStyle(color: AppPalette.muted)),
                  if (widget.footer != null) ...[
                    const SizedBox(height: 14),
                    widget.footer!,
                  ],
                ] else if (!widget.collapsible) ...[
                  const SizedBox(height: 8),
                  _MetaLine(label: 'Location', value: ticket.locationName),
                  if (ticket.assignedPerson != null) ...[
                    const SizedBox(height: 8),
                    _MetaLine(
                      label: 'Assigned To',
                      value: ticket.assignedPerson!.fullName,
                    ),
                  ],
                  if (ticket.reopenCount > 0 || ticket.escalationLevel > 0) ...[
                    const SizedBox(height: 8),
                    _MetaLine(
                      label: 'Escalation',
                      value: 'Level ${ticket.escalationLevel}',
                    ),
                  ],
                  if (ticket.remarks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetaLine(label: 'User Remark', value: ticket.remarks),
                  ],
                  if (ticket.adminRemark.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MetaLine(label: 'Admin Remark', value: ticket.adminRemark),
                  ],
                  if (pendingRequestVisible) ...[
                    const SizedBox(height: 8),
                    _MetaLine(
                      label: 'Service Update',
                      value: ticket.pendingServiceStatus,
                    ),
                    if (ticket.pendingServiceRemark.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _MetaLine(
                        label: 'Service Remark',
                        value: ticket.pendingServiceRemark,
                      ),
                    ],
                  ],
                  if (widget.showRequestedBy) ...[
                    const SizedBox(height: 8),
                    _MetaLine(
                        label: 'Requested By',
                        value:
                            '${ticket.requestedBy} (${ticket.requestedByEmail})'),
                  ],
                  if (!widget.showRequestedBy &&
                      widget.onReopen != null &&
                      ticket.status == 'Resolved' &&
                      ticket.reopenCount < 3) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onReopen!(ticket),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reopen'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Updated: ${ticket.updatedAt.toLocal()}',
                      style: const TextStyle(color: AppPalette.muted)),
                  if (widget.footer != null) ...[
                    const SizedBox(height: 14),
                    widget.footer!,
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style:
            const TextStyle(fontSize: 14, color: AppPalette.muted, height: 1.5),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
                color: AppPalette.ink, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
