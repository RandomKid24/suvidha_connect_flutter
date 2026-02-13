import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/provider_avatar.dart';

class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  Map<String, dynamic>? _providerData;
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _availableFromDay;
  String? _availableToDay;
  TimeOfDay? _availableStartTime;
  TimeOfDay? _availableEndTime;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  bool _savingProfile = false;
  bool _savingPhoto = false;
  bool _savingDoc = false;
  bool _savingServices = false;
  final ImagePicker _imagePicker = ImagePicker();
  
  final List<Map<String, String>> _days = [
    {'value': 'monday', 'label': 'Monday'},
    {'value': 'tuesday', 'label': 'Tuesday'},
    {'value': 'wednesday', 'label': 'Wednesday'},
    {'value': 'thursday', 'label': 'Thursday'},
    {'value': 'friday', 'label': 'Friday'},
    {'value': 'saturday', 'label': 'Saturday'},
    {'value': 'sunday', 'label': 'Sunday'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  String _fullMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final base = ApiService.baseUrl.replaceFirst(RegExp(r'/api.*'), '');
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }

  Future<void> _saveBusinessInfo() async {
    final name = _businessNameController.text.trim();
    final address = _addressController.text.trim();
    final contact = _contactController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business name is required'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _savingProfile = true);
    final result = await ApiService.updateProviderProfile(
      name: name,
      address: address.isEmpty ? null : address,
      contact: contact.isEmpty ? null : contact,
    );
    if (mounted) {
      setState(() => _savingProfile = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business info updated')),
        );
        _loadProviderData(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?['message'] ?? 'Failed to update'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _changeProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.cardColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Iconsax.camera, color: context.foregroundColor),
              title: Text('Camera', style: TextStyle(color: context.foregroundColor)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Iconsax.gallery, color: context.foregroundColor),
              title: Text('Gallery', style: TextStyle(color: context.foregroundColor)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final XFile? picked = await _imagePicker.pickImage(source: source);
    if (picked == null || !mounted) return;
    setState(() => _savingPhoto = true);
    final result = await ApiService.updateProviderProfilePhoto(picked.path);
    if (mounted) {
      setState(() => _savingPhoto = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
        _loadProviderData(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?['message'] ?? 'Failed to update photo'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _viewDocument(String? url) async {
    final fullUrl = _fullMediaUrl(url);
    if (fullUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document to view')),
      );
      return;
    }
    final uri = Uri.tryParse(fullUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open: $fullUrl')),
      );
    }
  }

  Future<void> _changeDocument(String documentType) async {
    final useImage = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.cardColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Iconsax.document, color: context.foregroundColor),
              title: Text('File (PDF or image)', style: TextStyle(color: context.foregroundColor)),
              subtitle: Text('Pick from device storage', style: TextStyle(color: context.mutedForegroundColor, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: Icon(Iconsax.gallery, color: context.foregroundColor),
              title: Text('Camera or Gallery', style: TextStyle(color: context.foregroundColor)),
              subtitle: Text('Take photo or choose image', style: TextStyle(color: context.mutedForegroundColor, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (useImage == null) return;

    if (useImage) {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: context.cardColor,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Iconsax.camera, color: context.foregroundColor),
                title: Text('Camera', style: TextStyle(color: context.foregroundColor)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Iconsax.gallery, color: context.foregroundColor),
                title: Text('Gallery', style: TextStyle(color: context.foregroundColor)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final XFile? picked = await _imagePicker.pickImage(source: source);
      if (picked == null || !mounted) return;
      setState(() => _savingDoc = true);
      final apiResult = await ApiService.updateProviderDocument(
        documentType: documentType,
        filePath: picked.path,
      );
      if (mounted) {
        setState(() => _savingDoc = false);
        if (apiResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${documentType == 'pan_card' ? 'PAN Card' : 'Registration Certificate'} updated')),
          );
          _loadProviderData(forceRefresh: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiResult['error']?['message'] ?? 'Failed to update document'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      return;
    }

    // File picker (withData: true so we get bytes on Android when path is null)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    final bytes = file.bytes;
    final filename = file.name;
    if (path == null && (bytes == null || bytes.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file. Use Camera or Gallery instead.')),
        );
      }
      return;
    }
    setState(() => _savingDoc = true);
    final apiResult = path != null
        ? await ApiService.updateProviderDocument(documentType: documentType, filePath: path)
        : await ApiService.updateProviderDocumentWithBytes(
            documentType: documentType,
            bytes: bytes!,
            filename: filename.isNotEmpty ? filename : 'document.jpg',
          );
    if (mounted) {
      setState(() => _savingDoc = false);
      if (apiResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${documentType == 'pan_card' ? 'PAN Card' : 'Registration Certificate'} updated')),
        );
        _loadProviderData(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiResult['error']?['message'] ?? 'Failed to update document'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<int> get _currentServiceIds {
    final services = _providerData?['services'] as List?;
    if (services == null) return [];
    final list = <int>[];
    for (final s in services) {
      if (s is! Map) continue;
      final sc = s['service_category'];
      if (sc is Map && sc['id'] != null) {
        final id = sc['id'];
        if (id is int) list.add(id);
      }
    }
    return list;
  }

  Future<void> _openCategorySelector() async {
    final categoriesResult = await ApiService.getServiceCategories(forceRefresh: true);
    if (categoriesResult['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load categories'), backgroundColor: AppColors.error),
      );
      return;
    }
    final rawData = categoriesResult['data'];
    final List<dynamic> initialCategories = rawData is List
        ? List<Map<String, dynamic>>.from(rawData.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{'id': 0, 'name': '$e'}))
        : (rawData is Map && rawData.containsKey('results'))
            ? List<Map<String, dynamic>>.from((rawData['results'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{'id': 0, 'name': '$e'}))
            : <Map<String, dynamic>>[];
    final currentIds = _currentServiceIds.toSet();
    final selectedIds = currentIds.toList();
    if (!mounted) return;
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      builder: (ctx) {
        final localSelected = List<int>.from(selectedIds);
        final localCategories = List<Map<String, dynamic>>.from(initialCategories);
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> createNewCategory() async {
              final nameController = TextEditingController();
              final descController = TextEditingController();
              final created = await showDialog<Map<String, dynamic>>(
                context: ctx,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: context.cardColor,
                    title: Text('Create new category', style: TextStyle(color: context.foregroundColor)),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Category name',
                              labelStyle: TextStyle(color: context.mutedForegroundColor),
                              border: const OutlineInputBorder(),
                            ),
                            style: TextStyle(color: context.foregroundColor),
                            autofocus: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descController,
                            decoration: InputDecoration(
                              labelText: 'Description (optional)',
                              labelStyle: TextStyle(color: context.mutedForegroundColor),
                              border: const OutlineInputBorder(),
                            ),
                            style: TextStyle(color: context.foregroundColor),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Enter a category name')),
                            );
                            return;
                          }
                          Navigator.pop(dialogContext); // close dialog
                          final result = await ApiService.createServiceCategory(
                            name: name,
                            description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                          );
                          if (!ctx.mounted) return;
                          if (result['success'] == true && result['data'] is Map) {
                            final newCat = Map<String, dynamic>.from(result['data'] as Map);
                            final newId = newCat['id'] as int?;
                            if (newId != null) {
                              setModalState(() {
                                localCategories.add(newCat);
                                localSelected.add(newId);
                              });
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Created: $name')),
                              );
                            }
                          } else {
                            final err = result['error'] is Map ? (result['error'] as Map)['message'] ?? result['error'] : result['error'];
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(err?.toString() ?? 'Failed to create category'), backgroundColor: AppColors.error),
                            );
                          }
                        },
                        child: const Text('Create'),
                      ),
                    ],
                  );
                },
              );
            }
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select service categories',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: context.foregroundColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await createNewCategory();
                            },
                            icon: const Icon(Iconsax.add, size: 18),
                            label: const Text('New'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, localSelected),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: localCategories.length,
                        itemBuilder: (context, index) {
                          final cat = localCategories[index];
                          final id = cat['id'] as int? ?? 0;
                          final name = cat['name']?.toString() ?? '';
                          final isSelected = localSelected.contains(id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  localSelected.add(id);
                                } else {
                                  localSelected.remove(id);
                                }
                              });
                            },
                            title: Text(name, style: TextStyle(color: context.foregroundColor)),
                            activeColor: AppColors.primary,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => _savingServices = true);
    final result = await ApiService.updateProviderServices(picked);
    if (mounted) {
      setState(() => _savingServices = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service categories updated')),
        );
        _loadProviderData(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?['message'] ?? 'Failed to update categories'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeCategory(int categoryId) async {
    final current = _currentServiceIds;
    if (current.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one category'), backgroundColor: AppColors.error),
      );
      return;
    }
    final updated = current.where((id) => id != categoryId).toList();
    setState(() => _savingServices = true);
    final result = await ApiService.updateProviderServices(updated);
    if (mounted) {
      setState(() => _savingServices = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category removed')),
        );
        _loadProviderData(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?['message'] ?? 'Failed to update'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadProviderData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final result = await ApiService.getProviderProfile(forceRefresh: forceRefresh);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _providerData = result['data'];
          _businessNameController.text = _providerData?['name']?.toString() ?? '';
          _addressController.text = _providerData?['address']?.toString() ?? '';
          _contactController.text = _providerData?['contact']?.toString() ?? '';
          _availableFromDay = _providerData?['available_from_day'];
          _availableToDay = _providerData?['available_to_day'];
          
          // Parse time strings to TimeOfDay
          if (_providerData?['available_start_time'] != null) {
            final timeStr = _providerData!['available_start_time'].toString();
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              _availableStartTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
          }
          if (_providerData?['available_end_time'] != null) {
            final timeStr = _providerData!['available_end_time'].toString();
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              _availableEndTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
          }
          
          // Set price range
          if (_providerData?['min_price'] != null) {
            _minPriceController.text = _providerData!['min_price'].toString();
          }
          if (_providerData?['max_price'] != null) {
            _maxPriceController.text = _providerData!['max_price'].toString();
          }
          
          // Load reviews for this provider
          final providerId = _providerData?['id'];
          if (providerId != null) {
            _loadReviews(providerId, forceRefresh: forceRefresh);
          }
        }
      });
    }
  }
  
  Future<void> _loadReviews(int providerId, {bool forceRefresh = false}) async {
    final reviewsResult = await ApiService.getReviews(providerId: providerId, forceRefresh: forceRefresh);
    if (mounted && reviewsResult['success'] == true) {
      setState(() {
        _reviews = reviewsResult['data'] as List;
      });
    }
  }

  Future<void> _saveAvailability() async {
    if (_availableFromDay == null || _availableToDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select availability days'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    if (_availableStartTime == null || _availableEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select availability times'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    final result = await ApiService.updateProviderAvailability(
      availableFromDay: _availableFromDay,
      availableToDay: _availableToDay,
      availableStartTime: '${_availableStartTime!.hour.toString().padLeft(2, '0')}:${_availableStartTime!.minute.toString().padLeft(2, '0')}',
      availableEndTime: '${_availableEndTime!.hour.toString().padLeft(2, '0')}:${_availableEndTime!.minute.toString().padLeft(2, '0')}',
    );
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability schedule updated successfully')),
        );
        _loadProviderData();
      } else {
        final errorMsg = result['error']?['message'] ?? 'Failed to update availability';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _availableStartTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _availableStartTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _availableEndTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _availableEndTime = picked;
      });
    }
  }

  Future<void> _savePriceRange() async {
    final minPrice = _minPriceController.text.trim();
    final maxPrice = _maxPriceController.text.trim();
    
    if (minPrice.isEmpty && maxPrice.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one price value'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    double? minPriceValue;
    double? maxPriceValue;
    
    if (minPrice.isNotEmpty) {
      minPriceValue = double.tryParse(minPrice);
      if (minPriceValue == null || minPriceValue < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid minimum price'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }
    
    if (maxPrice.isNotEmpty) {
      maxPriceValue = double.tryParse(maxPrice);
      if (maxPriceValue == null || maxPriceValue < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid maximum price'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }
    
    if (minPriceValue != null && maxPriceValue != null && minPriceValue > maxPriceValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum price cannot be greater than maximum price'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    final result = await ApiService.updateProviderPriceRange(
      minPrice: minPriceValue,
      maxPrice: maxPriceValue,
    );
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Price range updated successfully')),
        );
        _loadProviderData();
      } else {
        final errorMsg = result['error']?['message'] ?? 'Failed to update price range';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(title: 'Provider Settings'),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _loadProviderData(forceRefresh: true),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 16 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Business info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Iconsax.building, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Business information',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: context.foregroundColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _businessNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Business name',
                                    labelStyle: TextStyle(color: context.mutedForegroundColor),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Iconsax.building_4),
                                  ),
                                  style: TextStyle(color: context.foregroundColor),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _addressController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Business address',
                                    labelStyle: TextStyle(color: context.mutedForegroundColor),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Iconsax.location),
                                  ),
                                  style: TextStyle(color: context.foregroundColor),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _contactController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Business contact number',
                                    labelStyle: TextStyle(color: context.mutedForegroundColor),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Iconsax.call),
                                  ),
                                  style: TextStyle(color: context.foregroundColor),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _savingProfile ? null : _saveBusinessInfo,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _savingProfile
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                          )
                                        : const Text('Save business info'),
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: 50.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 16),
                          // Profile photo (business)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Iconsax.gallery, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Business profile photo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: context.foregroundColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _savingPhoto ? null : _changeProfilePhoto,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          ProviderAvatar(
                                            imageUrl: _fullMediaUrl(_providerData?['profile_photo']?.toString()),
                                            size: 80,
                                          ),
                                          if (_savingPhoto)
                                            Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                borderRadius: BorderRadius.circular(40),
                                              ),
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tap photo to change',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: context.mutedForegroundColor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          OutlinedButton.icon(
                                            onPressed: _savingPhoto ? null : _changeProfilePhoto,
                                            icon: const Icon(Iconsax.gallery, size: 18),
                                            label: const Text('Change photo'),
                                            style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ).animate(delay: 75.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 16),
                          // Availability Schedule
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Iconsax.calendar, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Availability Schedule',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: context.foregroundColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Day Range
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String?>(
                                        value: _availableFromDay,
                                        decoration: InputDecoration(
                                          labelText: 'From Day',
                                          labelStyle: TextStyle(color: context.mutedForegroundColor),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: context.borderColor),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: context.borderColor),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          isDense: true,
                                        ),
                                        items: _days.map((day) {
                                          return DropdownMenuItem<String?>(
                                            value: day['value'],
                                            child: Text(day['label']!),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _availableFromDay = value;
                                          });
                                        },
                                        style: TextStyle(color: context.foregroundColor),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<String?>(
                                        value: _availableToDay,
                                        decoration: InputDecoration(
                                          labelText: 'To Day',
                                          labelStyle: TextStyle(color: context.mutedForegroundColor),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: context.borderColor),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: context.borderColor),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          isDense: true,
                                        ),
                                        items: _days.map((day) {
                                          return DropdownMenuItem<String?>(
                                            value: day['value'],
                                            child: Text(day['label']!),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _availableToDay = value;
                                          });
                                        },
                                        style: TextStyle(color: context.foregroundColor),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Time Range
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: _selectStartTime,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: context.borderColor),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Iconsax.clock, color: context.mutedForegroundColor, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Start Time',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: context.mutedForegroundColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _availableStartTime != null
                                                          ? _availableStartTime!.format(context)
                                                          : 'Select time',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: context.foregroundColor,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: _selectEndTime,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: context.borderColor),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Iconsax.clock, color: context.mutedForegroundColor, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'End Time',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: context.mutedForegroundColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _availableEndTime != null
                                                          ? _availableEndTime!.format(context)
                                                          : 'Select time',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: context.foregroundColor,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Save Availability Button
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _isSaving ? null : _saveAvailability,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Save Availability Schedule'),
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: 100.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                          
                          const SizedBox(height: 16),
                          
                          // Price Range
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Iconsax.dollar_circle, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Price Range',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: context.foregroundColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _minPriceController,
                                        decoration: InputDecoration(
                                          labelText: 'Min Price (₹)',
                                          prefixIcon: const Icon(Iconsax.dollar_circle),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _maxPriceController,
                                        decoration: InputDecoration(
                                          labelText: 'Max Price (₹)',
                                          prefixIcon: const Icon(Iconsax.dollar_circle),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _isSaving ? null : _savePriceRange,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Save Price Range'),
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: 200.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                          
                          const SizedBox(height: 16),
                          
                          // Service categories (from onboarding)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Iconsax.category_2, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Service categories',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: context.foregroundColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Categories you offer (add, remove, or edit)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.mutedForegroundColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_currentServiceIds.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'No categories yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.mutedForegroundColor,
                                      ),
                                    ),
                                  )
                                else
                                  ...(_providerData?['services'] as List? ?? []).map<Widget>((s) {
                                    final cat = s is Map ? s['service_category'] : null;
                                    final id = cat?['id'] as int?;
                                    final name = cat?['name']?.toString() ?? 'Category';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: context.backgroundColor,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: context.borderColor),
                                              ),
                                              child: Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: context.foregroundColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: id != null && !_savingServices
                                                ? () => _removeCategory(id)
                                                : null,
                                            icon: Icon(Iconsax.trash, color: AppColors.error, size: 20),
                                            tooltip: 'Remove',
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _savingServices ? null : _openCategorySelector,
                                    icon: _savingServices
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Iconsax.add, size: 20),
                                    label: Text(_savingServices ? 'Saving...' : 'Add / Edit categories'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: 250.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                          
                          const SizedBox(height: 16),
                          
                          // Documents Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Iconsax.document_text, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Verification Documents',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: context.foregroundColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap to view document.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.mutedForegroundColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Profile Photo (view only - change is above)
                                if (_providerData?['profile_photo'] != null)
                                  _buildDocumentRow(
                                    context,
                                    'Profile Photo',
                                    _providerData!['profile_photo'],
                                    Iconsax.user,
                                    onView: () => _viewDocument(_providerData!['profile_photo']),
                                    onChange: null,
                                  ),
                                
                                // PAN Card
                                const SizedBox(height: 12),
                                _buildDocumentRow(
                                  context,
                                  'PAN Card',
                                  _providerData?['pan_card'],
                                  Iconsax.card,
                                  onView: _providerData?['pan_card'] != null
                                      ? () => _viewDocument(_providerData!['pan_card'])
                                      : null,
                                  onChange: null,
                                ),
                                
                                // Registration Certificate
                                const SizedBox(height: 12),
                                _buildDocumentRow(
                                  context,
                                  'Registration Certificate',
                                  _providerData?['registration_certificate'],
                                  Iconsax.document,
                                  onView: _providerData?['registration_certificate'] != null
                                      ? () => _viewDocument(_providerData!['registration_certificate'])
                                      : null,
                                  onChange: null,
                                ),
                                
                                // Verification Status
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getVerificationStatusColor().withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getVerificationStatusColor().withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getVerificationStatusIcon(),
                                        color: _getVerificationStatusColor(),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Verification Status',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.mutedForegroundColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _getVerificationStatusText(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _getVerificationStatusColor(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: 300.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                          
                          const SizedBox(height: 16),
                          
                          // Reviews Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Iconsax.star, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Text(
                                      'My Reviews',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: context.foregroundColor,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_reviews.length}',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                if (_reviews.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 24),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Iconsax.star,
                                            size: 48,
                                            color: context.mutedForegroundColor.withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No reviews yet',
                                            style: TextStyle(
                                              color: context.mutedForegroundColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ..._reviews.map((review) {
                                    final rating = review['rating'] as int? ?? 0;
                                    final comment = review['comment']?.toString() ?? '';
                                    final customerName = review['customer_name']?.toString() ?? 'Anonymous';
                                    final serviceName = review['service_category']?['name']?.toString() ?? 
                                                       review['service_name']?.toString() ?? '';
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: context.backgroundColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: context.borderColor.withOpacity(0.5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  customerName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: context.foregroundColor,
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (index) => Icon(
                                                    index < rating ? Iconsax.star1 : Iconsax.star,
                                                    color: index < rating ? Colors.amber : context.mutedForegroundColor,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (serviceName.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Service: $serviceName',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.mutedForegroundColor,
                                              ),
                                            ),
                                          ],
                                          if (comment.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              comment,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: context.foregroundColor,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              ],
                            ),
                          ).animate(delay: 400.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                        ],
                      ),
                    ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDocumentRow(
    BuildContext context,
    String label,
    String? url,
    IconData icon, {
    VoidCallback? onView,
    VoidCallback? onChange,
    bool saving = false,
  }) {
    final hasDocument = url != null && url.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasDocument ? AppColors.success.withOpacity(0.1) : context.mutedColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: hasDocument ? AppColors.success : context.mutedForegroundColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onView,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDocument ? 'Tap to view • Uploaded' : 'Not uploaded',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasDocument ? AppColors.success : context.mutedForegroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasDocument && onView != null)
            IconButton(
              onPressed: saving ? null : onView,
              icon: const Icon(Iconsax.eye, size: 20),
              tooltip: 'View',
            ),
          if (onChange != null)
            TextButton(
              onPressed: saving ? null : onChange,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change'),
            ),
          if (hasDocument && onView == null && onChange == null)
            Icon(
              Iconsax.tick_circle,
              color: AppColors.success,
              size: 20,
            ),
        ],
      ),
    );
  }
  
  Color _getVerificationStatusColor() {
    final status = _providerData?['verification_status'] ?? 'pending';
    switch (status) {
      case 'verified':
      case 'approved': // Backend uses 'approved', frontend may use 'verified'
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }
  
  IconData _getVerificationStatusIcon() {
    final status = _providerData?['verification_status'] ?? 'pending';
    switch (status) {
      case 'verified':
      case 'approved': // Backend uses 'approved', frontend may use 'verified'
        return Iconsax.tick_circle;
      case 'rejected':
        return Iconsax.close_circle;
      case 'pending':
      default:
        return Iconsax.clock;
    }
  }
  
  String _getVerificationStatusText() {
    final status = _providerData?['verification_status'] ?? 'pending';
    switch (status) {
      case 'verified':
      case 'approved': // Backend uses 'approved', frontend may use 'verified'
        return 'Verified ✓';
      case 'rejected':
        return 'Rejected - Please contact support';
      case 'pending':
      default:
        return 'Pending Review';
    }
  }
}

