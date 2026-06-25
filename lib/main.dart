import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/add_edit_listing_screen.dart';
import 'screens/data_transfer_screen.dart';
import 'screens/edit_selection_screen.dart';
import 'screens/listing_screen.dart';
import 'screens/sold_screen.dart';
import 'services/address_repository.dart';
import 'services/app_database.dart';
import 'services/photo_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  runApp(const SorgunEmlakApp());
}

class SorgunEmlakApp extends StatelessWidget {
  const SorgunEmlakApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF156C5B);
    return MaterialApp(
      title: 'Sorgun Emlak Defteri',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ).copyWith(
          secondary: const Color(0xFFE9B44C),
          tertiary: const Color(0xFF3F7C85),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ).copyWith(
          secondary: const Color(0xFFE9B44C),
          tertiary: const Color(0xFF72A8B0),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: const AppHome(),
    );
  }
}

enum AppSection {
  listings,
  add,
  edit,
  sold,
  dataTransfer;

  String get title {
    switch (this) {
      case AppSection.listings:
        return 'Listeleme';
      case AppSection.add:
        return 'Ekleme';
      case AppSection.edit:
        return 'Düzenleme';
      case AppSection.sold:
        return 'Satılanlar';
      case AppSection.dataTransfer:
        return 'Veri Aktarımı';
    }
  }

  IconData get icon {
    switch (this) {
      case AppSection.listings:
        return Icons.view_list_outlined;
      case AppSection.add:
        return Icons.add_business_outlined;
      case AppSection.edit:
        return Icons.edit_note_outlined;
      case AppSection.sold:
        return Icons.inventory_2_outlined;
      case AppSection.dataTransfer:
        return Icons.sync_alt_outlined;
    }
  }
}

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  late final AppDatabase _database;
  late final AddressRepository _addressRepository;
  late final PhotoService _photoService;
  AppSection _section = AppSection.listings;
  int _refreshNonce = 0;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _addressRepository = AddressRepository();
    _photoService = PhotoService();
  }

  void _openSection(AppSection section) {
    Navigator.of(context).pop();
    setState(() => _section = section);
  }

  void _dataChanged() {
    setState(() => _refreshNonce++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _section.title,
            key: ValueKey(_section),
          ),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: _DrawerHeader(current: _section),
              ),
              const Divider(height: 1),
              for (final section in AppSection.values)
                ListTile(
                  selected: section == _section,
                  leading: Icon(section.icon),
                  title: Text(section.title),
                  onTap: () => _openSection(section),
                ),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey('${_section.name}-$_refreshNonce'),
          child: _buildSection(),
        ),
      ),
      floatingActionButton: _section == AppSection.listings
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _section = AppSection.add),
              icon: const Icon(Icons.add),
              label: const Text('Yeni ilan'),
            )
          : null,
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case AppSection.listings:
        return ListingScreen(
          database: _database,
          addressRepository: _addressRepository,
          refreshNonce: _refreshNonce,
        );
      case AppSection.add:
        return AddEditListingScreen(
          database: _database,
          addressRepository: _addressRepository,
          photoService: _photoService,
          onSaved: () {
            _dataChanged();
            setState(() => _section = AppSection.listings);
          },
        );
      case AppSection.edit:
        return EditSelectionScreen(
          database: _database,
          addressRepository: _addressRepository,
          photoService: _photoService,
          onChanged: _dataChanged,
          refreshNonce: _refreshNonce,
        );
      case AppSection.sold:
        return SoldScreen(
          database: _database,
          refreshNonce: _refreshNonce,
        );
      case AppSection.dataTransfer:
        return DataTransferScreen(
          database: _database,
          onImported: _dataChanged,
        );
    }
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.current});

  final AppSection current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.home_work_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sorgun Emlak Defteri',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                current.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
