import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../utils/constants.dart';
import '../../../../services/feedback_service.dart';

class FeedbackDialog {
  static void show(BuildContext context) {
    final feedbackController = TextEditingController();
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Send Feedback'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We\'d love to hear your thoughts!',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                _buildMessageInput(feedbackController),
                const SizedBox(height: 16),
                _buildImageSection(selectedImage, setState, (File? f) {
                  setState(() {
                    selectedImage = f;
                  });
                }),
                const SizedBox(height: 12),
                _buildImagePickerButtons(setState, (File? f) {
                  setState(() {
                    selectedImage = f;
                  });
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _handleSendFeedback(
                context,
                feedbackController.text.trim(),
                selectedImage,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildMessageInput(TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: 'Type your message here...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  static Widget _buildImageSection(File? selectedImage, StateSetter setState,
      ValueChanged<File?> onImageChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attach Image (Optional)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 12),
        if (selectedImage != null)
          _buildSelectedImage(selectedImage, setState, onImageChanged)
        else
          _buildPlaceholderImage(),
      ],
    );
  }

  static Widget _buildSelectedImage(File selectedImage, StateSetter setState,
      ValueChanged<File?> onImageChanged) {
    return Stack(
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: FileImage(selectedImage),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              // Inform parent to clear the captured variable and refresh UI
              onImageChanged(null);
              setState(() {});
            },
            child: Container(
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.red),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.primary.withOpacity(0.5),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          Icon(Icons.image_outlined, color: AppColors.primary, size: 32),
          SizedBox(height: 8),
          Text(
            'No image selected',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static Widget _buildImagePickerButtons(
      StateSetter setState, ValueChanged<File?> onImageChanged) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () async {
                final file = await _pickImage(ImageSource.gallery);
                onImageChanged(file);
                setState(() {});
              },
              icon: const Icon(Icons.photo_library),
              color: AppColors.primary,
              tooltip: 'Pick from gallery',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () async {
                final file = await _pickImage(ImageSource.camera);
                onImageChanged(file);
                setState(() {});
              },
              icon: const Icon(Icons.camera_alt),
              color: AppColors.primary,
              tooltip: 'Open camera',
            ),
          ),
        ),
      ],
    );
  }

  static Future<File?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  static Future<void> _handleSendFeedback(
    BuildContext context,
    String message,
    File? selectedImage,
  ) async {
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your feedback'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context); // Close feedback dialog

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      print('About to send email...');
      await FeedbackService.sendFeedback(
          message: message, imageFile: selectedImage);
      print('Email sent successfully');
    } catch (e) {
      print('Error occurred: $e');
    }

    // Wait 1 second then close loading dialog
    await Future.delayed(const Duration(seconds: 1));

    if (context.mounted) {
      Navigator.of(context).pop();
      print('Loading dialog closed');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your feedback has been sent.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
