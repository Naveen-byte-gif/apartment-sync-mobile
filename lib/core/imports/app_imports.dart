// Centralized imports file for ApartmentSync Mobile App
// Import this file to get all common dependencies

// Flutter packages
export 'package:flutter/material.dart';
export 'package:flutter/services.dart';

// Provider for state management
export 'package:provider/provider.dart';

// Firebase
export 'package:firebase_core/firebase_core.dart';
export 'package:firebase_messaging/firebase_messaging.dart';

// Core theme and colors
export '../theme/app_colors.dart';
export '../theme/app_theme.dart';

// Note: Paths are relative to lib/core/imports/
// For theme: ../theme/ means lib/core/theme/

// Core services
export '../services/api_service.dart';
export '../services/storage_service.dart';
export '../services/notification_service.dart';
export '../services/socket_service.dart';
export '../services/error_handler.dart';
export '../services/tts_service.dart';
export '../services/story_service.dart';
export '../services/chat_service.dart';

// Core constants
export '../constants/api_constants.dart';
export '../constants/app_constants.dart';
export '../constants/news_api_constants.dart';
export '../constants/story_api_constants.dart';

// Providers
export '../../presentation/providers/auth_provider.dart';
export '../../presentation/providers/news_provider.dart';
export '../../presentation/providers/story_provider.dart';
export '../../presentation/providers/tts_provider.dart';

// Widgets
export '../../presentation/widgets/loading_widget.dart';
export '../../presentation/widgets/message_dialog.dart';
export '../../presentation/widgets/message_snackbar.dart';

// Utils
export '../utils/message_handler.dart';
export '../utils/api_response_handler.dart';

