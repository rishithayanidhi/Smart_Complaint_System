import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth.dart';
import 'location_service.dart';
import 'history.dart';

final _secureStorage = const FlutterSecureStorage();

// Placeholder ComplaintFormScreen widget
class ComplaintFormScreen extends StatelessWidget {
  final String category;
  final Map<String, dynamic> userData;

  const ComplaintFormScreen({
    super.key,
    required this.category,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$category Complaint'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 64, color: Color(0xFF6366F1)),
              SizedBox(height: 16),
              Text(
                'Complaint Form',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This feature is under development',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomePage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildMainContent(context)),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --------------------------------------------------------------
  // Header Section
  // --------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    final name = userData['full_name'] ?? 'User';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name 👋',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Let’s make our city better!',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: () => HistoryDialog.showHistoryDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // Main Content
  // --------------------------------------------------------------
  Widget _buildMainContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCategoryGrid(context),
          const SizedBox(height: 20),
          _buildCommunityStats(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // Categories (Static UI)
  // --------------------------------------------------------------
  Widget _buildCategoryGrid(BuildContext context) {
    final categories = [
      {
        'title': 'Roads',
        'icon': Icons.construction_rounded,
        'color': 0xFF3B82F6,
      },
      {
        'title': 'Garbage',
        'icon': Icons.delete_sweep_rounded,
        'color': 0xFF10B981,
      },
      {
        'title': 'Electricity',
        'icon': Icons.flash_on_rounded,
        'color': 0xFFF59E0B,
      },
      {'title': 'Water', 'icon': Icons.water_drop_rounded, 'color': 0xFF06B6D4},
      {
        'title': 'Others',
        'icon': Icons.more_horiz_rounded,
        'color': 0xFF8B5CF6,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, i) {
        final c = categories[i];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComplaintFormScreen(
                category: c['title'] as String,
                userData: userData,
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(c['color'] as int),
                  Color(c['color'] as int).withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(c['color'] as int).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c['icon'] as IconData, color: Colors.white, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    c['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------
  // Quick Stats (Placeholder for backend integration)
  // --------------------------------------------------------------
  Widget _buildCommunityStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _StatCard(label: "Total", count: "106", color: Color(0xFF3B82F6)),
          _StatCard(label: "Resolved", count: "78", color: Color(0xFF10B981)),
          _StatCard(label: "Pending", count: "28", color: Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // Floating Action Button
  // --------------------------------------------------------------
  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _openReportSheet(context),
      backgroundColor: const Color(0xFF6366F1),
      label: const Text('Report Issue', style: TextStyle(color: Colors.white)),
      icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
    );
  }

  void _openReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReportOptions(),
    );
  }

  // --------------------------------------------------------------
  // Logout Logic
  // --------------------------------------------------------------
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _secureStorage.deleteAll();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------
// Small Widgets
// --------------------------------------------------------------
class _StatCard extends StatelessWidget {
  final String label;
  final String count;
  final Color color;
  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(height: 6),
        Text(
          count,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 20,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// --------------------------------------------------------------
// BottomSheet for quick report options
// --------------------------------------------------------------
class _ReportOptions extends StatelessWidget {
  const _ReportOptions();

  Future<void> _captureAndSend(BuildContext context) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;

    final location = await LocationService.getCurrentLocationWithAddress();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            location != null
                ? 'Photo captured at ${location.address}'
                : 'Photo captured (no location)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _selectFromGallery(BuildContext context) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (photo == null) return;

    final location = await LocationService.getCurrentLocationWithAddress();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            location != null
                ? 'Selected photo with location: ${location.address}'
                : 'Selected photo (location unavailable)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Container(
            height: 5,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Report an Issue',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: Colors.indigo),
            title: const Text('Take Photo'),
            onTap: () => _captureAndSend(context),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_library_rounded,
              color: Colors.green,
            ),
            title: const Text('Choose from Gallery'),
            onTap: () => _selectFromGallery(context),
          ),
        ],
      ),
    );
  }
}
