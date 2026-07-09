import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/property_listing.dart';
import '../models/property_type.dart';
import '../services/address_repository.dart';
import '../services/app_database.dart';
import '../services/contact_picker_service.dart';
import '../services/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/listing_card.dart';
import '../widgets/search_selection_field.dart';
import 'property_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
    required this.database,
    required this.addressRepository,
    required this.onChanged,
    required this.refreshNonce,
  });

  final AppDatabase database;
  final AddressRepository addressRepository;
  final VoidCallback onChanged;
  final int refreshNonce;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Future<List<Customer>> _future;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = widget.database.getCustomers();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant CustomersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.database.getCustomers());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Müşteri ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Yeni müşteri',
                onPressed: _openNewCustomer,
                icon: const Icon(Icons.person_add_alt_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Customer>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final customers = _filter(snapshot.data ?? const []);
              if (customers.isEmpty) {
                return EmptyState(
                  icon: Icons.people_alt_outlined,
                  title: 'Müşteri yok',
                  message: 'Yeni müşteri ekleyerek takip listesi oluşturun.',
                  action: FilledButton.icon(
                    onPressed: _openNewCustomer,
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: const Text('Müşteri ekle'),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final previous =
                        index == 0 ? null : customers[index - 1].fullName;
                    final showHeader =
                        _groupKey(previous) != _groupKey(customer.fullName);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
                            child: Text(
                              _groupKey(customer.fullName),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(customer.fullName),
                          subtitle: Text(customer.phone),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openCustomer(customer),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Customer> _filter(List<Customer> customers) {
    final query = _normalize(_searchController.text);
    if (query.isEmpty) {
      return customers;
    }
    return customers.where((customer) {
      final haystack = _normalize('${customer.fullName} ${customer.phone}');
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _openNewCustomer() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CustomerEditScreen(database: widget.database),
      ),
    );
    if (changed == true && mounted) {
      widget.onChanged();
      await _refresh();
    }
  }

  Future<void> _openCustomer(Customer customer) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CustomerDetailScreen(
          database: widget.database,
          addressRepository: widget.addressRepository,
          customer: customer,
        ),
      ),
    );
    if (changed == true && mounted) {
      widget.onChanged();
      await _refresh();
    }
  }

  String _groupKey(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return '#';
    }
    return trimmed.characters.first.toUpperCase();
  }
}

class CustomerEditScreen extends StatefulWidget {
  const CustomerEditScreen({
    super.key,
    required this.database,
    this.customer,
  });

  final AppDatabase database;
  final Customer? customer;

  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactPickerService = const ContactPickerService();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.fullName);
    _phoneController = TextEditingController(text: widget.customer?.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.customer == null ? 'Müşteri ekle' : 'Müşteri düzenle'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              OutlinedButton.icon(
                onPressed: _pickContact,
                icon: const Icon(Icons.contacts_outlined),
                label: const Text('Rehberden seç'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Ad soyad',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Ad soyad girin.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Telefon girin.' : null,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickContact() async {
    try {
      final contact = await _contactPickerService.pickContact();
      if (!mounted || contact == null || contact.isEmpty) {
        return;
      }
      setState(() {
        if (contact.name.isNotEmpty) {
          _nameController.text = contact.name;
        }
        if (contact.phones.isNotEmpty) {
          _phoneController.text = contact.phones.first;
        }
      });
    } on PlatformException catch (error) {
      _showSnack(error.code == 'permission_denied'
          ? 'Rehber izni verilmedi.'
          : 'Rehberden kişi seçilemedi.');
    } catch (error) {
      _showSnack('Rehberden kişi seçilemedi: $error');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final previous = widget.customer;
    final customer = Customer(
      id: previous?.id,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      minBudget: previous?.minBudget,
      maxBudget: previous?.maxBudget,
      notes: previous?.notes ?? '',
      requestFilter: previous?.requestFilter ?? const CustomerRequestFilter(),
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      if (previous == null) {
        await widget.database.insertCustomer(customer);
      } else {
        await widget.database.updateCustomer(customer);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.database,
    required this.addressRepository,
    required this.customer,
  });

  final AppDatabase database;
  final AddressRepository addressRepository;
  final Customer customer;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer _customer;
  late CustomerRequestFilter _requestFilter;
  late Future<AddressBook> _addressFuture;
  late Future<List<PropertyListing>> _soldFuture;
  late final TextEditingController _minBudgetController;
  late final TextEditingController _maxBudgetController;
  late final TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _requestFilter = _customer.requestFilter;
    _addressFuture = widget.addressRepository.load();
    _soldFuture = _loadSoldListings();
    _minBudgetController = TextEditingController(
      text: _customer.minBudget == null
          ? ''
          : _customer.minBudget!.toStringAsFixed(0),
    );
    _maxBudgetController = TextEditingController(
      text: _customer.maxBudget == null
          ? ''
          : _customer.maxBudget!.toStringAsFixed(0),
    );
    _notesController = TextEditingController(text: _customer.notes);
  }

  @override
  void dispose() {
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<List<PropertyListing>> _loadSoldListings() {
    final id = _customer.id;
    if (id == null) {
      return Future.value(const []);
    }
    return widget.database.getSoldListingsForCustomer(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.fullName),
        actions: [
          IconButton(
            tooltip: 'Müşteri bilgilerini düzenle',
            onPressed: _editContact,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Müşteriyi sil',
            onPressed: _deleteCustomer,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customer.fullName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_customer.phone),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _call(_customer.phone),
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Ara'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _openWhatsApp(_customer.phone),
                            icon: const Icon(Icons.chat_outlined),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bütçe',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minBudgetController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Minimum bütçe',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maxBudgetController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Maksimum bütçe',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _RequestSummaryCard(
              filter: _requestFilter,
              onEdit: _editRequestFilter,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Müşteri notu',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Müşteri isteğini kaydet'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _openMatches,
              icon: const Icon(Icons.manage_search_outlined),
              label: const Text('Sonuçlara göz at'),
            ),
            const SizedBox(height: 24),
            Text(
              'Satın aldığı ilanlar',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<PropertyListing>>(
              future: _soldFuture,
              builder: (context, snapshot) {
                final soldListings = snapshot.data ?? const [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (soldListings.isEmpty) {
                  return Text(
                    'Bu müşteriye bağlı satış kaydı yok.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final listing in soldListings)
                      ListingCard(
                        listing: listing,
                        showSoldPrice: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openListing(listing, soldView: true),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editContact() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CustomerEditScreen(
          database: widget.database,
          customer: _customer,
        ),
      ),
    );
    if (changed != true || !mounted || _customer.id == null) {
      return;
    }
    final updated = await widget.database.getCustomer(_customer.id!);
    if (!mounted || updated == null) {
      return;
    }
    setState(() => _customer = updated);
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Müşteri silinsin mi?'),
        content: const Text(
          'Müşteri kaydı ve ilanlardaki ilgi bağlantıları kaldırılır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || _customer.id == null) {
      return;
    }
    await widget.database.deleteCustomer(_customer.id!);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _editRequestFilter() async {
    final addressBook = await _addressFuture;
    if (!mounted) {
      return;
    }
    final updated = await showModalBottomSheet<CustomerRequestFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RequestFilterSheet(
        addressBook: addressBook,
        initialFilter: _requestFilter,
      ),
    );
    if (updated != null && mounted) {
      setState(() => _requestFilter = updated);
    }
  }

  Future<void> _save({bool silent = false}) async {
    final id = _customer.id;
    if (id == null) {
      return;
    }
    setState(() => _saving = true);
    final updated = Customer(
      id: id,
      fullName: _customer.fullName,
      phone: _customer.phone,
      minBudget: parseOptionalNumberInput(_minBudgetController.text),
      maxBudget: parseOptionalNumberInput(_maxBudgetController.text),
      notes: _notesController.text.trim(),
      requestFilter: _requestFilter,
      createdAt: _customer.createdAt,
      updatedAt: DateTime.now(),
    );
    try {
      await widget.database.updateCustomer(updated);
      if (!mounted) {
        return;
      }
      setState(() {
        _customer = updated;
        _soldFuture = _loadSoldListings();
      });
      if (!silent) {
        _showSnack('Müşteri kaydedildi.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openMatches() async {
    await _save(silent: true);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomerMatchesScreen(
          database: widget.database,
          customer: _customer,
        ),
      ),
    );
  }

  void _openListing(PropertyListing listing, {bool soldView = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PropertyDetailScreen(
          database: widget.database,
          listing: listing,
          soldView: soldView,
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (!await launchUrl(uri)) {
      _showSnack('Arama açılamadı.');
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = _whatsAppPhone(phone);
    final uri = Uri.parse('https://wa.me/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('WhatsApp açılamadı.');
    }
  }

  String _whatsAppPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      return '90${digits.substring(1)}';
    }
    return digits;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class CustomerMatchesScreen extends StatefulWidget {
  const CustomerMatchesScreen({
    super.key,
    required this.database,
    required this.customer,
  });

  final AppDatabase database;
  final Customer customer;

  @override
  State<CustomerMatchesScreen> createState() => _CustomerMatchesScreenState();
}

class _CustomerMatchesScreenState extends State<CustomerMatchesScreen> {
  late Future<_CustomerMatchesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_CustomerMatchesData> _loadData() async {
    final listings = await widget.database.getActiveListings();
    final counts = await widget.database.getListingInterestCounts();
    final filtered = listings
        .where(
          (listing) => widget.customer.requestFilter.matches(
            listing,
            minBudget: widget.customer.minBudget,
            maxBudget: widget.customer.maxBudget,
          ),
        )
        .toList();
    return _CustomerMatchesData(listings: filtered, interestCounts: counts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.customer.fullName} sonuçları')),
      body: FutureBuilder<_CustomerMatchesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? const _CustomerMatchesData();
          if (data.listings.isEmpty) {
            return const EmptyState(
              icon: Icons.manage_search_outlined,
              title: 'Uygun aktif ilan yok',
              message: 'Müşteri bütçesi veya istek filtresini değiştirin.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _loadData());
              await _future;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: data.listings.length,
              itemBuilder: (context, index) {
                final listing = data.listings[index];
                return ListingCard(
                  listing: listing,
                  interestCount: data.interestCounts[listing.id] ?? 0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => PropertyDetailScreen(
                          database: widget.database,
                          listing: listing,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CustomerMatchesData {
  const _CustomerMatchesData({
    this.listings = const [],
    this.interestCounts = const {},
  });

  final List<PropertyListing> listings;
  final Map<int, int> interestCounts;
}

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({
    required this.filter,
    required this.onEdit,
  });

  final CustomerRequestFilter filter;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summary();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'İsteği',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune_outlined),
                  label: const Text('Düzenle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary.isEmpty ? 'Filtre seçilmedi.' : summary.join(' • '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _summary() {
    return [
      filter.dealType?.label,
      filter.type?.label,
      filter.placeKind?.label,
      filter.placeName,
      filter.streetName,
      filter.housingKind?.label,
      filter.roomLayout,
      if (filter.minSquareMeters != null)
        'Min ${_formatFilterArea(filter.minSquareMeters!)}',
      if (filter.maxSquareMeters != null)
        'Max ${_formatFilterArea(filter.maxSquareMeters!)}',
      if (filter.maxBuildingAge != null) 'Max yaş ${filter.maxBuildingAge}',
      if (filter.minBathroomCount != null)
        'Min banyo ${filter.minBathroomCount}',
      if (filter.minBalconyCount != null)
        'Min balkon ${filter.minBalconyCount}',
      filter.frontage,
      if ((filter.blockNo ?? '').trim().isNotEmpty) 'Ada ${filter.blockNo}',
      if ((filter.parcelNo ?? '').trim().isNotEmpty)
        'Parsel ${filter.parcelNo}',
    ].whereType<String>().where((item) => item.trim().isNotEmpty).toList();
  }

  String _formatFilterArea(num squareMeters) {
    if (filter.type == PropertyType.land || filter.type == PropertyType.field) {
      return formatLandArea(squareMeters, filter.areaUnit);
    }
    return formatArea(squareMeters);
  }
}

class _RequestFilterSheet extends StatefulWidget {
  const _RequestFilterSheet({
    required this.addressBook,
    required this.initialFilter,
  });

  final AddressBook addressBook;
  final CustomerRequestFilter initialFilter;

  @override
  State<_RequestFilterSheet> createState() => _RequestFilterSheetState();
}

class _RequestFilterSheetState extends State<_RequestFilterSheet> {
  late DealType? _dealType;
  late PropertyType? _type;
  late PlaceKind? _placeKind;
  late String? _placeName;
  late String? _streetName;
  late HousingKind? _housingKind;
  late AreaUnit _areaUnit;
  late final TextEditingController _blockController;
  late final TextEditingController _parcelController;
  late final TextEditingController _roomLayoutController;
  late final TextEditingController _minAreaController;
  late final TextEditingController _maxAreaController;
  late final TextEditingController _maxBuildingAgeController;
  late final TextEditingController _minBathroomController;
  late final TextEditingController _minBalconyController;
  late final TextEditingController _floorCountController;
  late final TextEditingController _floorNumberController;
  late final TextEditingController _frontageController;

  @override
  void initState() {
    super.initState();
    final filter = widget.initialFilter;
    _dealType = filter.dealType;
    _type = filter.type;
    _placeKind = filter.placeKind;
    _placeName = filter.placeName;
    _streetName = filter.streetName;
    _housingKind = filter.housingKind;
    _areaUnit = filter.areaUnit;
    _blockController = TextEditingController(text: filter.blockNo);
    _parcelController = TextEditingController(text: filter.parcelNo);
    _roomLayoutController = TextEditingController(text: filter.roomLayout);
    _minAreaController = TextEditingController(
      text: _formatAreaInput(filter.minSquareMeters),
    );
    _maxAreaController = TextEditingController(
      text: _formatAreaInput(filter.maxSquareMeters),
    );
    _maxBuildingAgeController =
        TextEditingController(text: filter.maxBuildingAge?.toString() ?? '');
    _minBathroomController =
        TextEditingController(text: filter.minBathroomCount?.toString() ?? '');
    _minBalconyController =
        TextEditingController(text: filter.minBalconyCount?.toString() ?? '');
    _floorCountController =
        TextEditingController(text: filter.floorCount?.toString() ?? '');
    _floorNumberController =
        TextEditingController(text: filter.floorNumber?.toString() ?? '');
    _frontageController = TextEditingController(text: filter.frontage);
  }

  @override
  void dispose() {
    _blockController.dispose();
    _parcelController.dispose();
    _roomLayoutController.dispose();
    _minAreaController.dispose();
    _maxAreaController.dispose();
    _maxBuildingAgeController.dispose();
    _minBathroomController.dispose();
    _minBalconyController.dispose();
    _floorCountController.dispose();
    _floorNumberController.dispose();
    _frontageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final places = _placeKind == null
        ? [
            ...widget.addressBook.neighborhoods,
            ...widget.addressBook.villages,
          ]
        : widget.addressBook.placesFor(_placeKind!);
    final isApartment = _type == PropertyType.apartment;
    final isLand = _type == PropertyType.land || _type == PropertyType.field;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          8,
          18,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Müşteri isteği',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _FilterSegment<DealType>(
                label: 'Satılık / Kiralık',
                values: DealType.values,
                selected: _dealType,
                labelFor: (value) => value.label,
                onChanged: (value) => setState(() => _dealType = value),
              ),
              const SizedBox(height: 12),
              _FilterSegment<PropertyType>(
                label: 'Mülk tipi',
                values: PropertyType.values,
                selected: _type,
                labelFor: (value) => value.label,
                onChanged: (value) {
                  setState(() {
                    _type = value;
                    if (_type == PropertyType.apartment) {
                      _blockController.clear();
                      _parcelController.clear();
                      _areaUnit = AreaUnit.squareMeter;
                    } else {
                      _roomLayoutController.clear();
                      _maxBuildingAgeController.clear();
                      _minBathroomController.clear();
                      _minBalconyController.clear();
                      _floorCountController.clear();
                      _floorNumberController.clear();
                      _frontageController.clear();
                      _housingKind = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _FilterSegment<PlaceKind>(
                label: 'Yer türü',
                values: PlaceKind.values,
                selected: _placeKind,
                labelFor: (value) => value.label,
                onChanged: (value) {
                  setState(() {
                    _placeKind = value;
                    _placeName = null;
                    _streetName = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              SearchSelectionField(
                label: 'Mahalle/Köy',
                value: places.contains(_placeName) ? _placeName : null,
                options: places,
                emptyText: 'Hepsi',
                clearText: 'Hepsi',
                onChanged: (value) => setState(() => _placeName = value),
              ),
              const SizedBox(height: 12),
              SearchSelectionField(
                label: 'Cadde/Sokak/Yol',
                value: widget.addressBook.streets.contains(_streetName)
                    ? _streetName
                    : null,
                options: widget.addressBook.streets,
                emptyText: 'Hepsi',
                clearText: 'Hepsi',
                onChanged: (value) => setState(() => _streetName = value),
              ),
              if (isApartment) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _roomLayoutController,
                  decoration: const InputDecoration(
                    labelText: 'Oda tipi',
                    hintText: '3+1',
                  ),
                ),
                const SizedBox(height: 12),
                _AreaRow(
                  minController: _minAreaController,
                  maxController: _maxAreaController,
                  suffix: 'm²',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _maxBuildingAgeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max bina yaşı',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _minBathroomController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min banyo',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minBalconyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min balkon',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<HousingKind>(
                        initialValue: _housingKind,
                        decoration:
                            const InputDecoration(labelText: 'Konut tipi'),
                        items: [
                          const DropdownMenuItem<HousingKind>(
                            child: Text('Hepsi'),
                          ),
                          ...HousingKind.values.map(
                            (kind) => DropdownMenuItem<HousingKind>(
                              value: kind,
                              child: Text(kind.label),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _housingKind = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _floorCountController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Toplam kat'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _floorNumberController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Bulunduğu kat'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _frontageController,
                  decoration: const InputDecoration(labelText: 'Cephe'),
                ),
              ],
              if (isLand) ...[
                const SizedBox(height: 12),
                SegmentedButton<AreaUnit>(
                  segments: AreaUnit.values
                      .map(
                        (unit) => ButtonSegment<AreaUnit>(
                          value: unit,
                          label: Text(unit.label),
                        ),
                      )
                      .toList(),
                  selected: {_areaUnit},
                  onSelectionChanged: (value) {
                    setState(() => _changeAreaUnit(value.first));
                  },
                ),
                const SizedBox(height: 12),
                _AreaRow(
                  minController: _minAreaController,
                  maxController: _maxAreaController,
                  suffix: _areaUnit.suffix,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _blockController,
                        decoration: const InputDecoration(labelText: 'Ada'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _parcelController,
                        decoration: const InputDecoration(labelText: 'Parsel'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Temizle'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.check),
                      label: const Text('Kaydet'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clear() {
    setState(() {
      _dealType = null;
      _type = null;
      _placeKind = null;
      _placeName = null;
      _streetName = null;
      _housingKind = null;
      _areaUnit = AreaUnit.squareMeter;
      _blockController.clear();
      _parcelController.clear();
      _roomLayoutController.clear();
      _minAreaController.clear();
      _maxAreaController.clear();
      _maxBuildingAgeController.clear();
      _minBathroomController.clear();
      _minBalconyController.clear();
      _floorCountController.clear();
      _floorNumberController.clear();
      _frontageController.clear();
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      CustomerRequestFilter(
        dealType: _dealType,
        type: _type,
        placeKind: _placeKind,
        placeName: _placeName,
        streetName: _streetName,
        housingKind: _type == PropertyType.apartment ? _housingKind : null,
        blockNo: _type == PropertyType.apartment
            ? null
            : _emptyToNull(_blockController.text),
        parcelNo: _type == PropertyType.apartment
            ? null
            : _emptyToNull(_parcelController.text),
        roomLayout: _type == PropertyType.apartment
            ? _emptyToNull(_roomLayoutController.text)
            : null,
        minSquareMeters: _areaInputToSquareMeters(_minAreaController.text),
        maxSquareMeters: _areaInputToSquareMeters(_maxAreaController.text),
        areaUnit: _type == PropertyType.land || _type == PropertyType.field
            ? _areaUnit
            : AreaUnit.squareMeter,
        maxBuildingAge: _type == PropertyType.apartment
            ? _parseOptionalInt(_maxBuildingAgeController.text)
            : null,
        minBathroomCount: _type == PropertyType.apartment
            ? _parseOptionalInt(_minBathroomController.text)
            : null,
        minBalconyCount: _type == PropertyType.apartment
            ? _parseOptionalInt(_minBalconyController.text)
            : null,
        floorCount: _type == PropertyType.apartment
            ? _parseOptionalInt(_floorCountController.text)
            : null,
        floorNumber: _type == PropertyType.apartment
            ? _parseOptionalInt(_floorNumberController.text)
            : null,
        frontage: _type == PropertyType.apartment
            ? _emptyToNull(_frontageController.text)
            : null,
      ),
    );
  }

  void _changeAreaUnit(AreaUnit unit) {
    if (unit == _areaUnit) {
      return;
    }
    final min = parseOptionalNumberInput(_minAreaController.text);
    final max = parseOptionalNumberInput(_maxAreaController.text);
    if (min != null) {
      _minAreaController.text =
          _formatNumber(unit.fromSquareMeters(_areaUnit.toSquareMeters(min)));
    }
    if (max != null) {
      _maxAreaController.text =
          _formatNumber(unit.fromSquareMeters(_areaUnit.toSquareMeters(max)));
    }
    _areaUnit = unit;
  }

  String _formatAreaInput(double? squareMeters) {
    if (squareMeters == null) {
      return '';
    }
    return _formatNumber(_areaUnit.fromSquareMeters(squareMeters));
  }

  double? _areaInputToSquareMeters(String value) {
    final parsed = parseOptionalNumberInput(value);
    if (parsed == null) {
      return null;
    }
    if (_type == PropertyType.land || _type == PropertyType.field) {
      return _areaUnit.toSquareMeters(parsed);
    }
    return parsed;
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({
    required this.minController,
    required this.maxController,
    required this.suffix,
  });

  final TextEditingController minController;
  final TextEditingController maxController;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: minController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Min alan ($suffix)'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: maxController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Max alan ($suffix)'),
          ),
        ),
      ],
    );
  }
}

class _FilterSegment<T> extends StatelessWidget {
  const _FilterSegment({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T? selected;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<T>(
          emptySelectionAllowed: true,
          segments: values
              .map(
                (value) => ButtonSegment<T>(
                  value: value,
                  label: Text(labelFor(value)),
                ),
              )
              .toList(),
          selected: selected == null ? <T>{} : {selected as T},
          onSelectionChanged: (value) {
            onChanged(value.isEmpty ? null : value.first);
          },
        ),
      ],
    );
  }
}

String _formatNumber(num value) {
  final digits = value % 1 == 0 ? 0 : 2;
  return value.toStringAsFixed(digits);
}

int? _parseOptionalInt(String value) {
  final raw = value.trim();
  if (raw.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(raw);
  return parsed == null || parsed < 0 ? null : parsed;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('\u0307', '')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
