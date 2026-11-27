/**
 * Translations for every push notification the backend sends.
 *
 * Notifications are rendered per recipient, from the language stored on their
 * User document (set by the apps, which previously kept the choice only in
 * local device storage — which is why every push arrived in English no matter
 * what the user had picked in the app).
 *
 * Adding a notification: add a key here with all three languages, then call
 * sendNotificationToUser(userId, 'your_key', { param: value }, data).
 * A key missing a language falls back to English rather than showing nothing.
 */

export type Lang = 'en' | 'fr' | 'ar';

export const SUPPORTED_LANGS: Lang[] = ['en', 'fr', 'ar'];

export const DEFAULT_LANG: Lang = 'en';

/** Narrows anything stored on a user (or sent by an app) to a supported language. */
export function normalizeLang(value: unknown): Lang {
  const code = String(value || '').slice(0, 2).toLowerCase();
  return (SUPPORTED_LANGS as string[]).includes(code) ? (code as Lang) : DEFAULT_LANG;
}

type Message = { title: string; body: string };

/**
 * `{placeholders}` are filled from the params passed at the call site. Keep the
 * placeholder names identical across the three languages — Arabic and French
 * often need them in a different position, which is fine, but a renamed or
 * dropped placeholder silently leaves `{foo}` in the text a user sees.
 */
export const NOTIFICATIONS: Record<string, Record<Lang, Message>> = {
  // ---------------------------------------------------------------- patient
  prescription_submitted: {
    en: {
      title: 'Request Submitted',
      body: 'Your prescription request was submitted. We are finding a pharmacy for you.',
    },
    fr: {
      title: 'Demande envoyée',
      body: 'Votre demande d’ordonnance a été envoyée. Nous recherchons une pharmacie pour vous.',
    },
    ar: {
      title: 'تم إرسال الطلب',
      body: 'تم إرسال طلب الوصفة الطبية. نبحث لك عن صيدلية.',
    },
  },
  quote_received: {
    en: { title: 'Quote Received', body: 'New quote of {amount} MRU' },
    fr: { title: 'Devis reçu', body: 'Nouveau devis de {amount} MRU' },
    ar: { title: 'تم استلام عرض سعر', body: 'عرض سعر جديد بقيمة {amount} أوقية' },
  },
  quote_updated: {
    en: { title: 'Quote Updated', body: 'Updated quote of {amount} MRU' },
    fr: { title: 'Devis mis à jour', body: 'Devis mis à jour de {amount} MRU' },
    ar: { title: 'تم تحديث عرض السعر', body: 'عرض سعر محدَّث بقيمة {amount} أوقية' },
  },
  prescription_reassigned: {
    en: {
      title: 'Prescription Reassigned',
      body: 'Your prescription has been sent to another nearby pharmacy.',
    },
    fr: {
      title: 'Ordonnance réaffectée',
      body: 'Votre ordonnance a été envoyée à une autre pharmacie à proximité.',
    },
    ar: {
      title: 'تمت إعادة توجيه الوصفة',
      body: 'تم إرسال وصفتك الطبية إلى صيدلية أخرى قريبة.',
    },
  },
  prescription_expired: {
    en: {
      title: 'Request Timed Out',
      body: 'No pharmacy sent a quote for your prescription request. Please try again later.',
    },
    fr: {
      title: 'Demande expirée',
      body: 'Aucune pharmacie n’a envoyé de devis pour votre demande. Veuillez réessayer plus tard.',
    },
    ar: {
      title: 'انتهت مهلة الطلب',
      body: 'لم ترسل أي صيدلية عرض سعر لطلبك. يرجى المحاولة مرة أخرى لاحقًا.',
    },
  },
  rider_assigned: {
    en: {
      title: 'Rider Assigned',
      body: 'A rider has been assigned to your order and will pick it up soon.',
    },
    fr: {
      title: 'Livreur assigné',
      body: 'Un livreur a été assigné à votre commande et viendra la récupérer bientôt.',
    },
    ar: {
      title: 'تم تعيين مندوب توصيل',
      body: 'تم تعيين مندوب توصيل لطلبك وسيستلمه قريبًا.',
    },
  },
  payment_confirmed: {
    en: {
      title: 'Payment Confirmed! 🎉',
      body: 'Your payment for order {orderNumber} has been verified. Your order is now confirmed!',
    },
    fr: {
      title: 'Paiement confirmé ! 🎉',
      body: 'Votre paiement pour la commande {orderNumber} a été vérifié. Votre commande est confirmée !',
    },
    ar: {
      title: '🎉 تم تأكيد الدفع',
      body: 'تم التحقق من دفعتك للطلب {orderNumber}. تم تأكيد طلبك الآن!',
    },
  },
  order_picked_up: {
    en: { title: 'Order Picked Up', body: 'Your order has been picked up and is on the way!' },
    fr: { title: 'Commande récupérée', body: 'Votre commande a été récupérée et est en route !' },
    ar: { title: 'تم استلام الطلب', body: 'تم استلام طلبك وهو في الطريق إليك!' },
  },
  order_in_transit: {
    en: { title: 'Order On The Way', body: 'Your order is on the way to you.' },
    fr: { title: 'Commande en route', body: 'Votre commande est en route.' },
    ar: { title: 'الطلب في الطريق', body: 'طلبك في الطريق إليك.' },
  },
  order_delivered: {
    en: { title: 'Order Delivered!', body: 'Your order has been delivered. Enjoy!' },
    fr: { title: 'Commande livrée !', body: 'Votre commande a été livrée. Bonne journée !' },
    ar: { title: 'تم توصيل الطلب!', body: 'تم توصيل طلبك. نتمنى لك يومًا سعيدًا!' },
  },

  // --------------------------------------------------------------- pharmacy
  prescription_request: {
    en: {
      title: 'New Prescription Request',
      body: 'A new prescription request is waiting for your quote.',
    },
    fr: {
      title: 'Nouvelle demande d’ordonnance',
      body: 'Une nouvelle demande d’ordonnance attend votre devis.',
    },
    ar: {
      title: 'طلب وصفة طبية جديد',
      body: 'هناك طلب وصفة طبية جديد بانتظار عرض السعر الخاص بك.',
    },
  },
  prescription_timeout: {
    en: {
      title: 'Request Moved',
      body: 'A prescription request was sent to another pharmacy because no quote was sent within {minutes} minutes.',
    },
    fr: {
      title: 'Demande transférée',
      body: 'Une demande d’ordonnance a été envoyée à une autre pharmacie car aucun devis n’a été envoyé en {minutes} minutes.',
    },
    ar: {
      title: 'تم نقل الطلب',
      body: 'تم إرسال طلب وصفة طبية إلى صيدلية أخرى لعدم إرسال عرض سعر خلال {minutes} دقيقة.',
    },
  },
  quote_cancelled: {
    en: { title: 'Quote Cancelled', body: 'The patient cancelled the request for your quote.' },
    fr: { title: 'Devis annulé', body: 'Le patient a annulé la demande de votre devis.' },
    ar: { title: 'تم إلغاء عرض السعر', body: 'قام المريض بإلغاء طلب عرض السعر الخاص بك.' },
  },
  quote_expired: {
    en: {
      title: 'Quote Expired',
      body: 'Your quote has expired as the patient did not respond within 1 hour.',
    },
    fr: {
      title: 'Devis expiré',
      body: 'Votre devis a expiré car le patient n’a pas répondu dans un délai d’une heure.',
    },
    ar: {
      title: 'انتهت صلاحية عرض السعر',
      body: 'انتهت صلاحية عرض السعر لعدم رد المريض خلال ساعة واحدة.',
    },
  },
  order_confirmed_pharmacy: {
    en: {
      title: 'New Order Confirmed',
      body: 'Order {orderNumber} has been confirmed. Please prepare the medicines.',
    },
    fr: {
      title: 'Nouvelle commande confirmée',
      body: 'La commande {orderNumber} a été confirmée. Veuillez préparer les médicaments.',
    },
    ar: {
      title: 'تم تأكيد طلب جديد',
      body: 'تم تأكيد الطلب {orderNumber}. يرجى تحضير الأدوية.',
    },
  },
  order_confirmed_pharmacy_cod: {
    en: {
      title: 'New Order Confirmed',
      body: 'Order {orderNumber} has been confirmed (Pay on Delivery). Please prepare the medicines.',
    },
    fr: {
      title: 'Nouvelle commande confirmée',
      body: 'La commande {orderNumber} a été confirmée (paiement à la livraison). Veuillez préparer les médicaments.',
    },
    ar: {
      title: 'تم تأكيد طلب جديد',
      body: 'تم تأكيد الطلب {orderNumber} (الدفع عند الاستلام). يرجى تحضير الأدوية.',
    },
  },
  payment_proof_received: {
    en: {
      title: 'Payment Proof Received!',
      body: 'Patient submitted payment proof for order {orderNumber}. Please verify and confirm.',
    },
    fr: {
      title: 'Preuve de paiement reçue !',
      body: 'Le patient a envoyé une preuve de paiement pour la commande {orderNumber}. Veuillez vérifier et confirmer.',
    },
    ar: {
      title: 'تم استلام إثبات الدفع!',
      body: 'أرسل المريض إثبات الدفع للطلب {orderNumber}. يرجى التحقق والتأكيد.',
    },
  },
  order_cancelled_pharmacy: {
    en: { title: 'Order Cancelled', body: 'Order {orderNumber} was cancelled by the patient.' },
    fr: { title: 'Commande annulée', body: 'La commande {orderNumber} a été annulée par le patient.' },
    ar: { title: 'تم إلغاء الطلب', body: 'تم إلغاء الطلب {orderNumber} من قبل المريض.' },
  },
  rider_coming: {
    en: { title: 'Rider on the Way', body: 'Rider is coming to pick up order {orderNumber}' },
    fr: { title: 'Livreur en route', body: 'Le livreur vient récupérer la commande {orderNumber}' },
    ar: { title: 'المندوب في الطريق', body: 'المندوب في طريقه لاستلام الطلب {orderNumber}' },
  },

  // ------------------------------------------------------------------ rider
  delivery_available: {
    en: { title: 'New Delivery Available', body: 'Delivery fee: {fee} MRU' },
    fr: { title: 'Nouvelle livraison disponible', body: 'Frais de livraison : {fee} MRU' },
    ar: { title: 'توصيل جديد متاح', body: 'رسوم التوصيل: {fee} أوقية' },
  },
  delivery_waiting_one: {
    en: {
      title: 'A delivery is waiting',
      body: 'A delivery near you needs a rider. Open the app to accept it.',
    },
    fr: {
      title: 'Une livraison vous attend',
      body: 'Une livraison près de chez vous a besoin d’un livreur. Ouvrez l’application pour l’accepter.',
    },
    ar: {
      title: 'هناك طلب توصيل بانتظارك',
      body: 'هناك طلب توصيل قريب منك يحتاج إلى مندوب. افتح التطبيق لقبوله.',
    },
  },
  delivery_waiting_many: {
    en: {
      title: '{count} deliveries waiting',
      body: '{count} deliveries near you need a rider. Open the app to accept.',
    },
    fr: {
      title: '{count} livraisons en attente',
      body: '{count} livraisons près de chez vous ont besoin d’un livreur. Ouvrez l’application pour accepter.',
    },
    ar: {
      title: '{count} طلبات توصيل بانتظارك',
      body: 'هناك {count} طلبات توصيل قريبة منك تحتاج إلى مندوب. افتح التطبيق للقبول.',
    },
  },
  delivery_cancelled_rider: {
    en: { title: 'Delivery Cancelled', body: 'Order {orderNumber} was cancelled by the patient.' },
    fr: { title: 'Livraison annulée', body: 'La commande {orderNumber} a été annulée par le patient.' },
    ar: { title: 'تم إلغاء التوصيل', body: 'تم إلغاء الطلب {orderNumber} من قبل المريض.' },
  },
  earnings_added: {
    en: { title: 'Earnings Added', body: '{amount} MRU was added to your earnings.' },
    fr: { title: 'Gains ajoutés', body: '{amount} MRU ont été ajoutés à vos gains.' },
    ar: { title: 'تمت إضافة أرباح', body: 'تمت إضافة {amount} أوقية إلى أرباحك.' },
  },
  earnings_added_note: {
    en: { title: 'Earnings Added', body: '{amount} MRU was added to your earnings. Note: {note}' },
    fr: { title: 'Gains ajoutés', body: '{amount} MRU ont été ajoutés à vos gains. Note : {note}' },
    ar: { title: 'تمت إضافة أرباح', body: 'تمت إضافة {amount} أوقية إلى أرباحك. ملاحظة: {note}' },
  },
  earnings_deducted: {
    en: { title: 'Earnings Deducted', body: '{amount} MRU was deducted from your earnings.' },
    fr: { title: 'Gains déduits', body: '{amount} MRU ont été déduits de vos gains.' },
    ar: { title: 'تم خصم أرباح', body: 'تم خصم {amount} أوقية من أرباحك.' },
  },
  earnings_deducted_note: {
    en: {
      title: 'Earnings Deducted',
      body: '{amount} MRU was deducted from your earnings. Reason: {note}',
    },
    fr: {
      title: 'Gains déduits',
      body: '{amount} MRU ont été déduits de vos gains. Raison : {note}',
    },
    ar: {
      title: 'تم خصم أرباح',
      body: 'تم خصم {amount} أوقية من أرباحك. السبب: {note}',
    },
  },
};

/**
 * Status text the pharmacy order history shows for a closed request. These are
 * not notifications, but they are backend-authored English that used to reach
 * an Arabic or French screen untranslated, so they share the same mechanism.
 *
 * Note this cannot cover a rejection reason the pharmacist typed by hand —
 * that is free text in whatever language they wrote it in.
 */
export const STATUS_TEXT: Record<string, Record<Lang, string>> = {
  patient_cancelled_quote: {
    en: 'Patient cancelled the quote',
    fr: 'Le patient a annulé le devis',
    ar: 'قام المريض بإلغاء عرض السعر',
  },
  quote_not_accepted_in_time: {
    en: 'Patient did not accept the quote in time',
    fr: 'Le patient n’a pas accepté le devis à temps',
    ar: 'لم يقبل المريض عرض السعر في الوقت المحدد',
  },
};

function interpolate(template: string, params?: Record<string, unknown>): string {
  if (!params) return template;
  return template.replace(/\{(\w+)\}/g, (match, name) =>
    params[name] === undefined || params[name] === null ? match : String(params[name])
  );
}

/**
 * Renders a notification in `lang`, falling back to English for a key that has
 * no entry in that language. An unknown key returns the key itself rather than
 * throwing — a missing translation should never stop a push from going out.
 */
export function translateNotification(
  key: string,
  lang: Lang,
  params?: Record<string, unknown>
): Message {
  const entry = NOTIFICATIONS[key];
  if (!entry) {
    console.warn(`[notification-i18n] unknown key: ${key}`);
    return { title: key, body: '' };
  }
  const message = entry[lang] || entry[DEFAULT_LANG];
  return {
    title: interpolate(message.title, params),
    body: interpolate(message.body, params),
  };
}

/** Renders one of the STATUS_TEXT strings, falling back to English. */
export function translateStatusText(key: string, lang: Lang): string {
  const entry = STATUS_TEXT[key];
  if (!entry) return key;
  return entry[lang] || entry[DEFAULT_LANG];
}
