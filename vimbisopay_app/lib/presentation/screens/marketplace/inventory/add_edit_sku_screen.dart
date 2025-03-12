import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

/// A screen for adding or editing a SKU (internal account) in the marketplace.
///
/// This screen allows vendors to create new SKUs or edit existing ones,
/// including setting metadata like name, description, price, etc.
class AddEditSkuScreen extends StatefulWidget {
  /// The ID of the vendor adding/editing the SKU.
  final String vendorId;

  /// The ID of the SKU to edit, or null if adding a new SKU.
  final String? skuId;

  /// Creates a new [AddEditSkuScreen] instance.
  const AddEditSkuScreen({
    super.key,
    required this.vendorId,
    this.skuId,
  });

  @override
  State<AddEditSkuScreen> createState() => _AddEditSkuScreenState();
}

class _AddEditSkuScreenState extends State<AddEditSkuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _initialInventoryController = TextEditingController();

  String _currency = 'USD';
  bool _isAvailable = true;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _errorMessage;
  
  // Image picker
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _existingImageUrl;
  bool _isImageLoading = false;

  final List<String> _currencies = ['USD', 'EUR', 'GBP'];
  final List<String> _categories = [
    'Electronics',
    'Clothing',
    'Food',
    'Home',
    'Beauty',
    'Sports',
    'Toys',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.skuId != null;
    if (_isEditing) {
      _loadSkuData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _initialInventoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isImageLoading = true;
      });
      
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _existingImageUrl = null; // Clear existing image URL if a new image is selected
        });
      }
      
      setState(() {
        _isImageLoading = false;
      });
    } catch (e) {
      setState(() {
        _isImageLoading = false;
        _errorMessage = 'Failed to pick image: $e';
      });
      Logger.error('Failed to pick image', e);
    }
  }
  
  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _existingImageUrl = null;
    });
  }

  Future<void> _loadSkuData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.skuId == null) {
        throw Exception('SKU ID is null');
      }

      // Fetch the product data from the repository
      final result = await _marketplaceRepository.getProduct(widget.skuId!);
      
      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load SKU data';
          });
        },
        (product) {
          setState(() {
            _nameController.text = product.name;
            _descriptionController.text = product.description;
            _priceController.text = (product.price / 100).toString(); // Convert from cents to dollars
            _categoryController.text = product.category;
            _tagsController.text = product.tags.join(', ');
            _initialInventoryController.text = product.inventory?.toString() ?? '0';
            _currency = product.currency;
            _isAvailable = product.isAvailable;
            
            // Load image URL if available
            if (product.imageUrls.isNotEmpty && product.imageUrls[0] != 'https://example.com/product_placeholder.jpg') {
              _existingImageUrl = product.imageUrls[0];
            }
            
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load SKU data: $e';
      });
    }
  }

  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;

  Future<void> _saveSku() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Parse form values
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final price = (double.parse(_priceController.text) * 100).round(); // Convert to cents
      final category = _categoryController.text.trim();
      final tags = _tagsController.text.split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      final initialInventory = int.tryParse(_initialInventoryController.text) ?? 0;

      // Handle image paths
      List<String> imageUrls = [];
      
      if (_selectedImage != null) {
        // Store the local file path with a file:// prefix
        final localPath = 'file://${_selectedImage!.path}';
        imageUrls.add(localPath);
        
        // Log the image path for debugging
        Logger.data('Selected image path: $localPath');
      } else if (_existingImageUrl != null) {
        // Keep the existing image URL or path
        imageUrls.add(_existingImageUrl!);
      } else {
        // Use a placeholder image URL
        imageUrls.add('https://example.com/product_placeholder.jpg');
      }

      if (_isEditing && widget.skuId != null) {
        // Update existing product
        final result = await _marketplaceRepository.updateProduct(
          id: widget.skuId!,
          name: name,
          description: description,
          price: price,
          currency: _currency,
          imageUrls: imageUrls,
          category: category,
          tags: tags,
          isAvailable: _isAvailable,
          inventory: initialInventory,
        );

        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = failure.message ?? 'Failed to update SKU';
              });
            }
          },
          (product) {
            if (mounted) {
              // First pop the context, then let the parent handle the success message
              Navigator.pop(context, {'success': true, 'message': 'SKU updated successfully'});
            }
          },
        );
      } else {
        // Create new product
        final result = await _marketplaceRepository.createProduct(
          vendorId: widget.vendorId,
          name: name,
          description: description,
          price: price,
          currency: _currency,
          imageUrls: imageUrls,
          category: category,
          tags: tags,
          isAvailable: _isAvailable,
          inventory: initialInventory,
        );

        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = failure.message ?? 'Failed to create SKU';
              });
            }
          },
          (product) {
            if (mounted) {
              // First pop the context, then let the parent handle the success message
              Navigator.pop(context, {'success': true, 'message': 'SKU created successfully'});
            }
          },
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save SKU: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit SKU' : 'Add New SKU'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: AppColors.errorRed),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.errorRed),
              ),
            ),
            const SizedBox(height: 16.0),
          ],
          _buildBasicInfoSection(),
          const SizedBox(height: 24.0),
          _buildImageSection(),
          const SizedBox(height: 24.0),
          _buildPricingSection(),
          const SizedBox(height: 24.0),
          _buildCategorySection(),
          const SizedBox(height: 24.0),
          _buildInventorySection(),
          const SizedBox(height: 32.0),
          FilledButton(
            onPressed: _saveSku,
            child: Text(_isEditing ? 'Update SKU' : 'Create SKU'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Image',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            Center(
              child: _isImageLoading
                  ? const CircularProgressIndicator()
                  : _buildImagePreview(),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Select Image'),
                ),
                const SizedBox(width: 16.0),
                if (_selectedImage != null || _existingImageUrl != null)
                  OutlinedButton.icon(
                    onPressed: _removeImage,
                    icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                    label: const Text('Remove', style: TextStyle(color: AppColors.errorRed)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.errorRed),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Add an image of your product to make it more appealing to customers. (Optional)',
              style: TextStyle(
                fontSize: 12.0,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      // Show selected image from device
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.file(
          _selectedImage!,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    } else if (_existingImageUrl != null) {
      if (_existingImageUrl!.startsWith('file://')) {
        // Show existing image from local file
        final filePath = _existingImageUrl!.substring(7); // Remove 'file://' prefix
        return ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.file(
            File(filePath),
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              Logger.error('Error loading local image: $filePath', error);
              return Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.error, size: 50, color: AppColors.errorRed),
                ),
              );
            },
          ),
        );
      } else {
        // Show existing image from remote URL
        return ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: CachedNetworkImage(
            imageUrl: _existingImageUrl!,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Icon(Icons.error, size: 50, color: AppColors.errorRed),
            ),
          ),
        );
      }
    } else {
      // Show placeholder
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image,
                size: 50,
                color: Colors.grey,
              ),
              SizedBox(height: 8),
              Text(
                'No image selected',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'SKU Name',
                hintText: 'Enter the name of your product',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter a detailed description of your product',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pricing',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      hintText: 'Enter the price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a price';
                      }
                      try {
                        final price = double.parse(value);
                        if (price <= 0) {
                          return 'Price must be greater than zero';
                        }
                      } catch (e) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                    items: _currencies.map((currency) {
                      return DropdownMenuItem<String>(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _currency = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            SwitchListTile(
              title: const Text('Available for Sale'),
              subtitle: const Text('Toggle to make this SKU available or unavailable'),
              value: _isAvailable,
              onChanged: (value) {
                setState(() {
                  _isAvailable = value;
                });
              },
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Categorization',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'Select a category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _categoryController.text = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Enter tags separated by commas',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                // Tags are optional
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _initialInventoryController,
              decoration: const InputDecoration(
                labelText: 'Initial Inventory',
                hintText: 'Enter the initial inventory quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an inventory quantity';
                }
                try {
                  final inventory = int.parse(value);
                  if (inventory < 0) {
                    return 'Inventory cannot be negative';
                  }
                } catch (e) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Note: This will create an internal account for tracking this SKU\'s inventory.',
              style: TextStyle(
                fontSize: 12.0,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
