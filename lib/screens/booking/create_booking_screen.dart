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
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime? _selectedDate;
  bool _isSubmitting = false;
  List<dynamic> _savedAddresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _useSavedAddress = false;
  bool _isLoadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
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
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final shouldAdd = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('No Saved Address'),
                  content: const Text('You need to save an address before booking. Would you like to add one now?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('Add Address'),
                    ),
                  ],
                ),
              );
              
              if (shouldAdd == true && mounted) {
                final result = await context.push('/add-address');
                // Reload addresses after adding
                if (result == true && mounted) {
                  _loadSavedAddresses();
                } else if (mounted) {
                  context.pop(); // Go back if address not added
                }
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
              _selectedAddress = defaultAddress;
              _useSavedAddress = true;
              _addressController.text = defaultAddress['full_address'] ?? '';
            }
          } catch (e) {
            // No default address found
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

    final bookingData = {
      'provider_id': int.parse(widget.providerId),
      'service_category_id': int.parse(widget.serviceCategoryId!),
      'description': _descriptionController.text.trim(),
      'address': _addressController.text.trim(),
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
                      
                      // Saved Addresses Section
                      if (_savedAddresses.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _useSavedAddress,
                                    onChanged: (value) {
                                      setState(() {
                                        _useSavedAddress = value ?? false;
                                        if (_useSavedAddress && _selectedAddress != null) {
                                          _addressController.text = _selectedAddress!['full_address'] ?? '';
                                        } else {
                                          _addressController.clear();
                                        }
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Use saved address',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: context.foregroundColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_useSavedAddress) ...[
                                const SizedBox(height: 8),
                                DropdownButtonFormField<Map<String, dynamic>>(
                                  value: _selectedAddress,
                                  isExpanded: true,
                                  isDense: true,
                                  decoration: InputDecoration(
                                    labelText: 'Select Address',
                                    prefixIcon: const Icon(Iconsax.location),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  menuMaxHeight: 300,
                                  items: _savedAddresses.map((address) {
                                    final label = address['label'] ?? 'Address';
                                    final fullAddress = address['full_address'] ?? '';
                                    final isDefault = address['is_default'] == true;
                                    
                                    // Create a compact display text
                                    String displayText = label;
                                    if (isDefault) {
                                      displayText += ' (Default)';
                                    }
                                    displayText += '\n$fullAddress';
                                    
                                    return DropdownMenuItem<Map<String, dynamic>>(
                                      value: address,
                                      child: Text(
                                        displayText,
                                        style: TextStyle(
                                          fontWeight: isDefault ? FontWeight.w600 : FontWeight.normal,
                                          fontSize: 13,
                                          color: isDefault ? AppColors.primary : null,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (address) {
                                    setState(() {
                                      _selectedAddress = address;
                                      if (address != null) {
                                        _addressController.text = address['full_address'] ?? '';
                                      }
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ).animate(delay: 300.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                        const SizedBox(height: 16),
                      ],
                      
                      // Address field
                      TextFormField(
                        controller: _addressController,
                        enabled: !_useSavedAddress,
                        decoration: InputDecoration(
                          labelText: _useSavedAddress ? 'Service Address (from saved)' : 'Service Address',
                          hintText: 'Enter the address where service is needed',
                          prefixIcon: const Icon(Iconsax.location),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: _useSavedAddress,
                          fillColor: _useSavedAddress ? context.mutedColor.withOpacity(0.3) : null,
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the service address';
                          }
                          return null;
                        },
                      ).animate(delay: 350.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
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

