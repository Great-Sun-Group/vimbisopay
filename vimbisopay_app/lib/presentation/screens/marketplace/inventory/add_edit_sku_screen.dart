import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';

/// A screen for adding or editing a Product Account in the marketplace.
///
/// This screen allows vendors to create new Product Accounts or edit existing ones,
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

  String _currency = 'USD';
  bool _isAvailable = true;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isUploadingImage = false;
  String? _errorMessage;
  String? _accountId;
  
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
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      
      if (source == null) return;
      
      setState(() {
        _isImageLoading = true;
      });
      
      // Use lower quality settings right from the start
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 400,  // Reduced from 800 to 400
        maxHeight: 400, // Reduced from 800 to 400
        imageQuality: 70, // Reduced from 85 to 70
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
  
  /// Compresses an image file to reduce its size.
  ///
  /// This method creates a temporary compressed copy of the image
  /// with reduced quality to ensure it's small enough for upload.
  Future<File> _compressImage(File imageFile) async {
    try {
      // Use Flutter's image_picker with lower quality settings
      final XFile? compressedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400, // Reduced from 600 to 400
        maxHeight: 400, // Reduced from 600 to 400
        imageQuality: 40, // Reduced from 50 to 40
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (compressedFile != null) {
        return File(compressedFile.path);
      } else {
        // If compression fails, use a manual approach to resize the image
        Logger.data('[ADD_EDIT_PRODUCT] Using manual approach to resize image');
        
        // For now, return the original file, but in a real app you would
        // implement a manual image resizing method here using packages like
        // flutter_image_compress or image
        return imageFile;
      }
    } catch (e) {
      // If compression fails, log the error and return the original file
      Logger.error('[ADD_EDIT_PRODUCT] Error compressing image', e);
      return imageFile;
    }
  }
  
  /// Compresses an image file with more aggressive settings.
  ///
  /// This method applies even more aggressive compression for images
  /// that are still too large after the first compression attempt.
  Future<File> _compressImageAggressively(File imageFile) async {
    try {
      // Use Flutter's image_picker with even lower quality settings
      final XFile? compressedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300, // Very small width
        maxHeight: 300, // Very small height
        imageQuality: 30, // Very low quality
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (compressedFile != null) {
        return File(compressedFile.path);
      } else {
        // If compression fails, return the original file
        return imageFile;
      }
    } catch (e) {
      // If compression fails, log the error and return the original file
      Logger.error('[ADD_EDIT_SKU] Error compressing image aggressively', e);
      return imageFile;
    }
  }

  Future<void> _loadSkuData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.skuId == null) {
        throw Exception('Product Account ID is null');
      }

      // Fetch the product data from the repository
      final result = await _marketplaceRepository.getProduct(widget.skuId!);
      
      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load Product Account data';
          });
        },
        (product) {
          setState(() {
            _nameController.text = product.name;
            _descriptionController.text = product.description;
            _priceController.text = (product.price / 100).toString(); // Convert from cents to dollars
            _categoryController.text = product.category;
            _tagsController.text = product.tags.join(', ');
            _accountId = product.accountId;
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
        _errorMessage = 'Failed to load Product Account data: $e';
      });
    }
  }

  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;

  Future<String?> _uploadImage(String accountId) async {
    if (_selectedImage == null) return _existingImageUrl;
    
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      // Log the original file size
      final fileSize = await _selectedImage!.length();
      final fileSizeKB = fileSize / 1024;
      Logger.data('[ADD_EDIT_SKU] Original image file size: ${fileSizeKB.toStringAsFixed(2)} KB');
      
      // Check if the image needs to be compressed - using 80KB as threshold
      File imageToUpload = _selectedImage!;
      if (fileSizeKB > 80) { // If larger than 80KB, compress the image
        Logger.data('[ADD_EDIT_SKU] Image is large (${fileSizeKB.toStringAsFixed(2)} KB), compressing before upload');
        imageToUpload = await _compressImage(_selectedImage!);
        final compressedSize = await imageToUpload.length();
        final compressedSizeKB = compressedSize / 1024;
        Logger.data('[ADD_EDIT_SKU] Compressed image size: ${compressedSizeKB.toStringAsFixed(2)} KB');
        
        // If still too large after compression, try again with more aggressive settings
        if (compressedSizeKB > 80) {
          Logger.data('[ADD_EDIT_SKU] Image still too large, applying more aggressive compression');
          imageToUpload = await _compressImageAggressively(_selectedImage!);
          final finalSize = await imageToUpload.length();
          final finalSizeKB = finalSize / 1024;
          Logger.data('[ADD_EDIT_SKU] Final image size after aggressive compression: ${finalSizeKB.toStringAsFixed(2)} KB');
          
          // If still too large, show an error
          if (finalSizeKB > 80) {
            throw Exception('Image is too large even after compression. Please select a smaller image.');
          }
        }
      }
      
      Logger.data('[ADD_EDIT_SKU] Uploading image to account: $accountId');
      final uploadResult = await _marketplaceRepository.uploadProfileImage(
        imagePath: imageToUpload.path,
        drAccountId: accountId,
      );
      
      return await uploadResult.fold(
        (failure) {
          throw Exception(failure.message ?? 'Failed to upload image');
        },
        (assetIds) async {
          // Get the user to find the member ID
          final user = await ServiceLocator.databaseHelper.getUser();
          if (user == null) {
            throw Exception('User not found');
          }
          
          // Update profile pictures
          final updateResult = await _marketplaceRepository.updateProfilePictures(
            sourceId: accountId,
            originalAssetId: assetIds['originalAssetID']!,
            thumbnailAssetId: assetIds['originalAssetID']!,
            asset200Id: assetIds['asset200ID']!,
            asset600Id: assetIds['asset600ID']!,
          );
          
          return await updateResult.fold(
            (failure) {
              throw Exception(failure.message ?? 'Failed to update profile pictures');
            },
            (success) {
              // Return the asset600ID as the image URL
              return assetIds['asset600ID'];
            },
          );
        },
      );
    } catch (e) {
      final errorMessage = e.toString();
      Logger.error('[ADD_EDIT_SKU] Error uploading image', e);
      
      // Provide more specific error message based on the error
      String userFriendlyMessage = 'Failed to upload image: $e';
      if (errorMessage.contains('413') || errorMessage.contains('request entity too large')) {
        userFriendlyMessage = 'The image file is too large. Please select a smaller image or try again with a lower resolution image.';
      } else if (errorMessage.contains('too large even after compression')) {
        userFriendlyMessage = 'The image is too large even after compression. Please select a smaller image with simpler content.';
      }
      
      setState(() {
        _errorMessage = userFriendlyMessage;
      });
      return null;
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _saveProductAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingDialog(
        message: 'Saving product...',
      ),
    );

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

      // Initialize image URLs
      List<String> imageUrls = [];
      if (_existingImageUrl != null) {
        imageUrls.add(_existingImageUrl!);
      }

      if (_isEditing && widget.skuId != null) {
        // For editing, we already have the account ID
        if (_selectedImage != null && _accountId != null) {
          // Upload the new image
          final imageUrl = await _uploadImage(_accountId!);
          if (imageUrl != null) {
            imageUrls = [imageUrl];
          }
        }
        
        // Update existing product TODO
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
          accountId: _accountId,
        );

        // Dismiss loading dialog
        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading dialog

        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _errorMessage = failure.message ?? 'Failed to update Product Account';
              });
            }
          },
          (product) {
            if (mounted) {
              // First pop the context, then let the parent handle the success message
              Navigator.pop(context, {'success': true, 'message': 'Product Account updated successfully'});
            }
          },
        );
      } else {
        // For new products, create an internal account first
        final accountResult = await _marketplaceRepository.createInternalAccount(
          accountName: name,
          defaultDenom: _currency,
          accountType: 'PHYSICAL_ASSET',
        );

        await accountResult.fold(
          (failure) {
            if (mounted) {
              // Dismiss loading dialog
              Navigator.pop(context); // Dismiss loading dialog
              
              setState(() {
                _errorMessage = failure.message ?? 'Failed to create internal account';
              });
            }
          },
          (accountId) async {
            // Create a Product object manually
            final now = DateTime.now();
            var product = Product(
              id: accountId, // Use account ID as product ID
              vendorId: widget.vendorId,
              name: name,
              description: description,
              price: price,
              currency: _currency,
              imageUrls: imageUrls.isEmpty ? ['https://example.com/product_placeholder.jpg'] : imageUrls,
              category: category,
              tags: tags,
              isAvailable: _isAvailable,
              accountId: accountId,
              createdAt: now,
              updatedAt: now,
            );
            
            // Handle image upload if needed
            if (_selectedImage != null) {
              // Update the loading dialog message
              if (mounted) {
                Navigator.pop(context); // Dismiss previous loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const LoadingDialog(
                    message: 'Uploading product image...',
                  ),
                );
              }
              
              // Upload the image using the account ID
              final imageUrl = await _uploadImage(accountId);
              
              if (imageUrl != null) {
                // Update the product's image URLs
                product = Product(
                  id: product.id,
                  vendorId: product.vendorId,
                  name: product.name,
                  description: product.description,
                  price: product.price,
                  currency: product.currency,
                  imageUrls: [imageUrl],
                  category: product.category,
                  tags: product.tags,
                  isAvailable: product.isAvailable,
                  accountId: product.accountId,
                  createdAt: product.createdAt,
                  updatedAt: product.updatedAt,
                );
                Logger.data('[ADD_EDIT_PRODUCT] Product updated with image URL: $imageUrl');
              }
            }
            
            // Dismiss loading dialog
            if (mounted) {
              Navigator.pop(context); // Dismiss loading dialog
              
              // Return success with the product
              Navigator.pop(context, {
                'success': true, 
                'message': 'Product Account created successfully',
                'product': {
                  'id': product.id,
                  'vendorId': product.vendorId,
                  'name': product.name,
                  'description': product.description,
                  'price': product.price,
                  'currency': product.currency,
                  'imageUrls': product.imageUrls,
                  'category': product.category,
                  'tags': product.tags,
                  'isAvailable': product.isAvailable,
                  'accountId': product.accountId,
                  'createdAt': product.createdAt.toIso8601String(),
                  'updatedAt': product.updatedAt.toIso8601String(),
                },
              });
            }
          },
        );
      }
    } catch (e) {
      // Dismiss loading dialog
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        
        setState(() {
          _errorMessage = 'Failed to save Product Account: $e';
        });
      }
      Logger.error('Error saving Product Account', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product Account' : 'Add Product Account'),
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
          const SizedBox(height: 32.0),
          FilledButton(
            onPressed: _saveProductAccount,
            child: Text(_isEditing ? 'Update Product Account' : 'Create Product Account'),
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
              child: _isImageLoading || _isUploadingImage
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
              'Add an image of your product to make it more appealing to customers. The image will be uploaded to the product\'s account. For best results, use small images under 80KB.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
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
                labelText: 'Product Name',
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
              subtitle: const Text('Toggle to make this Product Account available or unavailable'),
              value: _isAvailable,
              onChanged: (value) {
                setState(() {
                  _isAvailable = value;
                });
              },
              activeColor: AppColors.primary,
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Note: Creating a product will automatically create an internal account for tracking inventory using the accounting-based system.',
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
}
