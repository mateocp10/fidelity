// lib/features/business/widgets/location_picker_map.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class LocationPickerMap extends StatefulWidget {
  final Function(double latitude, double longitude, String address)
  onLocationSelected;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const LocationPickerMap({
    super.key,
    required this.onLocationSelected,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  String _address = '';
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      setState(() {
        _selectedLocation = LatLng(
          widget.initialLatitude!,
          widget.initialLongitude!,
        );
        _address = widget.initialAddress ?? '';
        _searchController.text = _address;
      });
    } else {
      // Ubicación por defecto (Quito) sin pedir permisos
      final defaultLocation = const LatLng(-0.1807, -78.4678);
      setState(() {
        _selectedLocation = defaultLocation;
        _address = 'Quito, Ecuador';
        _searchController.text = _address;
      });
      // Importante: No llamamos a _getCurrentLocation() aquí para no asustar al usuario.
      // Se llamará solo cuando presione "UBICARME".
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          final turnOn = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('GPS Desactivado'),
              content: const Text('Para poder ubicarte automáticamente, necesitas encender el GPS. ¿Deseas abrir la configuración?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  child: const Text('Configuración'),
                ),
              ],
            ),
          );

          if (turnOn == true) {
            await Geolocator.openLocationSettings();
            // Esperar un momento a que el usuario active y regrese
            await Future.delayed(const Duration(seconds: 3));
            serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
               throw Exception('El GPS sigue desactivado');
            }
          } else {
             throw Exception('Servicios de ubicación desactivados por el usuario');
          }
        } else {
          throw Exception('Servicios de ubicación desactivados');
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Los permisos de ubicación fueron denegados permanentemente en el sistema. Debes habilitarlos en la configuración de la app.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = newLocation;
      });

      _mapController.move(newLocation, 15.0);
      await _updateAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAddressFromCoordinates(double lat, double lon) async {
    setState(() => _isLoading = true);
    String? newAddress;

    try {
      // Intento 1: Geocoding Nativo
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String> parts = [];
        if (place.street?.isNotEmpty ?? false) parts.add(place.street!);
        if (place.subLocality?.isNotEmpty ?? false) {
          parts.add(place.subLocality!);
        } else if (place.locality?.isNotEmpty ?? false) {
          parts.add(place.locality!);
        }
        if (place.subAdministrativeArea?.isNotEmpty ?? false) {
          parts.add(place.subAdministrativeArea!);
        }
        
        if (parts.isNotEmpty) {
          newAddress = parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('Error geocoding nativo: $e');
    }

    // Intento 2: Nominatim (OpenStreetMap) de respaldo si el nativo falla o es incompleto
    if (newAddress == null || newAddress.length < 5) {
      try {
        
        
        final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
        final response = await http.get(uri, headers: {
          'User-Agent': 'FidelityApp/1.0 (fidelitysistemadefidelizacion@gmail.com)',
          'Accept-Language': 'es-ES,es;q=0.9',
        });
        
        if (response.statusCode == 200) {
          final content = utf8.decode(response.bodyBytes);
          final data = json.decode(content);
          
          final addressData = data['address'];
          if (addressData != null) {
            final road = addressData['road'] ?? addressData['pedestrian'] ?? '';
            final neighborhood = addressData['neighborhood'] ?? addressData['suburb'] ?? addressData['residential'] ?? '';
            final city = addressData['city'] ?? addressData['town'] ?? addressData['village'] ?? '';
            
            final parts = [road, neighborhood, city].where((s) => s.toString().isNotEmpty).toList();
            if (parts.isNotEmpty) {
              newAddress = parts.join(', ');
            } else {
              newAddress = data['display_name'];
            }
          } else {
            newAddress = data['display_name'];
          }
          
          // Limpiar si es demasiado largo
          if (newAddress != null && newAddress.length > 100) {
            newAddress = newAddress.split(',').take(3).join(', ').trim();
          }
        }
      } catch (e) {
        debugPrint('Error geocoding Nominatim: $e');
      }
    }

    setState(() {
      _address = newAddress ?? 'Ubicación: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
      _searchController.text = _address;
      _isLoading = false;
    });

    widget.onLocationSelected(lat, lon, _address);
  }

  Future<Iterable<Map<String, dynamic>>> _getSuggestions(String query) async {
    if (query.length < 3) return const Iterable.empty();

    final completer = Completer<Iterable<Map<String, dynamic>>>();

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        
        
        final uri = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&addressdetails=1&countrycodes=ec&limit=5');
        final response = await http.get(uri, headers: {
          'User-Agent': 'FidelityApp/1.0',
        });
        
        if (response.statusCode == 200) {
          final content = utf8.decode(response.bodyBytes);
          final List data = json.decode(content);
          completer.complete(data.cast<Map<String, dynamic>>());
        } else {
          completer.complete(const Iterable.empty());
        }
      } catch (e) {
        completer.complete(const Iterable.empty());
      }
    });

    return completer.future;
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    LatLng? newLocation;
    String? newAddress;

    try {
      // Intento 1: Geocoding Nativo
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        newLocation = LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint('Error búsqueda nativa: $e');
    }

    // Intento 2: Nominatim Search de respaldo
    if (newLocation == null) {
      try {
        
        
        final uri = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=1&addressdetails=1');
        final response = await http.get(uri, headers: {
          'User-Agent': 'FidelityApp/1.0',
        });
        
        if (response.statusCode == 200) {
          final content = utf8.decode(response.bodyBytes);
          final data = json.decode(content);
          if (data is List && data.isNotEmpty) {
            final firstMatch = data[0];
            newLocation = LatLng(
              double.parse(firstMatch['lat']),
              double.parse(firstMatch['lon']),
            );
            
            final addressData = firstMatch['address'];
            if (addressData != null) {
              final road = addressData['road'] ?? addressData['pedestrian'] ?? '';
              final neighborhood = addressData['neighborhood'] ?? addressData['suburb'] ?? addressData['residential'] ?? '';
              final city = addressData['city'] ?? addressData['town'] ?? addressData['village'] ?? '';
              final parts = [road, neighborhood, city].where((s) => s.toString().isNotEmpty).toList();
              newAddress = parts.isNotEmpty ? parts.join(', ') : firstMatch['display_name'];
            } else {
              newAddress = firstMatch['display_name'];
            }
          }
        }
      } catch (e) {
        debugPrint('Error búsqueda Nominatim: $e');
      }
    }

    if (newLocation != null) {
      if (mounted) {
        setState(() {
          _selectedLocation = newLocation;
          _mapController.move(newLocation!, 15.0);
        });
      }
      
      if (newAddress != null) {
        if (mounted) {
          setState(() {
            _address = newAddress!;
            _searchController.text = _address;
          });
        }
        widget.onLocationSelected(newLocation.latitude, newLocation.longitude, _address);
      } else {
        await _updateAddressFromCoordinates(newLocation.latitude, newLocation.longitude);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la dirección')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onMapTapped(TapPosition tap, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    _updateAddressFromCoordinates(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: RawAutocomplete<Map<String, dynamic>>(
                    textEditingController: _searchController,
                    focusNode: _searchFocusNode,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      return _getSuggestions(textEditingValue.text);
                    },
                    displayStringForOption: (option) => option['display_name'] ?? '',
                    onSelected: (selection) {
                      final lat = double.tryParse(selection['lat'].toString()) ?? 0.0;
                      final lon = double.tryParse(selection['lon'].toString()) ?? 0.0;
                      final newLocation = LatLng(lat, lon);
                      
                      setState(() {
                        _selectedLocation = newLocation;
                        _address = selection['display_name'] ?? '';
                        _mapController.move(newLocation, 16.0);
                      });
                      
                      _searchFocusNode.unfocus();
                      widget.onLocationSelected(lat, lon, _address);
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Buscar ciudad, calle, local...',
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: Colors.black,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.04),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (value) {
                          onFieldSubmitted();
                          _searchAddress(value);
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          color: Colors.white,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                final address = option['address'] ?? {};
                                final road = address['road'] ?? address['pedestrian'] ?? '';
                                final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
                                final name = option['name'] ?? '';
                                
                                final title = name.isNotEmpty ? name : (road.isNotEmpty ? road : city);
                                
                                return ListTile(
                                  leading: const Icon(Icons.location_on_outlined, color: Colors.black54),
                                  title: Text(
                                    title.isNotEmpty ? title : 'Ubicación',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    option['display_name'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text(
                    'UBICARME',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          // Mapa
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _selectedLocation ?? const LatLng(-0.1807, -78.4678),
                    initialZoom: 15.0,
                    onTap: _onMapTapped,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.fidelity.app',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40.0,
                            height: 40.0,
                            point: _selectedLocation!,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.black,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Dirección seleccionada
          if (_address.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _address,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}



