import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const FacilityServiceApp());
}

class FacilityServiceApp extends StatelessWidget {
  const FacilityServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC62828);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MY VOICE',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F6F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: red,
          brightness: Brightness.light,
          primary: red,
          secondary: Colors.black,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: red, width: 1.5),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class ApiConfig {
  static const baseUrl = 'http://10.0.2.2:4000/api';
}

class ApiService {
  Future<AppUser> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Login failed');
    }
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> catalog() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/catalog/options'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<TicketItem>> tickets({required int userId, required String role, String? siteArea}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/tickets').replace(
      queryParameters: {
        'userId': '$userId',
        'role': role,
        if (siteArea != null && siteArea.isNotEmpty) 'siteArea': siteArea,
      },
    );
    final response = await http.get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['tickets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
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

  Future<TicketItem> updateStatus(int ticketId, String status, {String? adminRemark}) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/tickets/$ticketId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, 'adminRemark': adminRemark}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to update ticket');
    }
    return TicketItem.fromJson(data['ticket'] as Map<String, dynamic>);
  }
}

class AppUser {
  const AppUser({required this.id, required this.fullName, required this.email, required this.role});

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
      requestedBy: json['requestedBy'] as String? ?? '',
      requestedByEmail: json['requestedByEmail'] as String? ?? '',
      siteColor: json['siteColor'] as String? ?? '#c62828',
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  bool _loading = false;

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
      final user = await _api.login(_emailController.text.trim(), _passwordController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => user.role == 'admin_user' ? AdminDashboard(user: user) : UserDashboard(user: user),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFFDEBEB), Color(0xFFF7F7F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC62828),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.apartment, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 18),
                        const Text('Facility Service Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text(
                          'Light mode service app for plant, guesthouse, and colony maintenance requests.',
                          style: TextStyle(color: Colors.black54, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter email' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter password' : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC62828),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Login'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Demo Accounts', style: TextStyle(fontWeight: FontWeight.w700)),
                              SizedBox(height: 6),
                              Text('User: user@fsm.com / user123'),
                              Text('Admin: admin@fsm.com / admin123'),
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
    final tickets = await _api.tickets(userId: widget.user.id, role: widget.user.role);
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _tickets = tickets;
      _loading = false;
    });
  }

  Future<void> _refreshTickets() async {
    final tickets = await _api.tickets(userId: widget.user.id, role: widget.user.role);
    if (!mounted) return;
    setState(() => _tickets = tickets);
  }

  Future<void> _openCreateTicket() async {
    if (_catalog.isEmpty) return;
    final created = await Navigator.of(context).push<TicketItem>(
      MaterialPageRoute(builder: (_) => CreateTicketScreen(user: widget.user, catalog: _catalog)),
    );
    if (created != null) {
      await _refreshTickets();
      if (mounted) setState(() => _tab = 1);
    }
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      UserHome(user: widget.user, onCreate: _openCreateTicket),
      TicketHistory(tickets: _tickets, loading: _loading, onRefresh: _refreshTickets, showRequestedBy: false),
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
          NavigationDestination(icon: Icon(Icons.confirmation_num_outlined), label: 'Tickets'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class UserHome extends StatelessWidget {
  const UserHome({super.key, required this.user, required this.onCreate});

  final AppUser user;
  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    const sites = ['Plant', 'Guesthouse', 'Colony'];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Welcome, ${user.fullName}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Choose one of the three areas, then create a service ticket with remarks and location details.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        ...sites.map((site) => Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: CircleAvatar(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white, child: Text(site[0])),
                title: Text(site, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Open service types, locations, and ticket submission'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded),
                onTap: onCreate,
              ),
            )),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_task),
          label: const Text('Register New Ticket'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ],
    );
  }
}

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key, required this.user, required this.catalog});

  final AppUser user;
  final Map<String, dynamic> catalog;

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

  List<String> get sites => (widget.catalog['sites'] as List<dynamic>).cast<String>();
  Map<String, dynamic> get serviceCatalog => widget.catalog['serviceCatalog'] as Map<String, dynamic>;
  Map<String, dynamic> get locationCatalog => widget.catalog['locationCatalog'] as Map<String, dynamic>;

  List<String> get serviceTypes {
    if (site == null) return [];
    return (serviceCatalog[site] as Map<String, dynamic>).keys.cast<String>().toList();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ticket ${ticket.ticketNumber} created successfully.')));
      Navigator.pop(context, ticket);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Ticket')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Register Service Request', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Select site, service type, specific service, location, and optional remarks.', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: site,
                      decoration: const InputDecoration(labelText: 'Area'),
                      items: sites.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (value) => setState(() {
                        site = value;
                        serviceType = null;
                        serviceName = null;
                        location = null;
                      }),
                      validator: (value) => value == null ? 'Select area' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: serviceType,
                      decoration: const InputDecoration(labelText: 'Service Type'),
                      items: serviceTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (value) => setState(() {
                        serviceType = value;
                        serviceName = null;
                      }),
                      validator: (value) => value == null ? 'Select service type' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: serviceName,
                      decoration: const InputDecoration(labelText: 'Specific Service'),
                      items: serviceNames.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (value) => setState(() => serviceName = value),
                      validator: (value) => value == null ? 'Select specific service' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: location,
                      decoration: const InputDecoration(labelText: 'Location'),
                      items: locations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (value) => setState(() => location = value),
                      validator: (value) => value == null ? 'Select location' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarksController,
                      minLines: 4,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Remarks', alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
  const TicketHistory({super.key, required this.tickets, required this.loading, required this.onRefresh, required this.showRequestedBy});

  final List<TicketItem> tickets;
  final bool loading;
  final Future<void> Function() onRefresh;
  final bool showRequestedBy;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Ticket History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('See previous registered tickets with current status and admin actions.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          if (tickets.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No tickets found.'))),
          ...tickets.map((ticket) => TicketCard(ticket: ticket, showRequestedBy: showRequestedBy)),
        ],
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text('Name: ${user.fullName}'),
                const SizedBox(height: 8),
                Text('Email: ${user.email}'),
                const SizedBox(height: 8),
                Text('Role: ${user.role}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: const Text('Logout'),
        ),
      ],
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
    final tickets = await _api.tickets(userId: widget.user.id, role: widget.user.role, siteArea: _selectedSite.isEmpty ? null : _selectedSite);
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
    await _api.updateStatus(ticket.id, status, adminRemark: remark);
    await _loadTickets();
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFC62828)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Ticket Filters', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(widget.user.fullName, style: const TextStyle(color: Colors.white70)),
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
            ...['Plant', 'Guesthouse', 'Colony'].map(
              (site) => ListTile(
                selected: _selectedSite == site,
                leading: const Icon(Icons.location_city_outlined),
                title: Text(site),
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
            ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: _logout),
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
                  Text(_selectedSite.isEmpty ? 'Latest Tickets' : 'Latest $_selectedSite Tickets', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Color labels distinguish plant, guesthouse, and colony tickets. Admin actions reflect for users instantly after refresh.', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  if (_tickets.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No tickets available for this filter.'))),
                  ..._tickets.map(
                    (ticket) => TicketCard(
                      ticket: ticket,
                      showRequestedBy: true,
                      footer: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(onPressed: () => _changeStatus(ticket, 'Resolved'), child: const Text('Solve')),
                          OutlinedButton(onPressed: () => _changeStatus(ticket, 'Hold'), child: const Text('Hold')),
                          ElevatedButton(
                            onPressed: () => _changeStatus(ticket, 'Cancelled'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                            child: const Text('Cancel'),
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
}

class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket, required this.showRequestedBy, this.footer});

  final TicketItem ticket;
  final bool showRequestedBy;
  final Widget? footer;

  Color _colorFromHex(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'Hold':
        return Colors.orange;
      case 'Cancelled':
        return Colors.black;
      default:
        return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border(left: BorderSide(color: _colorFromHex(ticket.siteColor), width: 6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(ticket.ticketNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  Chip(
                    label: Text(ticket.status, style: const TextStyle(color: Colors.white)),
                    backgroundColor: _statusColor(ticket.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${ticket.siteArea} � ${ticket.serviceType} � ${ticket.serviceName}'),
              const SizedBox(height: 6),
              Text('Location: ${ticket.locationName}'),
              if (ticket.remarks.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('User Remark: ${ticket.remarks}'),
              ],
              if (ticket.adminRemark.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Admin Remark: ${ticket.adminRemark}'),
              ],
              if (showRequestedBy) ...[
                const SizedBox(height: 6),
                Text('Requested By: ${ticket.requestedBy} (${ticket.requestedByEmail})'),
              ],
              const SizedBox(height: 8),
              Text('Updated: ${ticket.updatedAt.toLocal()}', style: const TextStyle(color: Colors.black54)),
              if (footer != null) ...[
                const SizedBox(height: 14),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
