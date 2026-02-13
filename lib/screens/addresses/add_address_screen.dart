import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/app_header.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();
  final _labelController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  bool _isDefault = false;
  bool _isSubmitting = false;
  bool _isLoadingLocation = false;
  LatLng? _selectedLocation; // null until user allows location or taps map

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _labelController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          _selectedLocation ??= const LatLng(18.5204, 73.8567);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Tap the map to set position.')),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _selectedLocation ??= const LatLng(18.5204, 73.8567);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied. Tap the map to set position.')),
          );
        }
        return;
      }
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        _mapController.move(_selectedLocation!, 14.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _selectedLocation ??= const LatLng(18.5204, 73.8567);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng location) {
    setState(() => _selectedLocation = location);
  }

  Future<void> _submitAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final addressData = {
      'label': _labelController.text.trim(),
      'address_line1': _addressLine1Controller.text.trim(),
      'address_line2': _addressLine2Controller.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'postal_code': _postalCodeController.text.trim(),
      'country': _countryController.text.trim(),
      'is_default': _isDefault,
      if (_selectedLocation != null) ...{
        'latitude': double.parse(_selectedLocation!.latitude.toStringAsFixed(6)),
        'longitude': double.parse(_selectedLocation!.longitude.toStringAsFixed(6)),
      },
    };

    final result = await ApiService.createSavedAddress(addressData);

    if (mounted) {
      setState(() => _isSubmitting = false);
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address saved successfully')),
        );
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/addresses');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?['message'] ?? 'Failed to save address',
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
        bottom: false,
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
                        'Add New Address',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.foregroundColor,
                        ),
                      ).animate().fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 24),
                      
                      TextFormField(
                        controller: _labelController,
                        decoration: InputDecoration(
                          labelText: 'Label',
                          hintText: 'e.g., Home, Office',
                          prefixIcon: const Icon(Iconsax.tag),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a label';
                          }
                          return null;
                        },
                      ).animate(delay: 100.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _addressLine1Controller,
                        decoration: InputDecoration(
                          labelText: 'Address Line 1',
                          hintText: 'Street address, building name',
                          prefixIcon: const Icon(Iconsax.location),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter address line 1';
                          }
                          return null;
                        },
                      ).animate(delay: 200.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _addressLine2Controller,
                        decoration: InputDecoration(
                          labelText: 'Address Line 2 (Optional)',
                          hintText: 'Apartment, suite, etc.',
                          prefixIcon: const Icon(Iconsax.building),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                      ).animate(delay: 300.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                labelText: 'City',
                                prefixIcon: const Icon(Iconsax.buildings),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: InputDecoration(
                                labelText: 'State',
                                prefixIcon: const Icon(Iconsax.map),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ).animate(delay: 400.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _postalCodeController,
                              decoration: InputDecoration(
                                labelText: 'Postal Code',
                                prefixIcon: const Icon(Iconsax.code),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _countryController,
                              decoration: InputDecoration(
                                labelText: 'Country',
                                prefixIcon: const Icon(Iconsax.global),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ).animate(delay: 500.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 20),
                      Text(
                        'Location (tap map to set)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.foregroundColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your position is used for the address. Tap the map to adjust the pin.',
                        style: TextStyle(
                          color: context.mutedForegroundColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _selectedLocation ?? const LatLng(18.5204, 73.8567),
                                  initialZoom: 14.0,
                                  onTap: _onMapTap,
                                  minZoom: 3.0,
                                  maxZoom: 18.0,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.suvidha.connect',
                                  ),
                                  if (_selectedLocation != null)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: _selectedLocation!,
                                          width: 44,
                                          height: 44,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.25),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(Iconsax.location, color: Colors.white, size: 22),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Material(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: _isLoadingLocation ? null : _getCurrentLocation,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: _isLoadingLocation
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(Iconsax.gps, color: Colors.white, size: 22),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate(delay: 550.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      if (_selectedLocation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Lat: ${_selectedLocation!.latitude.toStringAsFixed(5)}, Lon: ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.mutedForegroundColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      
                      CheckboxListTile(
                        value: _isDefault,
                        onChanged: (value) {
                          setState(() {
                            _isDefault = value ?? false;
                          });
                        },
                        title: Text(
                          'Set as default address',
                          style: TextStyle(color: context.foregroundColor),
                        ),
                        subtitle: Text(
                          'This address will be used by default for bookings',
                          style: TextStyle(color: context.mutedForegroundColor),
                        ),
                        activeColor: AppColors.primary,
                      ).animate(delay: 600.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                      
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitAddress,
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
                                  'Save Address',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ).animate(delay: 700.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
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

