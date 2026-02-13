import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/app_header.dart';

class CreateBookingScreen extends StatefulWidget {
  final String providerId;
  final String? serviceCategoryId;
  final String? serviceName;
  
  const CreateBookingScreen({
    super.key,
    required this.providerId,
    this.serviceCategoryId,
    this.serviceName,
  });

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime? _selectedDate;
  bool _isSubmitting = false;
  List<dynamic> _savedAddresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingAddresses = true;
  bool _showAddressError = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    setState(() => _isLoadingAddresses = true);
    final result = await ApiService.getSavedAddresses(forceRefresh: false);
    if (mounted) {
      setState(() {
        _isLoadingAddresses = false;
        if (result['success'] == true) {
          _savedAddresses = result['data'] as List;
          // If no addresses saved, redirect to add address
          if (_savedAddresses.isEmpty) {
            final navigator = GoRouter.of(context);
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final shouldAdd = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('No Saved Address'),
                  content: const Text(
                    "You don't have any saved address. Add an address from Profile to continue with booking.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('Add Address'),
                    ),
                  ],
                ),
              );
              if (shouldAdd == true && mounted) {
                context.pop(); // Leave create-booking screen first
                navigator.go('/add-address'); // Navigate to Profile section Add Address page
              } else if (shouldAdd == false && mounted) {
                context.pop(); // Go back from booking screen
              }
            });
            return;
          }
          // Auto-select default address if available
          try {
            final defaultAddress = _savedAddresses.firstWhere(
              (addr) => addr['is_default'] == true,
            );
            if (defaultAddress != null) {
              _selectedAddress = defaultAddress as Map<String, dynamic>;
            }
          } catch (e) {
            // No default address found; select first
            if (_savedAddresses.isNotEmpty) {
              _selectedAddress = _savedAddresses.first as Map<String, dynamic>;
            }
          }
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    // Validate required fields
    if (widget.serviceCategoryId == null || widget.serviceCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service category is required'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }
    if (_selectedAddress == null || _selectedAddress!['id'] == null) {
      setState(() {
        _isSubmitting = false;
        _showAddressError = true;
      });
      return;
    }
    setState(() => _showAddressError = false);

    final bookingData = {
      'provider_id': int.parse(widget.providerId),
      'service_category_id': int.parse(widget.serviceCategoryId!),
      'description': _descriptionController.text.trim(),
      'saved_address_id': _selectedAddress!['id'] as int,
      'scheduled_date': _selectedDate != null
          ? _selectedDate!.toIso8601String()
          : null,
      'price': _priceController.text.trim().isNotEmpty
          ? double.tryParse(_priceController.text.trim())
          : null,
    };

    final result = await ApiService.createBooking(bookingData);

    if (mounted) {
      setState(() => _isSubmitting = false);
      
      if (result['success'] == true) {
        context.push('/booking-success');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?['message'] ?? 'Failed to create booking',
            ),
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
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book Service',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.foregroundColor,
                        ),
                      ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 8),
                      
                      if (widget.serviceName != null)
                        Text(
                          'Service: ${widget.serviceName}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ).animate(delay: 100.ms).fadeIn(duration: 500.ms),
                      
                      const SizedBox(height: 24),
                      
                      // Description field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Service Description',
                          hintText: 'Describe what service you need...',
                          prefixIcon: const Icon(Iconsax.document_text),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe the service you need';
                          }
                          return null;
                        },
                      ).animate(delay: 200.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      // Service address: selectable saved-address cards
                      if (_savedAddresses.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          key: const ValueKey('service_address_section'),
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Iconsax.location,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Service address',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: context.foregroundColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Where should we provide the service?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: context.mutedForegroundColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(_savedAddresses.length, (index) {
                              final address = _savedAddresses[index] as Map<String, dynamic>;
                              final label = address['label'] ?? 'Address';
                              final fullAddress = address['full_address'] ?? '';
                              final isDefault = address['is_default'] == true;
                              final isSelected = _selectedAddress?['id'] == address['id'];
                              return Padding(
                                padding: EdgeInsets.only(
                                    bottom: index < _savedAddresses.length - 1 ? 10 : 0),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedAddress = address;
                                        _showAddressError = false;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withOpacity(0.08)
                                            : context.cardColor,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : context.borderColor,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary.withOpacity(0.15),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.primary.withOpacity(0.2)
                                                  : context.mutedColor,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              isDefault
                                                  ? Iconsax.home_2
                                                  : Iconsax.building_4,
                                              size: 20,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : context.mutedForegroundColor,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      label,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                        color: context.foregroundColor,
                                                      ),
                                                    ),
                                                    if (isDefault) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primary
                                                              .withOpacity(0.15),
                                                          borderRadius:
                                                              BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          'Default',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors.primary,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  fullAddress,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        context.mutedForegroundColor,
                                                    height: 1.35,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            isSelected
                                                ? Iconsax.tick_circle5
                                                : Icons.radio_button_unchecked,
                                            size: 24,
                                            color: isSelected
                                                ? AppColors.primary
                                                : context.borderColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (_showAddressError) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Iconsax.info_circle,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Please select a saved address',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ).animate(delay: 300.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      // Scheduled date picker
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.borderColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Iconsax.calendar, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Scheduled Date & Time',
                                      style: TextStyle(
                                        color: context.mutedForegroundColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedDate != null
                                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} at ${_selectedDate!.hour}:${_selectedDate!.minute.toString().padLeft(2, '0')}'
                                          : 'Select date and time (optional)',
                                      style: TextStyle(
                                        color: _selectedDate != null
                                            ? context.foregroundColor
                                            : context.mutedForegroundColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Iconsax.arrow_right_3,
                                color: context.mutedForegroundColor,
                              ),
                            ],
                          ),
                        ),
                      ).animate(delay: 400.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      // Price field (optional)
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Expected Price (Optional)',
                          hintText: 'Enter expected price in Rs.',
                          prefixIcon: const Icon(Iconsax.card),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (double.tryParse(value.trim()) == null) {
                              return 'Please enter a valid price';
                            }
                          }
                          return null;
                        },
                      ).animate(delay: 500.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 32),
                      
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Book Service',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ).animate(delay: 600.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
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
}

