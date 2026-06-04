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
      'pharmacy_info': 'Pharmacy Info',
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
      'full_name': 'Full Name',
      'phone': 'Phone',
      'save_changes': 'Save Changes',
      'current_password': 'Current Password',
      'new_password': 'New Password',
      'update_password': 'Update Password',
      'logout_confirm': 'Are you sure you want to logout?',

      // Dashboard & Navigation
      'dashboard': 'Dashboard',
      'requests': 'Requests',
      'orders': 'Orders',
      'total_sales': 'Total Sales',
      'active_requests': 'Active Requests',
      'pending_orders': 'Pending Orders',
      'completed_orders': 'Completed Orders',
      'recent_activity': 'Recent Activity',
      
      // Requests Screen
      'new_requests': 'New Requests',
      'no_requests': 'No pending requests',
      'distance': 'Distance',
      'view_details': 'View Details',
      'send_quote': 'Send Quote',
      'reject': 'Reject',
      'accept': 'Accept',
      'medicine_name': 'Medicine Name',
      'quantity': 'Quantity',
      'add_medicine': 'Add Medicine',
      'subtotal': 'Subtotal',
      'delivery_fee': 'Delivery Fee',
      'total': 'Total',
      
      // Orders Screen
      'order_id': 'Order ID',
      'customer': 'Customer',
      'status': 'Status',
      'preparing': 'Preparing',
      'ready_for_pickup': 'Ready for Pickup',
      'picked_up': 'Picked Up',
      'on_the_way': 'On the Way',
      'delivered': 'Delivered',
      'cancelled': 'Cancelled',
      'update_status': 'Update Status',
    },
    'fr': {
      // Profile
      'profile': 'Profil',
      'edit_profile': 'Modifier le profil',
      'wallet': 'Portefeuille',
      'pharmacy_info': 'Infos Pharmacie',
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
      'full_name': 'Nom complet',
      'phone': 'Téléphone',
      'save_changes': 'Enregistrer les modifications',
      'current_password': 'Mot de passe actuel',
      'new_password': 'Nouveau mot de passe',
      'update_password': 'Mettre à jour le mot de passe',
      'logout_confirm': 'Êtes-vous sûr de vouloir vous déconnecter ?',

      // Dashboard & Navigation
      'dashboard': 'Tableau de bord',
      'requests': 'Demandes',
      'orders': 'Commandes',
      'total_sales': 'Ventes totales',
      'active_requests': 'Demandes actives',
      'pending_orders': 'Commandes en attente',
      'completed_orders': 'Commandes terminées',
      'recent_activity': 'Activité récente',
      
      // Requests Screen
      'new_requests': 'Nouvelles demandes',
      'no_requests': 'Aucune demande en attente',
      'distance': 'Distance',
      'view_details': 'Voir les détails',
      'send_quote': 'Envoyer un devis',
      'reject': 'Rejeter',
      'accept': 'Accepter',
      'medicine_name': 'Nom du médicament',
      'quantity': 'Quantité',
      'add_medicine': 'Ajouter un médicament',
      'subtotal': 'Sous-total',
      'delivery_fee': 'Frais de livraison',
      'total': 'Total',
      
      // Orders Screen
      'order_id': 'ID de commande',
      'customer': 'Client',
      'status': 'Statut',
      'preparing': 'En préparation',
      'ready_for_pickup': 'Prêt pour le ramassage',
      'picked_up': 'Récupéré',
      'on_the_way': 'En chemin',
      'delivered': 'Livré',
      'cancelled': 'Annulé',
      'update_status': 'Mettre à jour le statut',
    },
    'ar': {
      // Profile
      'profile': 'الملف الشخصي',
      'edit_profile': 'تعديل الملف الشخصي',
      'wallet': 'المحفظة',
      'pharmacy_info': 'معلومات الصيدلية',
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
      'full_name': 'الاسم الكامل',
      'phone': 'الهاتف',
      'save_changes': 'حفظ التغييرات',
      'current_password': 'كلمة المرور الحالية',
      'new_password': 'كلمة المرور الجديدة',
      'update_password': 'تحديث كلمة المرور',
      'logout_confirm': 'هل أنت متأكد أنك تريد تسجيل الخروج؟',

      // Dashboard & Navigation
      'dashboard': 'لوحة التحكم',
      'requests': 'الطلبات',
      'orders': 'الطلبيات',
      'total_sales': 'إجمالي المبيعات',
      'active_requests': 'الطلبات النشطة',
      'pending_orders': 'الطلبات المعلقة',
      'completed_orders': 'الطلبات المكتملة',
      'recent_activity': 'النشاط الأخير',
      
      // Requests Screen
      'new_requests': 'طلبات جديدة',
      'no_requests': 'لا توجد طلبات معلقة',
      'distance': 'المسافة',
      'view_details': 'عرض التفاصيل',
      'send_quote': 'إرسال عرض سعر',
      'reject': 'رفض',
      'accept': 'قبول',
      'medicine_name': 'اسم الدواء',
      'quantity': 'الكمية',
      'add_medicine': 'إضافة دواء',
      'subtotal': 'المجموع الفرعي',
      'delivery_fee': 'رسوم التوصيل',
      'total': 'الإجمالي',
      
      // Orders Screen
      'order_id': 'رقم الطلب',
      'customer': 'العميل',
      'status': 'الحالة',
      'preparing': 'جاري التحضير',
      'ready_for_pickup': 'جاهز للاستلام',
      'picked_up': 'تم الاستلام',
      'on_the_way': 'في الطريق',
      'delivered': 'تم التوصيل',
      'cancelled': 'تم الإلغاء',
      'update_status': 'تحديث الحالة',
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
