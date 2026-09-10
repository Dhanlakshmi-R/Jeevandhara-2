import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  AppUser? _user;
  bool _isLoading = true;
  String? _errorMessage;

  // Placeholder tiles for each ASIP objective. Each one becomes a real
  // screen as that objective is built (see the week-by-week plan).
  final List<_FeatureTile> _features = const [
    _FeatureTile('Weather Alerts', Icons.wb_sunny, 'Objective 1'),
    _FeatureTile('Crop Prices', Icons.trending_up, 'Objective 2'),
    _FeatureTile('Trader Matching', Icons.handshake, 'Objective 3'),
    _FeatureTile('Crop Quality Check', Icons.camera_alt, 'Objective 4'),
    _FeatureTile('Marketplace & Rentals', Icons.store, 'Objective 5'),
    _FeatureTile('Voice Assistant', Icons.mic, 'Objective 6'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _apiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeevandhara'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : RefreshIndicator(
                  onRefresh: _loadUser,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Welcome, ${_user?.name ?? ''}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Role: ${_user?.role ?? ''}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: _features.map((f) => _buildFeatureCard(f)).toList(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFeatureCard(_FeatureTile feature) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${feature.title} — coming soon')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(feature.icon, size: 36, color: Colors.green),
              const SizedBox(height: 8),
              Text(feature.title, textAlign: TextAlign.center),
              Text(
                feature.subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile {
  final String title;
  final IconData icon;
  final String subtitle;
  const _FeatureTile(this.title, this.icon, this.subtitle);
}
