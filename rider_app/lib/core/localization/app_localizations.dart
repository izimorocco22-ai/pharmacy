import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Profile
      'profile': 'Profile',
      'edit_profile': 'Edit Profile',
      'wallet': 'Wallet',
      'privacy_policy': 'Privacy Policy',
      'change_password': 'Change Password',
      'help_support': 'Help & Support',
      'logout': 'Logout',
      'language': 'Language',
      'select_language': 'Select Language',
      'english': 'English',
      'french': 'French',
      'arabic': 'Arabic',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'logout_confirm': 'Are you sure you want to logout?',

      // Navigation & Dashboard
      'deliveries': 'Deliveries',
      'history': 'History',
      'new_tasks': 'New Tasks',
      'active_tasks': 'Active Tasks',
      'completed_tasks': 'Completed Tasks',
      'earnings': 'Earnings',
      
      // Tasks
      'order_id': 'Order ID',
      'pickup': 'Pickup',
      'delivery': 'Delivery',
      'accept_task': 'Accept Task',
      'reject_task': 'Reject Task',
      'start_pickup': 'Start Pickup',
      'mark_picked_up': 'Mark as Picked Up',
      'start_delivery': 'Start Delivery',
      'mark_delivered': 'Mark as Delivered',
      'view_on_map': 'View on Map',
      'call_customer': 'Call Customer',
      'call_pharmacy': 'Call Pharmacy',
      
      // General
      'status': 'Status',
      'pending': 'Pending',
      'on_way': 'On the Way',
      'delivered': 'Delivered',
      'cancelled': 'Cancelled',
    },
    'fr': {
      // Profile
      'profile': 'Profil',
      'edit_profile': 'Modifier le profil',
      'wallet': 'Portefeuille',
      'privacy_policy': 'Politique de confidentialité',
      'change_password': 'Modifier le mot de passe',
      'help_support': 'Aide et support',
      'logout': 'Déconnexion',
      'language': 'Langue',
      'select_language': 'Choisir la langue',
      'english': 'Anglais',
      'french': 'Français',
      'arabic': 'Arabe',
      'confirm': 'Confirmer',
      'cancel': 'Annuler',
      'logout_confirm': 'Êtes-vous sûr de vouloir vous déconnecter ?',

      // Navigation & Dashboard
      'deliveries': 'Livraisons',
      'history': 'Historique',
      'new_tasks': 'Nouvelles tâches',
      'active_tasks': 'Tâches actives',
      'completed_tasks': 'Tâches terminées',
      'earnings': 'Gains',
      
      // Tasks
      'order_id': 'ID de commande',
      'pickup': 'Ramassage',
      'delivery': 'Livraison',
      'accept_task': 'Accepter la tâche',
      'reject_task': 'Rejeter la tâche',
      'start_pickup': 'Commencer le ramassage',
      'mark_picked_up': 'Marquer comme récupéré',
      'start_delivery': 'Commencer la livraison',
      'mark_delivered': 'Marquer comme livré',
      'view_on_map': 'Voir sur la carte',
      'call_customer': 'Appeler le client',
      'call_pharmacy': 'Appeler la pharmacie',
      
      // General
      'status': 'Statut',
      'pending': 'En attente',
      'on_way': 'En chemin',
      'delivered': 'Livré',
      'cancelled': 'Annulé',
    },
    'ar': {
      // Profile
      'profile': 'الملف الشخصي',
      'edit_profile': 'تعديل الملف الشخصي',
      'wallet': 'المحفظة',
      'privacy_policy': 'سياسة الخصوصية',
      'change_password': 'تغيير كلمة المرور',
      'help_support': 'المساعدة والدعم',
      'logout': 'تسجيل الخروج',
      'language': 'اللغة',
      'select_language': 'اختر اللغة',
      'english': 'الإنجليزية',
      'french': 'الفرنسية',
      'arabic': 'العربية',
      'confirm': 'تأكيد',
      'cancel': 'إلغاء',
      'logout_confirm': 'هل أنت متأكد أنك تريد تسجيل الخروج؟',

      // Navigation & Dashboard
      'deliveries': 'التوصيلات',
      'history': 'السجل',
      'new_tasks': 'مهام جديدة',
      'active_tasks': 'المهام النشطة',
      'completed_tasks': 'المهام المكتملة',
      'earnings': 'الأرباح',
      
      // Tasks
      'order_id': 'رقم الطلب',
      'pickup': 'الاستلام',
      'delivery': 'التوصيل',
      'accept_task': 'قبول المهمة',
      'reject_task': 'رفض المهمة',
      'start_pickup': 'بدء الاستلام',
      'mark_picked_up': 'تم الاستلام',
      'start_delivery': 'بدء التوصيل',
      'mark_delivered': 'تم التوصيل',
      'view_on_map': 'عرض على الخريطة',
      'call_customer': 'اتصال بالعميل',
      'call_pharmacy': 'اتصال بالصيدلية',
      
      // General
      'status': 'الحالة',
      'pending': 'معلق',
      'on_way': 'في الطريق',
      'delivered': 'تم التوصيل',
      'cancelled': 'تم الإلغاء',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fr', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return Future.value(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
