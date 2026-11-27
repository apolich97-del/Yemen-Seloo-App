export type AppCurrency = 'south' | 'north' | 'sar' | 'usd';

export type AppLanguage = 'ar' | 'en';

export type StaffRole =
  | 'customer'
  | 'manager'
  | 'marketer'
  | 'accounting'
  | 'shipping'
  | 'support'
  | 'courier';

export enum OrderStatus {
  unpaid = 'unpaid',
  verifying = 'verifying',
  processing = 'processing',
  shipped = 'shipped',
  outForDelivery = 'outForDelivery',
  delivered = 'delivered',
  cancelled = 'cancelled',
}

export enum ShippingMilestone {
  preparing = 'preparing',
  chinaWarehouse = 'china_warehouse',
  uaeTransit = 'uae_transit',
  saudiCustoms = 'saudi_customs',
  yemenArrival = 'yemen_arrival',
  outForDelivery = 'out_for_delivery',
  delivered = 'delivered',
}

export type TabKey = 'home' | 'catalog' | 'shein' | 'cart' | 'orders' | 'me';

export interface CurrencyMatrix {
  sar: number;
  usd: number;
  northFromSar: number;
  southFromSar: number;
  northFromUsd: number;
  southFromUsd: number;
}

export interface AppSettings {
  rateNorth: number;
  rateSouth: number;
  usdRateNorth: number;
  usdRateSouth: number;
  sarPerUsd: number;
  deferredEnabled: boolean;
  deferredThresholdSar: number;
  deferredUpfrontPercent: number;
  shippingFeeSar: number;
  deliveryFeeSar: number;
  deliveryFeeNorthLocal: number;
  deliveryFeeSouthLocal: number;
  deliveryFeeSarLocal: number;
  freeShippingThresholdSar: number;
  supportWhatsApp: string;
  alternateWhatsApp: string;
  supportPhone: string;
  companyNameAr: string;
  codEnabled: boolean;
  serviceFeeSar: number;
  shippingPerPieceSar: number;
  deliveryMinDays: number;
  deliveryMaxDays: number;
  senderName: string;
  waybillCompanyPhone: string;
}

export interface Address {
  id: string;
  label: string;
  city: string;
  district?: string;
  line: string;
  phone: string;
  receiverName: string;
  lat?: number;
  lng?: number;
}

export interface CatalogItem {
  id: string;
  title: string;
  goodsId: string;
  sourceUrl: string;
  imageUrl: string;
  brand?: 'SHEIN' | 'يمن سيلو الخاص' | string;
  promoHeadline?: string;
  category: string;
  colors: string[];
  sizes: string[];
  sizePrices?: Record<string, number>;
  basePriceSar: number;
  marginSar: number;
  originalPriceSar?: number;
  discountPercent?: number;
  region: 'south' | 'north' | 'sar';
  badge: '' | 'new' | 'best' | 'offer';
  active: boolean;
  nonRefundable: boolean;
  nonRefundableReason: string;
  createdAt?: number;
}

export interface CartItem {
  id: string;
  goodsId: string;
  sku?: string;
  title: string;
  imageUrl: string;
  size: string;
  color: string;
  availableColors?: string[];
  availableSizes?: string[];
  sizePrices?: Record<string, number>;
  qty: number;
  unitPriceSar: number;
  productUrl: string;
  source: 'catalog' | 'shein' | 'manual';
  nonRefundable: boolean;
  nonRefundableReason: string;
  verifiedAt?: number;
  previousPriceSar?: number;
  stockStatus?: 'available' | 'out_of_stock' | 'price_changed';
}

export interface OrderItem {
  goodsId: string;
  sku: string;
  title: string;
  imageUrl: string;
  size: string;
  color: string;
  qty: number;
  unitPriceSar: number;
  productUrl: string;
  nonRefundable: boolean;
  nonRefundableReason: string;
  stockStatus?: string;
  isReplacement?: boolean;
  replacedFromTitle?: string;
  replacementNote?: string;
}

export interface TimelineEvent {
  status: OrderStatus;
  at: number;
  byName: string;
  note: string;
}

export interface PaymentInfo {
  accountId: string;
  accountTitleAr: string;
  accountNumber: string;
  amount: number;
  senderName: string;
  refNo: string;
  note: string;
  proofUrl: string;
  creditLocal: number;
  submittedAt?: number;
  confirmedAt?: number;
  confirmedByName: string;
}

export interface RefundRecord {
  id: string;
  amountSar: number;
  reason: string;
  reasonType: 'damaged' | 'wrong_item' | 'missing' | 'other';
  status: 'pending' | 'approved' | 'rejected' | 'paid';
  bankOrWallet: string;
  accountNo: string;
  createdAt: number;
  note?: string;
}

export interface ReplacementProposal {
  targetItemTitle: string;
  targetItemPriceSar: number;
  replacementTitle?: string;
  replacementUrl?: string;
  replacementImageUrl?: string;
  replacementPriceSar?: number;
  diffSar?: number;
  settlementNote?: string;
  submittedAt?: number;
  decidedAt?: number;
}

export interface Order {
  id: string;
  orderNo: string;
  userId: string;
  customerName?: string;
  customerEmail?: string;
  currency: AppCurrency;
  exchangeRate: number;
  usdRateNorth: number;
  usdRateSouth: number;
  sarPerUsd: number;
  items: OrderItem[];
  subtotalSar: number;
  shippingFeeSar: number;
  deliveryFeeSar: number;
  serviceFeeSar: number;
  discountSar: number;
  totalSar: number;
  totalLocal: number;
  paymentPlan: 'full' | 'half_deferred';
  upfrontDueLocal: number;
  paidTotalLocal: number;
  remainingLocal: number;
  couponCode: string;
  address: Address;
  status: OrderStatus;
  timeline: TimelineEvent[];
  payment: PaymentInfo;
  shippingMode: 'office' | 'driver' | 'pickup';
  shippingGovernorate: string;
  shippingOffice: string;
  shippingOfficeChoice: string;
  receiverName: string;
  receiverPhone: string;
  driverName: string;
  driverPhone: string;
  driverMeetPoint: string;
  trackingNo: string;
  trackingUrl: string;
  trackingImageUrl: string;
  courierName: string;
  courierPhone?: string;
  proofImageUrl: string;
  shippingStage: ShippingMilestone;
  shippingStageNote: string;
  shippingStageUpdatedAt?: number;
  whatsappSentAt?: number;
  whatsappSentTarget: string;
  orderSummaryImageUrl: string;
  priceSyncStatus: '' | 'pending_customer' | 'accepted' | 'rejected';
  priceSyncNote: string;
  proposedTotalSar: number;
  proposedTotalLocal: number;
  proposedItems: OrderItem[];
  replacementStatus: '' | 'pending_customer' | 'pending_admin' | 'approved' | 'rejected';
  replacementAlert?: string;
  replacementProposal?: ReplacementProposal;
  customerSignatureUrl: string;
  signedAt?: number;
  signedByName: string;
  deliveryPin: string;
  deliverySigned: boolean;
  deliveryPinVerified: boolean;
  refunds: RefundRecord[];
  refundedTotalSar: number;
  editingLocked: boolean;
  approvedAt?: number;
  approvedByName: string;
  deliveryMinDays: number;
  deliveryMaxDays: number;
  createdAt: number;
  updatedAt: number;
}

export interface ReceiptRecord {
  id: string;
  receiptNo: string;
  orderId: string;
  orderNo: string;
  customerId: string;
  status: 'pending' | 'approved' | 'rejected';
  source: 'customer' | 'admin';
  amountLocal: number;
  amountSar: number;
  refNo: string;
  senderName: string;
  note: string;
  proofUrl: string;
  reviewedBy?: string;
  rejectReason?: string;
  createdAt: number;
}

export interface WalletMovement {
  id: string;
  type: 'credit' | 'debit';
  amountSar: number;
  amountLocal: number;
  note: string;
  at: number;
}

export interface WalletData {
  balanceSar: number;
  movements: WalletMovement[];
}

export interface PaymentAccount {
  id: string;
  bankAr: string;
  titleAr: string;
  numbers: string[];
  currencies: AppCurrency[];
  brandShortAr: string;
  regionAr: string;
  noteAr: string;
  accentHex: string;
}

export interface CheckoutAlert {
  id: string;
  title: string;
  message: string;
  severity: 'info' | 'warning' | 'urgent';
  requireAck: boolean;
  active: boolean;
  createdByName: string;
  createdAt: number;
  expiresAt?: number;
}

export interface NotificationItem {
  id: string;
  title: string;
  body: string;
  type: 'order' | 'shipping' | 'payment' | 'support' | 'alert';
  orderId?: string;
  read: boolean;
  createdAt: number;
}

export interface SupportMessage {
  id: string;
  senderUid: string;
  senderName: string;
  isStaff: boolean;
  text: string;
  createdAt: number;
}

export interface SupportThread {
  id: string;
  userId: string;
  customerName: string;
  customerPhone: string;
  customerEmail: string;
  lastMessage: string;
  status: 'open' | 'resolved';
  updatedAt: number;
}

export interface AuditLogEntry {
  id: string;
  action: string;
  targetType: string;
  targetId: string;
  actorUid: string;
  actorName: string;
  actorRole: string;
  details: string;
  createdAt: number;
}

export interface DeletedRecord {
  id: string;
  collection: string;
  originalId: string;
  label: string;
  reason: string;
  deletedByName: string;
  deletedByUid: string;
  createdByName?: string;
  snapshot: Record<string, unknown>;
  deletedAt: number;
}

export interface SavedAccount {
  uid: string;
  displayName: string;
  email: string;
  photoURL: string;
  role: StaffRole;
  phone?: string;
  defaultCity?: string;
  lastUsedAt: number;
}

export interface UserProfile {
  uid: string;
  displayName: string;
  email: string;
  photoURL: string;
  phone: string;
  role: StaffRole;
  defaultCity: string;
  defaultAddress?: Address;
  walletBalanceSar?: number;
  updatedAt: number;
}

export interface StaffInvite {
  email: string;
  role: StaffRole;
  name?: string;
  active: boolean;
  addedBy?: string;
  updatedAt?: number;
}
