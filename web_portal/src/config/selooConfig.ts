import { AppCurrency, AppSettings, PaymentAccount, StaffRole } from '../types/seloo';

export const MAIN_MANAGER_EMAILS = ['apolich97@gmail.com', 'abode212k@gmail.com'];

export const DEFAULT_APP_SETTINGS: AppSettings = {
  rateNorth: 140,
  rateSouth: 413,
  usdRateNorth: 533,
  usdRateSouth: 1570,
  sarPerUsd: 3.75,
  deferredEnabled: true,
  deferredThresholdSar: 150,
  deferredUpfrontPercent: 50,
  shippingFeeSar: 0,
  deliveryFeeSar: 10,
  deliveryFeeNorthLocal: 1500,
  deliveryFeeSouthLocal: 1000,
  deliveryFeeSarLocal: 0,
  freeShippingThresholdSar: 75,
  supportWhatsApp: '967770518757',
  alternateWhatsApp: '967737383637',
  supportPhone: '770518757',
  companyNameAr: 'يمن سيلو',
  codEnabled: false,
  serviceFeeSar: 1.22,
  shippingPerPieceSar: 1,
  deliveryMinDays: 15,
  deliveryMaxDays: 20,
  senderName: 'يمن سيلو',
  waybillCompanyPhone: '770518757',
};

export const SELOO_POLICIES = {
  brandHost: 'yemenseloo.com',
  supportEmail: 'yemenseloo.shop@gmail.com',
  priceDisclaimer:
    'سعر SHEIN هو سعر المصدر وقت الإضافة، يتم تثبيت سعر الصرف للطلب بمجرد تأكيده وإرسال الحوالة.',
  shippingEstimate: 'مدة الوصول المتوقعة: 15–20 يوماً عبر مسار الصين ← الإمارات ← السعودية ← اليمن.',
  paymentNote:
    'يرجى إرفاق صورة الحوالة وإرسال استمارة التأكيد عبر واتساب لتسريع الاعتماد المحاسبي.',
  deferredRule:
    'في الطلب الآجل (دفعة أولى 50%): يُحترم سعر الصرف المسجل يوم إنشاء الطلب دون تغيير على المتبقي.',
};

export const PAYMENT_ACCOUNTS: PaymentAccount[] = [
  {
    id: 'kuraimi_yer_old',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — يمني قديم (شمال)',
    numbers: ['3141952047'],
    currencies: ['north'],
    brandShortAr: 'كريمي',
    regionAr: 'شمال',
    noteAr: 'باسم: عبدالله عبدالعالم عبدالله — حوّل بالريال اليمني القديم.',
    accentHex: '#1565C0',
  },
  {
    id: 'kuraimi_yer_new',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — يمني جديد (جنوب)',
    numbers: ['3055509637'],
    currencies: ['south'],
    brandShortAr: 'كريمي',
    regionAr: 'جنوب',
    noteAr: 'باسم: عبدالله عبدالعالم عبدالله — حوّل بالريال اليمني الجديد.',
    accentHex: '#1565C0',
  },
  {
    id: 'kuraimi_sar_old',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — سعودي (حساب الشمال)',
    numbers: ['3168803857'],
    currencies: ['sar'],
    brandShortAr: 'كريمي',
    regionAr: 'شمال',
    noteAr: 'باسم: عبدالله عبدالعالم عبدالله — حوّل بالريال السعودي.',
    accentHex: '#1565C0',
  },
  {
    id: 'kuraimi_sar_south',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — سعودي (حساب الجنوب)',
    numbers: ['3116991917'],
    currencies: ['sar', 'south'],
    brandShortAr: 'كريمي',
    regionAr: 'جنوب',
    noteAr: 'باسم: عبدالله عبدالعالم عبدالله — حوّل بالريال السعودي.',
    accentHex: '#1565C0',
  },
  {
    id: 'kuraimi_usd_old',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — دولار قديم (شمال)',
    numbers: ['3207365296'],
    currencies: ['sar', 'north', 'usd'],
    brandShortAr: 'كريمي',
    regionAr: 'شمال',
    noteAr: 'حوّل ما يعادل إجمالي الطلب بالدولار الأمريكي ثم أدخل المبلغ المرسل.',
    accentHex: '#1565C0',
  },
  {
    id: 'kuraimi_usd_new',
    bankAr: 'بنك الكريمي',
    titleAr: 'الكريمي — دولار جديد (جنوب)',
    numbers: ['3124522861'],
    currencies: ['sar', 'south', 'usd'],
    brandShortAr: 'كريمي',
    regionAr: 'جنوب',
    noteAr: 'حوّل ما يعادل إجمالي الطلب بالدولار الأمريكي ثم أدخل المبلغ المرسل.',
    accentHex: '#1565C0',
  },
  {
    id: 'qatibi',
    bankAr: 'بنك القطيبي',
    titleAr: 'القطيبي — يمني / سعودي / دولار',
    numbers: ['480642452'],
    currencies: ['sar', 'south', 'usd'],
    brandShortAr: 'قطيبي',
    regionAr: 'جنوب',
    noteAr: 'حساب واحد يستقبل العملات الثلاث — أدخل المبلغ بعملة الطلب.',
    accentHex: '#2E7D32',
  },
  {
    id: 'shilling',
    bankAr: 'محفظة شلن',
    titleAr: 'شلن — يمني (جنوب)',
    numbers: ['600589797', '775801198'],
    currencies: ['south'],
    brandShortAr: 'شلن',
    regionAr: 'جنوب',
    noteAr: 'التحويل بالريال اليمني الجديد عبر محفظة شلن.',
    accentHex: '#00897B',
  },
  {
    id: 'jaib',
    bankAr: 'محفظة جيب',
    titleAr: 'جيب — يمني (شمال)',
    numbers: ['2291789', '775801198'],
    currencies: ['north'],
    brandShortAr: 'جيب',
    regionAr: 'شمال',
    noteAr: 'أرسل إلى محفظة الرقم الأول، أو «تحويل إلى مشترك جيب» على الرقم الثاني.',
    accentHex: '#6A1B9A',
  },
];

export function accountsForCurrency(currency: AppCurrency): PaymentAccount[] {
  return PAYMENT_ACCOUNTS.filter((a) => a.currencies.includes(currency));
}

export const ROLE_LABELS_AR: Record<StaffRole, string> = {
  customer: 'عميل يمن سيلو',
  manager: 'المدير العام',
  marketer: 'مسوّق الكتالوج',
  accounting: 'قسم المحاسبة',
  shipping: 'إدارة الشحن',
  support: 'خدمة العملاء',
  courier: 'مندوب التوصيل',
};

export const ROLE_LABELS_EN: Record<StaffRole, string> = {
  customer: 'Customer',
  manager: 'General Manager',
  marketer: 'Catalog Marketer',
  accounting: 'Accounting',
  shipping: 'Shipping Ops',
  support: 'Customer Support',
  courier: 'Delivery Courier',
};

export const YEMEN_GOVERNORATES: {
  name: string;
  region: 'north' | 'south';
  offices: string[];
}[] = [
  { name: 'صنعاء', region: 'north', offices: ['تسليم مكتب يمن سيلو - حدة', 'شركة البسيري للنقل', 'النجم السريع'] },
  { name: 'عدن', region: 'south', offices: ['نقطة استلام كريتر / المنصورة', 'البسيري للشحن', 'العمقي إكسبريس'] },
  { name: 'تعز', region: 'north', offices: ['مكتب الحوبان / المدينة', 'البسيري للنقل', 'الراشدي إكسبريس'] },
  { name: 'حضرموت - المكلا', region: 'south', offices: ['مكتب المكلا المركزي', 'البسيري للشحن', 'العمقي للنقل'] },
  { name: 'إب', region: 'north', offices: ['مكتب الدائري الغربي', 'البسيري للنقل', 'شركة النجم'] },
  { name: 'الحديدة', region: 'north', offices: ['مكتب شارع صنعاء', 'البسيري للنقل'] },
  { name: 'مأرب', region: 'south', offices: ['مكتب مأرب المدينة', 'الرويشان إكسبريس', 'البسيري'] },
  { name: 'ذمار', region: 'north', offices: ['مكتب ذمار المركزي', 'البسيري للنقل'] },
  { name: 'شبوة', region: 'south', offices: ['مكتب عتق المركزي', 'العمقي للنقل'] },
  { name: 'لحج / أبين', region: 'south', offices: ['مندوب عدن المباشر', 'البسيري'] },
];
