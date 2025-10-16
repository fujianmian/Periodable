import 'package:http/http.dart' as http;
import 'dart:io';

const String FORMSPREE_URL = 'https://formspree.io/f/xjkajena';

class FeedbackService {
  /// Send feedback via Formspree with optional image
  static Future<void> sendFeedback({
    required String message,
    File? imageFile,
  }) async {
    try {
      print('=== Starting feedback submission ===');
      print('Message: $message');
      print('Image file: ${imageFile?.path}');
      print('Formspree URL: $FORMSPREE_URL');

      var request = http.MultipartRequest('POST', Uri.parse(FORMSPREE_URL));

      // Formspree special fields
      request.fields['_subject'] = 'New Feedback from Cycle Tracker';
      request.fields['_replyto'] = 'jun379e@gmail.com';

      // Main content field
      request.fields['message'] = message;

      print('Fields added: ${request.fields}');

      // Add image if selected
      if (imageFile != null) {
        print('Adding image file...');
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            imageFile.path,
          ),
        );
        print('Image added to request');
      }

      print('Sending request to Formspree...');
      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('ERROR: Request timeout after 30 seconds');
          throw Exception('Request timeout');
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');

      final responseBody = await response.stream.bytesToString();
      print('Response body length: ${responseBody.length}');

      // Formspree returns 200 on success
      if (response.statusCode == 200) {
        print('=== Feedback sent successfully! ===');
        return;
      }
      // Sometimes it redirects
      else if (response.statusCode == 302 || response.statusCode == 303) {
        print('=== Feedback sent successfully (redirected)! ===');
        return;
      }
      // Anything else is an error
      else {
        print('ERROR: Status code is ${response.statusCode}');
        print(
            'Response preview: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}');
        throw Exception(
            'Failed to send feedback. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('=== ERROR in sendFeedback ===');
      print('Error: $e');
      rethrow;
    }
  }
}
