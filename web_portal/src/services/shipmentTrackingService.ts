import { OrderStatus, ShippingMilestone } from '../types/seloo';

export interface MilestoneMeta {
  key: ShippingMilestone;
  labelAr: string;
  labelEn: string;
  shortAr: string;
  emoji: string;
  progress: number;
  mappedStatus: OrderStatus;
  locationNameAr: string;
  mapX: number;
  mapY: number;
}

export const SHIPPING_MILESTONES: MilestoneMeta[] = [
  {
    key: ShippingMilestone.preparing,
    labelAr: 'قيد التجهيز — مستودعات شي إن',
    labelEn: 'Preparing at SHEIN Warehouse',
    shortAr: 'مستودعات شي إن',
    emoji: '🛍️',
    progress: 14,
    mappedStatus: OrderStatus.processing,
    locationNameAr: 'مستودعات شي إن — التجهيز والشراء',
    mapX: 90,
    mapY: 32,
  },
  {
    key: ShippingMilestone.chinaWarehouse,
    labelAr: 'تم الشحن — المطار في الصين إلى مستودع التجميع',
    labelEn: 'Shipped from China Airport',
    shortAr: 'مطار الصين 🇨🇳',
    emoji: '✈️',
    progress: 28,
    mappedStatus: OrderStatus.shipped,
    locationNameAr: 'مطار قوانغتشو — الصين',
    mapX: 84,
    mapY: 42,
  },
  {
    key: ShippingMilestone.uaeTransit,
    labelAr: 'قيد التجهيز — مستودعات الإمارات والفرز',
    labelEn: 'UAE Warehouse Sorting',
    shortAr: 'مستودع الإمارات 🇦🇪',
    emoji: '🇦🇪',
    progress: 48,
    mappedStatus: OrderStatus.shipped,
    locationNameAr: 'مستودع دبي — الإمارات',
    mapX: 60,
    mapY: 46,
  },
  {
    key: ShippingMilestone.saudiCustoms,
    labelAr: 'جمارك السعودية — مستودعات الرياض وجدة',
    labelEn: 'Saudi Customs & Riyadh/Jeddah Hub',
    shortAr: 'السعودية 🇸🇦',
    emoji: '🇸🇦',
    progress: 68,
    mappedStatus: OrderStatus.shipped,
    locationNameAr: 'جمارك السعودية · الرياض / جدة',
    mapX: 40,
    mapY: 50,
  },
  {
    key: ShippingMilestone.yemenArrival,
    labelAr: 'الشحن لليمن — وصل مقر الشركة في تعز',
    labelEn: 'Arrived Yemen HQ (Taiz)',
    shortAr: 'مقر تعز 🇾🇪',
    emoji: '🇾🇪',
    progress: 82,
    mappedStatus: OrderStatus.shipped,
    locationNameAr: 'مقر شركة يمن سيلو — تعز',
    mapX: 22,
    mapY: 66,
  },
  {
    key: ShippingMilestone.outForDelivery,
    labelAr: 'جاري التوصيل مع المندوب / مكتب المحافظة',
    labelEn: 'Out for Delivery',
    shortAr: 'المندوب 🛵',
    emoji: '🛵',
    progress: 93,
    mappedStatus: OrderStatus.outForDelivery,
    locationNameAr: 'مع المندوب إلى عنوانك',
    mapX: 16,
    mapY: 74,
  },
  {
    key: ShippingMilestone.delivered,
    labelAr: 'تم التسليم بنجاح (موثق بالتوقيع)',
    labelEn: 'Delivered & Signed',
    shortAr: 'تم التسليم ✅',
    emoji: '✅',
    progress: 100,
    mappedStatus: OrderStatus.delivered,
    locationNameAr: 'تم التسليم للعميل',
    mapX: 12,
    mapY: 78,
  },
];

export const SHIPPING_STAFF_GUIDE: { stage: string; meaning: string }[] = [
  { stage: '1. مستودعات شي إن', meaning: 'تُختار عند تأكيد الحوالة وشراء القطع من التطبيق.' },
  { stage: '2. مطار الصين 🇨🇳', meaning: 'تُختار بمجرد صدور رقم التتبع الدولي ومغادرة الصين.' },
  { stage: '3. مستودعات الإمارات 🇦🇪', meaning: 'تُختار عند وصول الشحنة للفرز الجوي في دبي.' },
  { stage: '4. جمارك السعودية (الرياض/جدة) 🇸🇦', meaning: 'تُختار عند دخول الشحنة للجمارك أو مستودعات الرياض وجدة.' },
  { stage: '5. مقر الشركة في تعز 🇾🇪', meaning: 'تُختار فور استلام الطرود في مقر يمن سيلو بتعز للفرز المحلي.' },
  { stage: '6. المندوب 🛵', meaning: 'تُفعّل التوقيع الإلكتروني وكود الـ 4 أرقام للعميل.' },
  { stage: '7. تم التسليم ✅', meaning: 'تُعتمد تلقائياً بعد توقيع العميل أو تأكيد المندوب.' },
];

export const ORDER_STAGE_BAR: {
  status: OrderStatus;
  labelAr: string;
  labelEn: string;
}[] = [
  { status: OrderStatus.unpaid, labelAr: 'بانتظار السداد', labelEn: 'Awaiting Payment' },
  { status: OrderStatus.verifying, labelAr: 'تأكيد الحوالة', labelEn: 'Verifying' },
  { status: OrderStatus.processing, labelAr: 'قيد التجهيز', labelEn: 'Processing' },
  { status: OrderStatus.shipped, labelAr: 'في الشحن', labelEn: 'In Transit' },
  { status: OrderStatus.outForDelivery, labelAr: 'مع المندوب', labelEn: 'Out for Delivery' },
  { status: OrderStatus.delivered, labelAr: 'تم التسليم', labelEn: 'Delivered' },
];

export function orderStatusLabelAr(status: OrderStatus): string {
  switch (status) {
    case OrderStatus.unpaid:
      return 'بانتظار السداد / إرسال الاستمارة';
    case OrderStatus.verifying:
      return 'قيد التحقق المحاسبي (تم استلام الاستمارة)';
    case OrderStatus.processing:
      return 'قيد التجهيز والشراء';
    case OrderStatus.shipped:
      return 'تم الشحن — في المسار الدولي';
    case OrderStatus.outForDelivery:
      return 'جاري التوصيل مع المندوب';
    case OrderStatus.delivered:
      return 'تم التسليم بنجاح';
    case OrderStatus.cancelled:
      return 'ملغي';
  }
}

export function getMilestoneMeta(stage?: ShippingMilestone | string): MilestoneMeta {
  return (
    SHIPPING_MILESTONES.find((m) => m.key === stage) || SHIPPING_MILESTONES[0]
  );
}

export function inferMilestoneFromOrder(
  status: OrderStatus,
  explicitStage?: ShippingMilestone
): ShippingMilestone {
  if (explicitStage && SHIPPING_MILESTONES.some((m) => m.key === explicitStage)) {
    return explicitStage;
  }
  switch (status) {
    case OrderStatus.delivered:
      return ShippingMilestone.delivered;
    case OrderStatus.outForDelivery:
      return ShippingMilestone.outForDelivery;
    case OrderStatus.shipped:
      return ShippingMilestone.chinaWarehouse;
    case OrderStatus.processing:
    default:
      return ShippingMilestone.preparing;
  }
}
