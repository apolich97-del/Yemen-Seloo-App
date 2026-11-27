import React, {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import {
  auth,
  db,
  onAuthStateChanged,
  signInWithGoogleAccount,
  signOutFirebase,
} from '../config/firebase';
import {
  DEFAULT_APP_SETTINGS,
  MAIN_MANAGER_EMAILS,
} from '../config/selooConfig';
import { FALLBACK_CATALOG_ITEMS, I18N } from '../data/seedData';
import {
  Address,
  AppCurrency,
  AppLanguage,
  AppSettings,
  AuditLogEntry,
  CartItem,
  CatalogItem,
  CheckoutAlert,
  DeletedRecord,
  NotificationItem,
  Order,
  OrderStatus,
  PaymentInfo,
  ReceiptRecord,
  RefundRecord,
  SavedAccount,
  ShippingMilestone,
  StaffInvite,
  StaffRole,
  SupportMessage,
  SupportThread,
  TabKey,
  UserProfile,
  WalletData,
} from '../types/seloo';
import {
  classifyBrandAndCategory,
  computeCartTotals,
  convertSarToCurrency,
  rateForCurrency,
  sanitizeImageUrl,
} from '../services/pricingService';
import {
  cacheCatalogItems,
  readCachedCatalogItems,
} from '../services/idbCacheService';
import { inferMilestoneFromOrder } from '../services/shipmentTrackingService';

interface ToastMessage {
  id: number;
  text: string;
  tone: 'info' | 'success' | 'error';
}

interface SelooContextValue {
  theme: 'light' | 'dark';
  toggleTheme: () => void;
  language: AppLanguage;
  setLanguage: (lang: AppLanguage) => void;
  t: (key: string) => string;
  currency: AppCurrency;
  setCurrency: (c: AppCurrency) => void;
  currencyModalOpen: boolean;
  setCurrencyModalOpen: (open: boolean) => void;
  activeTab: TabKey;
  setActiveTab: (tab: TabKey) => void;
  settings: AppSettings;
  catalog: CatalogItem[];
  catalogLoading: boolean;
  followedProductIds: string[];
  toggleFollowProduct: (goodsIdOrId: string) => void;
  deepLinkedProductId: string | null;
  clearDeepLinkedProduct: () => void;
  cart: CartItem[];
  isCartAbandoned24h: boolean;
  cartAgeHours: number;
  dismissCartReminder: () => void;
  addToCart: (item: Omit<CartItem, 'id'>) => void;
  updateCartQty: (id: string, delta: number) => void;
  removeFromCart: (id: string) => void;
  clearCart: () => void;
  updateCartItemPrice: (id: string, newPriceSar: number) => void;
  updateCartItemVariant: (
    id: string,
    patch: { color?: string; size?: string; unitPriceSar?: number; imageUrl?: string }
  ) => void;
  updateOrderAddress: (orderId: string, address: Address) => Promise<void>;
  notifyMarketerDiscount: (
    title: string,
    oldPriceSar: number,
    newPriceSar: number,
    sourceUrl?: string
  ) => Promise<void>;
  user: UserProfile | null;
  authLoading: boolean;
  effectiveRole: StaffRole;
  isStaff: boolean;
  isManager: boolean;
  savedAccounts: SavedAccount[];
  signInGoogle: (loginHint?: string) => Promise<void>;
  signOutUser: () => Promise<void>;
  removeSavedAccount: (uid: string) => void;
  savedAddresses: Address[];
  selectedAddressId: string;
  setSelectedAddressId: (id: string) => void;
  saveAddress: (addr: Address) => Promise<void>;
  deleteAddress: (id: string) => Promise<void>;
  orders: Order[];
  ordersLoading: boolean;
  activeOrderForPayment: Order | null;
  setActiveOrderForPayment: (order: Order | null) => void;
  selectedOrderId: string | null;
  setSelectedOrderId: (id: string | null) => void;
  checkoutAlerts: CheckoutAlert[];
  notifications: NotificationItem[];
  unreadNotificationsCount: number;
  markNotificationRead: (id: string) => Promise<void>;
  markAllNotificationsRead: () => Promise<void>;
  supportThread: SupportThread | null;
  supportMessages: SupportMessage[];
  allSupportThreads: SupportThread[];
  sendSupportMessage: (text: string, targetThreadId?: string) => Promise<void>;
  auditLogs: AuditLogEntry[];
  deletedRecords: DeletedRecord[];
  staffInvites: StaffInvite[];
  allOrdersForStaff: Order[];
  wallet: WalletData;
  orderReceipts: ReceiptRecord[];
  toasts: ToastMessage[];
  notifyToast: (text: string, tone?: 'info' | 'success' | 'error') => void;
  submitOrderReceipt: (
    order: Order,
    payload: { amountLocal: number; senderName: string; refNo: string; note: string; proofUrl: string }
  ) => Promise<void>;
  reviewOrderReceipt: (
    receipt: ReceiptRecord,
    approve: boolean,
    rejectReason?: string
  ) => Promise<void>;
  requestWalletWithdrawal: (amountSar: number, bankOrWallet: string, accountNo: string) => Promise<void>;
  createOrder: (params: {
    address: Address;
    shippingMode: 'office' | 'driver' | 'pickup';
    shippingGovernorate: string;
    shippingOffice: string;
    shippingOfficeChoice: string;
    driverName: string;
    driverPhone: string;
    driverMeetPoint: string;
    paymentPlan: 'full' | 'half_deferred';
    couponCode: string;
    discountSar: number;
  }) => Promise<Order | null>;
  submitOrderPayment: (orderId: string, payment: PaymentInfo) => Promise<void>;
  recordWhatsAppSubmission: (
    orderId: string,
    targetPhone: string,
    summaryImageUrl: string
  ) => Promise<void>;
  respondPriceSync: (orderId: string, accept: boolean) => Promise<void>;
  submitReplacementProposal: (
    orderId: string,
    replacement: { title: string; url: string; priceSar: number; imageUrl?: string }
  ) => Promise<void>;
  submitElectronicSignature: (
    orderId: string,
    signatureDataUrl: string,
    pinInput: string
  ) => Promise<void>;
  submitRefundRequest: (
    orderId: string,
    req: Omit<RefundRecord, 'id' | 'status' | 'createdAt'>
  ) => Promise<void>;
  // Staff & Manager actions
  saveAppSettings: (next: AppSettings) => Promise<void>;
  upsertCatalogItem: (item: Omit<CatalogItem, 'id'>, id?: string) => Promise<void>;
  deleteCatalogItem: (item: CatalogItem, reason: string) => Promise<void>;
  staffUpdateOrder: (
    orderId: string,
    patch: Partial<Order> & { note?: string },
    auditAction: string
  ) => Promise<void>;
  managerArchiveDeleteOrder: (order: Order, reason: string) => Promise<void>;
  saveCheckoutAlert: (alert: Omit<CheckoutAlert, 'id' | 'createdAt' | 'createdByName'>, id?: string) => Promise<void>;
  deleteCheckoutAlert: (id: string) => Promise<void>;
  saveStaffInvite: (invite: StaffInvite) => Promise<void>;
  removeStaffInvite: (email: string) => Promise<void>;
  pushCustomerNotification: (
    targetUid: string,
    payload: Omit<NotificationItem, 'id' | 'read' | 'createdAt'>
  ) => Promise<void>;
}

const SelooContext = createContext<SelooContextValue | null>(null);

const LS_KEYS = {
  theme: 'seloo_theme_v1',
  lang: 'seloo_lang_v1',
  currency: 'seloo_currency_v1',
  cart: 'seloo_cart_v2',
  cartUpdatedAt: 'seloo_cart_updated_at_v1',
  cartReminderDismissedAt: 'seloo_cart_reminder_dismissed_v1',
  followedProducts: 'seloo_followed_products_v1',
  accounts: 'seloo_saved_accounts_v1',
  addresses: 'seloo_addresses_v1',
};

function toMillis(val: unknown): number {
  if (!val) return Date.now();
  if (typeof val === 'number') return val;
  if (typeof val === 'object' && val !== null && 'toMillis' in val) {
    return (val as { toMillis: () => number }).toMillis();
  }
  return Date.now();
}

export const SelooProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [theme, setTheme] = useState<'light' | 'dark'>(() => {
    const saved = localStorage.getItem(LS_KEYS.theme);
    return saved === 'dark' ? 'dark' : 'light';
  });
  const [language, setLanguageState] = useState<AppLanguage>(() => {
    const saved = localStorage.getItem(LS_KEYS.lang);
    return saved === 'en' ? 'en' : 'ar';
  });
  const [currency, setCurrencyState] = useState<AppCurrency>(() => {
    const saved = localStorage.getItem(LS_KEYS.currency) as AppCurrency | null;
    return saved && ['south', 'north', 'sar', 'usd'].includes(saved) ? saved : 'south';
  });
  const [currencyModalOpen, setCurrencyModalOpen] = useState(false);

  const [deepLinkedProductId, setDeepLinkedProductId] = useState<string | null>(() => {
    if (typeof window === 'undefined') return null;
    const sp = new URLSearchParams(window.location.search);
    return sp.get('product');
  });
  const clearDeepLinkedProduct = () => {
    setDeepLinkedProductId(null);
    if (typeof window !== 'undefined') {
      const url = new URL(window.location.href);
      if (url.searchParams.has('product')) {
        url.searchParams.delete('product');
        window.history.replaceState({}, '', url.toString());
      }
    }
  };

  const [activeTab, setActiveTab] = useState<TabKey>(() => {
    if (typeof window !== 'undefined') {
      const sp = new URLSearchParams(window.location.search);
      if (sp.get('product')) return 'catalog';
    }
    return 'home';
  });
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_APP_SETTINGS);
  const [catalog, setCatalog] = useState<CatalogItem[]>(FALLBACK_CATALOG_ITEMS);
  const [catalogLoading, setCatalogLoading] = useState(true);

  const [followedProductIds, setFollowedProductIds] = useState<string[]>(() => {
    try {
      const raw = localStorage.getItem(LS_KEYS.followedProducts);
      return raw ? (JSON.parse(raw) as string[]) : [];
    } catch {
      return [];
    }
  });

  const [cart, setCart] = useState<CartItem[]>(() => {
    try {
      const raw = localStorage.getItem(LS_KEYS.cart);
      return raw ? (JSON.parse(raw) as CartItem[]) : [];
    } catch {
      return [];
    }
  });
  const [cartUpdatedAt, setCartUpdatedAt] = useState<number>(() => {
    const saved = Number(localStorage.getItem(LS_KEYS.cartUpdatedAt) || 0);
    return saved > 0 ? saved : Date.now();
  });
  const [cartReminderDismissedAt, setCartReminderDismissedAt] = useState<number>(() => {
    return Number(localStorage.getItem(LS_KEYS.cartReminderDismissedAt) || 0);
  });

  const [savedAccounts, setSavedAccounts] = useState<SavedAccount[]>(() => {
    try {
      const raw = localStorage.getItem(LS_KEYS.accounts);
      return raw ? (JSON.parse(raw) as SavedAccount[]) : [];
    } catch {
      return [];
    }
  });

  const [savedAddresses, setSavedAddresses] = useState<Address[]>(() => {
    try {
      const raw = localStorage.getItem(LS_KEYS.addresses);
      return raw ? (JSON.parse(raw) as Address[]) : [];
    } catch {
      return [];
    }
  });
  const [selectedAddressId, setSelectedAddressId] = useState<string>('');

  const [firebaseUid, setFirebaseUid] = useState<string | null>(null);
  const [firebaseEmail, setFirebaseEmail] = useState<string>('');
  const [firebaseDisplayName, setFirebaseDisplayName] = useState<string>('');
  const [firebasePhoto, setFirebasePhoto] = useState<string>('');
  const [userDocRole, setUserDocRole] = useState<StaffRole>('customer');
  const [inviteRole, setInviteRole] = useState<StaffRole>('customer');
  const [userPhone, setUserPhone] = useState<string>('');
  const [userDefaultCity, setUserDefaultCity] = useState<string>('صنعاء');
  const [authLoading, setAuthLoading] = useState(true);

  const [orders, setOrders] = useState<Order[]>([]);
  const [ordersLoading, setOrdersLoading] = useState(false);
  const [allOrdersForStaff, setAllOrdersForStaff] = useState<Order[]>([]);
  const [activeOrderForPayment, setActiveOrderForPayment] = useState<Order | null>(null);
  const [selectedOrderId, setSelectedOrderId] = useState<string | null>(null);
  const [checkoutAlerts, setCheckoutAlerts] = useState<CheckoutAlert[]>([]);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [supportThread, setSupportThread] = useState<SupportThread | null>(null);
  const [supportMessages, setSupportMessages] = useState<SupportMessage[]>([]);
  const [allSupportThreads, setAllSupportThreads] = useState<SupportThread[]>([]);
  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>([]);
  const [deletedRecords, setDeletedRecords] = useState<DeletedRecord[]>([]);
  const [staffInvites, setStaffInvites] = useState<StaffInvite[]>([]);
  const [wallet, setWallet] = useState<WalletData>({ balanceSar: 0, movements: [] });
  const [orderReceipts, setOrderReceipts] = useState<ReceiptRecord[]>([]);
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  const notifyToast = (
    text: string,
    tone: 'info' | 'success' | 'error' = 'info'
  ) => {
    const id = Date.now() + Math.floor(Math.random() * 999);
    setToasts((prev) => [...prev.slice(-2), { id, text, tone }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 3600);
  };

  // Sync HTML dark class + RTL/LTR direction
  useEffect(() => {
    const root = document.documentElement;
    if (theme === 'dark') {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }
    localStorage.setItem(LS_KEYS.theme, theme);
  }, [theme]);

  useEffect(() => {
    const root = document.documentElement;
    root.lang = language;
    root.dir = language === 'ar' ? 'rtl' : 'ltr';
    localStorage.setItem(LS_KEYS.lang, language);
  }, [language]);

  useEffect(() => {
    localStorage.setItem(LS_KEYS.currency, currency);
  }, [currency]);

  useEffect(() => {
    localStorage.setItem(LS_KEYS.cart, JSON.stringify(cart));
    if (cart.length === 0) {
      localStorage.removeItem(LS_KEYS.cartUpdatedAt);
    } else if (!localStorage.getItem(LS_KEYS.cartUpdatedAt)) {
      const now = Date.now();
      setCartUpdatedAt(now);
      localStorage.setItem(LS_KEYS.cartUpdatedAt, String(now));
    }
  }, [cart]);

  useEffect(() => {
    localStorage.setItem(LS_KEYS.followedProducts, JSON.stringify(followedProductIds));
  }, [followedProductIds]);

  useEffect(() => {
    localStorage.setItem(LS_KEYS.accounts, JSON.stringify(savedAccounts));
  }, [savedAccounts]);

  useEffect(() => {
    localStorage.setItem(LS_KEYS.addresses, JSON.stringify(savedAddresses));
    if (!selectedAddressId && savedAddresses.length > 0) {
      setSelectedAddressId(savedAddresses[0].id);
    }
  }, [savedAddresses, selectedAddressId]);

  const toggleTheme = () => setTheme((prev) => (prev === 'dark' ? 'light' : 'dark'));
  const setLanguage = (lang: AppLanguage) => setLanguageState(lang);
  const setCurrency = (c: AppCurrency) => setCurrencyState(c);
  const t = (key: string) => I18N[language][key] || key;

  // Live Firestore: settings/app
  useEffect(() => {
    const unsub = onSnapshot(
      doc(db, 'settings', 'app'),
      (snap) => {
        if (!snap.exists()) return;
        const m = snap.data();
        setSettings({
          ...DEFAULT_APP_SETTINGS,
          rateNorth: typeof m.rateNorth === 'number' ? m.rateNorth : DEFAULT_APP_SETTINGS.rateNorth,
          rateSouth: typeof m.rateSouth === 'number' ? m.rateSouth : DEFAULT_APP_SETTINGS.rateSouth,
          usdRateNorth:
            typeof m.usdRateNorth === 'number' ? m.usdRateNorth : DEFAULT_APP_SETTINGS.usdRateNorth,
          usdRateSouth:
            typeof m.usdRateSouth === 'number' ? m.usdRateSouth : DEFAULT_APP_SETTINGS.usdRateSouth,
          sarPerUsd: typeof m.sarPerUsd === 'number' ? m.sarPerUsd : DEFAULT_APP_SETTINGS.sarPerUsd,
          deferredEnabled:
            typeof m.deferredEnabled === 'boolean'
              ? m.deferredEnabled
              : DEFAULT_APP_SETTINGS.deferredEnabled,
          deferredThresholdSar:
            typeof m.deferredThresholdSar === 'number'
              ? m.deferredThresholdSar
              : DEFAULT_APP_SETTINGS.deferredThresholdSar,
          deferredUpfrontPercent:
            typeof m.deferredUpfrontPercent === 'number'
              ? m.deferredUpfrontPercent
              : DEFAULT_APP_SETTINGS.deferredUpfrontPercent,
          shippingFeeSar:
            typeof m.shippingFeeSar === 'number' ? m.shippingFeeSar : DEFAULT_APP_SETTINGS.shippingFeeSar,
          deliveryFeeSar:
            typeof m.deliveryFeeSar === 'number' ? m.deliveryFeeSar : DEFAULT_APP_SETTINGS.deliveryFeeSar,
          freeShippingThresholdSar:
            typeof m.freeShippingThresholdSar === 'number'
              ? m.freeShippingThresholdSar
              : DEFAULT_APP_SETTINGS.freeShippingThresholdSar,
          supportWhatsApp: m.supportWhatsApp || DEFAULT_APP_SETTINGS.supportWhatsApp,
          alternateWhatsApp: m.alternateWhatsApp || DEFAULT_APP_SETTINGS.alternateWhatsApp,
          supportPhone: m.supportPhone || DEFAULT_APP_SETTINGS.supportPhone,
          companyNameAr: m.companyNameAr || DEFAULT_APP_SETTINGS.companyNameAr,
          serviceFeeSar:
            typeof m.serviceFeeSar === 'number' ? m.serviceFeeSar : DEFAULT_APP_SETTINGS.serviceFeeSar,
          shippingPerPieceSar:
            typeof m.shippingPerPieceSar === 'number'
              ? m.shippingPerPieceSar
              : DEFAULT_APP_SETTINGS.shippingPerPieceSar,
          deliveryMinDays:
            typeof m.deliveryMinDays === 'number'
              ? m.deliveryMinDays
              : DEFAULT_APP_SETTINGS.deliveryMinDays,
          deliveryMaxDays:
            typeof m.deliveryMaxDays === 'number'
              ? m.deliveryMaxDays
              : DEFAULT_APP_SETTINGS.deliveryMaxDays,
        });
      },
      () => {
        // Keep defaults quietly if offline
      }
    );
    return () => unsub();
  }, []);

  // Bootstrap catalog immediately from IndexedDB cache, then sync live Firestore
  useEffect(() => {
    let active = true;
    readCachedCatalogItems().then((cached) => {
      if (active && cached.length > 0) {
        setCatalog(cached);
        setCatalogLoading(false);
      }
    });

    const q = query(collection(db, 'catalog'), limit(120));
    const unsub = onSnapshot(
      q,
      (snap) => {
        if (!snap.empty) {
          const items: CatalogItem[] = snap.docs
            .map((d) => {
              const m = d.data();
              const title = String(m.title || 'منتج يمن سيلو');
              const sourceUrl = String(m.sourceUrl || '');
              const classified = classifyBrandAndCategory(title, sourceUrl, String(m.category || ''));
              return {
                id: d.id,
                title,
                goodsId: String(m.goodsId || d.id),
                sourceUrl,
                imageUrl: sanitizeImageUrl(
                  String(m.imageUrl || ''),
                  FALLBACK_CATALOG_ITEMS[0].imageUrl
                ),
                brand: m.brand ? String(m.brand) : classified.brand,
                promoHeadline: m.promoHeadline ? String(m.promoHeadline) : '',
                category: String(m.category || classified.category),
                colors: Array.isArray(m.colors) && m.colors.length ? m.colors : ['أساسي'],
                sizes: Array.isArray(m.sizes) && m.sizes.length ? m.sizes : ['One Size'],
                sizePrices:
                  m.sizePrices && typeof m.sizePrices === 'object'
                    ? (m.sizePrices as Record<string, number>)
                    : undefined,
                basePriceSar: Number(m.basePriceSar || 0),
                marginSar: Number(m.marginSar || 0),
                originalPriceSar: m.originalPriceSar ? Number(m.originalPriceSar) : undefined,
                discountPercent: m.discountPercent ? Number(m.discountPercent) : undefined,
                region: (m.region as 'south' | 'north' | 'sar') || 'south',
                badge: (['new', 'best', 'offer'].includes(String(m.badge))
                  ? String(m.badge)
                  : '') as '' | 'new' | 'best' | 'offer',
                active: m.active !== false,
                nonRefundable: Boolean(m.nonRefundable),
                nonRefundableReason: String(m.nonRefundableReason || ''),
                createdAt: toMillis(m.createdAt),
              };
            })
            .filter((it) => it.active);
          if (items.length > 0) {
            setCatalog(items);
            cacheCatalogItems(items);
          }
        }
        setCatalogLoading(false);
      },
      () => {
        setCatalogLoading(false);
      }
    );
    return () => {
      active = false;
      unsub();
    };
  }, []);

  // Live Firestore: checkout_alerts
  useEffect(() => {
    const q = query(collection(db, 'checkout_alerts'), limit(30));
    const unsub = onSnapshot(
      q,
      (snap) => {
        const list: CheckoutAlert[] = snap.docs
          .map((d) => {
            const m = d.data();
            return {
              id: d.id,
              title: String(m.title || 'تنبيه هام'),
              message: String(m.message || ''),
              severity: (m.severity as 'info' | 'warning' | 'urgent') || 'info',
              requireAck: Boolean(m.requireAck),
              active: m.active !== false,
              createdByName: String(m.createdByName || 'الإدارة'),
              createdAt: toMillis(m.createdAt),
              expiresAt: m.expiresAt ? toMillis(m.expiresAt) : undefined,
            };
          })
          .filter((a) => a.active && (!a.expiresAt || a.expiresAt > Date.now()));
        setCheckoutAlerts(list);
      },
      () => {}
    );
    return () => unsub();
  }, []);

  // Firebase Auth listener
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (fbUser) => {
      if (!fbUser) {
        setFirebaseUid(null);
        setFirebaseEmail('');
        setFirebaseDisplayName('');
        setFirebasePhoto('');
        setUserDocRole('customer');
        setInviteRole('customer');
        setOrders([]);
        setNotifications([]);
        setAuthLoading(false);
        return;
      }
      setFirebaseUid(fbUser.uid);
      setFirebaseEmail((fbUser.email || '').toLowerCase());
      setFirebaseDisplayName(fbUser.displayName || 'مستخدم يمن سيلو');
      setFirebasePhoto(fbUser.photoURL || '');
      setAuthLoading(false);
    });
    return () => unsub();
  }, []);

  // Real-time stream on users/{uid} & staff_invites/{email}
  useEffect(() => {
    if (!firebaseUid) return;
    const unsubUser = onSnapshot(
      doc(db, 'users', firebaseUid),
      async (snap) => {
        if (!snap.exists()) {
          // Initialize customer user profile doc once on first Google sign-in without forcing form fill
          try {
            await setDoc(
              doc(db, 'users', firebaseUid),
              {
                displayName: firebaseDisplayName,
                email: firebaseEmail,
                photoURL: firebasePhoto,
                role: MAIN_MANAGER_EMAILS.includes(firebaseEmail) ? 'manager' : 'customer',
                createdAt: serverTimestamp(),
                updatedAt: serverTimestamp(),
              },
              { merge: true }
            );
          } catch {
            // ignore permission edge case
          }
          return;
        }
        const m = snap.data();
        if (m.role) setUserDocRole(m.role as StaffRole);
        if (m.phone) setUserPhone(String(m.phone));
        if (m.defaultCity) setUserDefaultCity(String(m.defaultCity));
      },
      () => {}
    );

    let unsubInvite: (() => void) | undefined;
    if (firebaseEmail) {
      unsubInvite = onSnapshot(
        doc(db, 'staff_invites', firebaseEmail),
        (snap) => {
          if (snap.exists() && snap.data().active !== false && snap.data().role) {
            setInviteRole(snap.data().role as StaffRole);
          } else {
            setInviteRole('customer');
          }
        },
        () => setInviteRole('customer')
      );
    }

    // Real-time saved addresses subcollection
    const unsubAddrs = onSnapshot(
      collection(db, 'users', firebaseUid, 'addresses'),
      (snap) => {
        if (!snap.empty) {
          const list: Address[] = snap.docs.map((d) => {
            const m = d.data();
            return {
              id: d.id,
              label: String(m.label || 'العنوان'),
              city: String(m.city || 'صنعاء'),
              district: m.district ? String(m.district) : '',
              line: String(m.line || ''),
              phone: String(m.phone || ''),
              receiverName: String(m.receiverName || firebaseDisplayName),
            };
          });
          setSavedAddresses(list);
        }
      },
      () => {}
    );

    return () => {
      unsubUser();
      unsubInvite?.();
      unsubAddrs();
    };
  }, [firebaseUid, firebaseEmail, firebaseDisplayName, firebasePhoto]);

  const effectiveRole: StaffRole = useMemo(() => {
    if (!firebaseUid) return 'customer';
    if (MAIN_MANAGER_EMAILS.includes(firebaseEmail)) return 'manager';
    if (inviteRole !== 'customer') return inviteRole;
    return userDocRole || 'customer';
  }, [firebaseUid, firebaseEmail, inviteRole, userDocRole]);

  const isStaff = effectiveRole !== 'customer';
  const isManager = effectiveRole === 'manager';

  // Route staff users directly to their operational dashboard once upon sign-in (unless product deep-link)
  useEffect(() => {
    if (!firebaseUid || !isStaff || deepLinkedProductId) return;
    const guardKey = `seloo_staff_routed_${firebaseUid}`;
    if (!sessionStorage.getItem(guardKey)) {
      sessionStorage.setItem(guardKey, '1');
      setActiveTab('me');
    }
  }, [firebaseUid, isStaff, deepLinkedProductId]);

  const user: UserProfile | null = useMemo(() => {
    if (!firebaseUid) return null;
    return {
      uid: firebaseUid,
      displayName: firebaseDisplayName,
      email: firebaseEmail,
      photoURL: firebasePhoto,
      phone: userPhone,
      role: effectiveRole,
      defaultCity: userDefaultCity,
      updatedAt: Date.now(),
    };
  }, [
    firebaseUid,
    firebaseDisplayName,
    firebaseEmail,
    firebasePhoto,
    userPhone,
    effectiveRole,
    userDefaultCity,
  ]);

  // Persist signed-in user into Saved Accounts list (Feature #8)
  useEffect(() => {
    if (!user) return;
    setSavedAccounts((prev) => {
      const filtered = prev.filter((a) => a.uid !== user.uid && a.email !== user.email);
      const entry: SavedAccount = {
        uid: user.uid,
        displayName: user.displayName,
        email: user.email,
        photoURL: user.photoURL,
        role: effectiveRole,
        phone: user.phone,
        defaultCity: user.defaultCity,
        lastUsedAt: Date.now(),
      };
      return [entry, ...filtered].slice(0, 8);
    });
  }, [user, effectiveRole]);

  // Live Firestore: customer orders
  useEffect(() => {
    if (!firebaseUid) return;
    setOrdersLoading(true);
    const q = query(
      collection(db, 'orders'),
      where('userId', '==', firebaseUid),
      limit(60)
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        const list = snap.docs
          .map((d) => mapOrderDoc(d.id, d.data()))
          .sort((a, b) => b.createdAt - a.createdAt);
        setOrders(list);
        setOrdersLoading(false);
      },
      () => {
        setOrdersLoading(false);
      }
    );
    return () => unsub();
  }, [firebaseUid]);

  // Live Firestore: notifications/{uid}/items
  useEffect(() => {
    if (!firebaseUid) return;
    const q = query(
      collection(db, 'notifications', firebaseUid, 'items'),
      orderBy('createdAt', 'desc'),
      limit(40)
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        setNotifications(
          snap.docs.map((d) => {
            const m = d.data();
            return {
              id: d.id,
              title: String(m.title || 'إشعار جديد'),
              body: String(m.body || ''),
              type: (m.type as NotificationItem['type']) || 'order',
              orderId: m.orderId ? String(m.orderId) : undefined,
              read: Boolean(m.read),
              createdAt: toMillis(m.createdAt),
            };
          })
        );
      },
      () => {}
    );
    return () => unsub();
  }, [firebaseUid]);

  // Customer Wallet & Receipts listeners
  useEffect(() => {
    if (!firebaseUid) {
      setWallet({ balanceSar: 0, movements: [] });
      setOrderReceipts([]);
      return;
    }
    const unsubWallet = onSnapshot(
      doc(db, 'wallets', firebaseUid),
      (snap) => {
        if (!snap.exists()) {
          setWallet({ balanceSar: 0, movements: [] });
          return;
        }
        const m = snap.data();
        const rawMoves = Array.isArray(m.movements) ? m.movements : [];
        setWallet({
          balanceSar: Number(m.balanceSar || 0),
          movements: rawMoves
            .map((mv: Record<string, unknown>) => ({
              id: String(mv.id || ''),
              type: (mv.type as 'credit' | 'debit') || 'credit',
              amountSar: Number(mv.amountSar || 0),
              amountLocal: Number(mv.amountLocal || 0),
              note: String(mv.note || ''),
              at: toMillis(mv.at),
            }))
            .sort((a, b) => b.at - a.at),
        });
      },
      () => {}
    );

    const unsubReceipts = onSnapshot(
      query(
        collection(db, 'orders'),
        where('userId', '==', firebaseUid),
        limit(30)
      ),
      () => {},
      () => {}
    );

    return () => {
      unsubWallet();
      unsubReceipts();
    };
  }, [firebaseUid]);

  // Listen to selected order's receipts subcollection (Eesal)
  useEffect(() => {
    const targetOrderId = selectedOrderId || activeOrderForPayment?.id;
    if (!firebaseUid || !targetOrderId) {
      setOrderReceipts([]);
      return;
    }
    const q = query(
      collection(db, 'orders', targetOrderId, 'receipts'),
      limit(30)
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        setOrderReceipts(
          snap.docs
            .map((d) => {
              const m = d.data();
              return {
                id: d.id,
                receiptNo: String(m.receiptNo || d.id.slice(0, 6).toUpperCase()),
                orderId: String(m.orderId || targetOrderId),
                orderNo: String(m.orderNo || ''),
                customerId: String(m.customerId || ''),
                status: (m.status as ReceiptRecord['status']) || 'pending',
                source: (m.source as ReceiptRecord['source']) || 'customer',
                amountLocal: Number(m.amountLocal || 0),
                amountSar: Number(m.amountSar || 0),
                refNo: String(m.refNo || ''),
                senderName: String(m.senderName || ''),
                note: String(m.note || ''),
                proofUrl: String(m.proofUrl || ''),
                reviewedBy: m.reviewedBy ? String(m.reviewedBy) : '',
                rejectReason: m.rejectReason ? String(m.rejectReason) : '',
                createdAt: toMillis(m.createdAt),
              };
            })
            .sort((a, b) => b.createdAt - a.createdAt)
        );
      },
      () => {}
    );
    return () => unsub();
  }, [firebaseUid, selectedOrderId, activeOrderForPayment?.id]);

  // Staff live streams (orders, invites, audit_logs, deleted_records, support)
  useEffect(() => {
    if (!firebaseUid || !isStaff) {
      setAllOrdersForStaff([]);
      setAuditLogs([]);
      setDeletedRecords([]);
      setStaffInvites([]);
      return;
    }
    const unsubAllOrders = onSnapshot(
      query(collection(db, 'orders'), limit(120)),
      (snap) => {
        const list = snap.docs
          .map((d) => mapOrderDoc(d.id, d.data()))
          .sort((a, b) => b.createdAt - a.createdAt);
        setAllOrdersForStaff(list);
      },
      () => {}
    );

    const unsubThreads = onSnapshot(
      query(collection(db, 'support_threads'), limit(40)),
      (snap) => {
        setAllSupportThreads(
          snap.docs
            .map((d) => {
              const m = d.data();
              return {
                id: d.id,
                userId: String(m.userId || ''),
                customerName: String(m.customerName || 'عميل'),
                customerPhone: String(m.customerPhone || ''),
                customerEmail: String(m.customerEmail || ''),
                lastMessage: String(m.lastMessage || ''),
                status: (m.status as 'open' | 'resolved') || 'open',
                updatedAt: toMillis(m.updatedAt),
              };
            })
            .sort((a, b) => b.updatedAt - a.updatedAt)
        );
      },
      () => {}
    );

    let unsubAudit: (() => void) | undefined;
    let unsubDeleted: (() => void) | undefined;
    let unsubInvites: (() => void) | undefined;

    if (isManager) {
      unsubAudit = onSnapshot(
        query(collection(db, 'audit_logs'), orderBy('createdAt', 'desc'), limit(60)),
        (snap) => {
          setAuditLogs(
            snap.docs.map((d) => {
              const m = d.data();
              return {
                id: d.id,
                action: String(m.action || ''),
                targetType: String(m.targetType || ''),
                targetId: String(m.targetId || ''),
                actorUid: String(m.actorUid || ''),
                actorName: String(m.actorName || ''),
                actorRole: String(m.actorRole || ''),
                details: String(m.details || ''),
                createdAt: toMillis(m.createdAt),
              };
            })
          );
        },
        () => {}
      );
      unsubDeleted = onSnapshot(
        query(collection(db, 'deleted_records'), orderBy('deletedAt', 'desc'), limit(50)),
        (snap) => {
          setDeletedRecords(
            snap.docs.map((d) => {
              const m = d.data();
              return {
                id: d.id,
                collection: String(m.collection || ''),
                originalId: String(m.originalId || ''),
                label: String(m.label || ''),
                reason: String(m.reason || ''),
                deletedByName: String(m.deletedByName || ''),
                deletedByUid: String(m.deletedByUid || ''),
                createdByName: m.createdByName ? String(m.createdByName) : undefined,
                snapshot: (m.snapshot as Record<string, unknown>) || {},
                deletedAt: toMillis(m.deletedAt),
              };
            })
          );
        },
        () => {}
      );
      unsubInvites = onSnapshot(
        collection(db, 'staff_invites'),
        (snap) => {
          setStaffInvites(
            snap.docs.map((d) => {
              const m = d.data();
              return {
                email: d.id,
                role: (m.role as StaffRole) || 'customer',
                name: m.name ? String(m.name) : '',
                active: m.active !== false,
                addedBy: m.addedBy ? String(m.addedBy) : '',
                updatedAt: toMillis(m.updatedAt),
              };
            })
          );
        },
        () => {}
      );
    }

    return () => {
      unsubAllOrders();
      unsubThreads();
      unsubAudit?.();
      unsubDeleted?.();
      unsubInvites?.();
    };
  }, [firebaseUid, isStaff, isManager]);

  // Customer support thread listener
  useEffect(() => {
    if (!firebaseUid) {
      setSupportThread(null);
      setSupportMessages([]);
      return;
    }
    const threadRef = doc(db, 'support_threads', firebaseUid);
    const unsubThread = onSnapshot(
      threadRef,
      (snap) => {
        if (snap.exists()) {
          const m = snap.data();
          setSupportThread({
            id: snap.id,
            userId: String(m.userId || firebaseUid),
            customerName: String(m.customerName || firebaseDisplayName),
            customerPhone: String(m.customerPhone || userPhone),
            customerEmail: String(m.customerEmail || firebaseEmail),
            lastMessage: String(m.lastMessage || ''),
            status: (m.status as 'open' | 'resolved') || 'open',
            updatedAt: toMillis(m.updatedAt),
          });
        }
      },
      () => {}
    );
    const unsubMsgs = onSnapshot(
      query(
        collection(db, 'support_threads', firebaseUid, 'messages'),
        orderBy('createdAt', 'asc'),
        limit(80)
      ),
      (snap) => {
        setSupportMessages(
          snap.docs.map((d) => {
            const m = d.data();
            return {
              id: d.id,
              senderUid: String(m.senderUid || ''),
              senderName: String(m.senderName || ''),
              isStaff: Boolean(m.isStaff),
              text: String(m.text || ''),
              createdAt: toMillis(m.createdAt),
            };
          })
        );
      },
      () => {}
    );
    return () => {
      unsubThread();
      unsubMsgs();
    };
  }, [firebaseUid, firebaseDisplayName, firebaseEmail, userPhone]);

  // Actions
  const signInGoogle = async (loginHint?: string) => {
    try {
      await signInWithGoogleAccount(loginHint);
      notifyToast(
        language === 'ar' ? 'تم تسجيل الدخول بنجاح' : 'Signed in successfully',
        'success'
      );
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'تعذر تسجيل الدخول عبر Google';
      notifyToast(msg, 'error');
    }
  };

  const signOutUser = async () => {
    await signOutFirebase();
    notifyToast(language === 'ar' ? 'تم تسجيل الخروج' : 'Signed out', 'info');
  };

  const removeSavedAccount = (uid: string) => {
    setSavedAccounts((prev) => prev.filter((a) => a.uid !== uid));
  };

  const toggleFollowProduct = (goodsIdOrId: string) => {
    setFollowedProductIds((prev) => {
      const exists = prev.includes(goodsIdOrId);
      const next = exists ? prev.filter((x) => x !== goodsIdOrId) : [...prev, goodsIdOrId];
      notifyToast(
        exists
          ? 'تم إلغاء متابعة المنتج'
          : 'تمت متابعة المنتج — ستصلك إشعارات فورية عند أي خصم أو انخفاض بالسعر',
        exists ? 'info' : 'success'
      );
      return next;
    });
  };

  const cartAgeHours = useMemo(() => {
    if (cart.length === 0) return 0;
    return Math.max(0, Math.floor((Date.now() - cartUpdatedAt) / (1000 * 60 * 60)));
  }, [cart.length, cartUpdatedAt]);

  const isCartAbandoned24h = useMemo(() => {
    if (cart.length === 0) return false;
    const elapsedMs = Date.now() - cartUpdatedAt;
    const dismissedRecently = Date.now() - cartReminderDismissedAt < 12 * 60 * 60 * 1000;
    return elapsedMs >= 24 * 60 * 60 * 1000 && !dismissedRecently;
  }, [cart.length, cartUpdatedAt, cartReminderDismissedAt]);

  const dismissCartReminder = () => {
    const now = Date.now();
    setCartReminderDismissedAt(now);
    localStorage.setItem(LS_KEYS.cartReminderDismissedAt, String(now));
  };

  const touchCartTimestamp = () => {
    const now = Date.now();
    setCartUpdatedAt(now);
    localStorage.setItem(LS_KEYS.cartUpdatedAt, String(now));
  };

  const addToCart = (item: Omit<CartItem, 'id'>) => {
    touchCartTimestamp();
    setCart((prev) => {
      const existingIdx = prev.findIndex(
        (c) =>
          c.goodsId === item.goodsId &&
          c.color === item.color &&
          c.size === item.size
      );
      if (existingIdx >= 0) {
        const copy = [...prev];
        copy[existingIdx] = {
          ...copy[existingIdx],
          qty: Math.min(99, copy[existingIdx].qty + Math.max(1, item.qty)),
          unitPriceSar: item.unitPriceSar,
          verifiedAt: Date.now(),
        };
        return copy;
      }
      const id = `${item.goodsId}_${Date.now()}_${Math.floor(Math.random() * 999)}`;
      return [...prev, { ...item, id, verifiedAt: Date.now() }];
    });
    notifyToast(
      language === 'ar' ? `تمت إضافة «${item.title.slice(0, 28)}» إلى السلة` : 'Added to bag',
      'success'
    );
  };

  const updateCartQty = (id: string, delta: number) => {
    touchCartTimestamp();
    setCart((prev) =>
      prev
        .map((c) => (c.id === id ? { ...c, qty: c.qty + delta } : c))
        .filter((c) => c.qty > 0)
    );
  };

  const removeFromCart = (id: string) => {
    touchCartTimestamp();
    setCart((prev) => prev.filter((c) => c.id !== id));
  };

  const clearCart = () => setCart([]);

  const updateCartItemPrice = (id: string, newPriceSar: number) => {
    setCart((prev) =>
      prev.map((c) =>
        c.id === id
          ? {
              ...c,
              previousPriceSar: c.unitPriceSar,
              unitPriceSar: newPriceSar,
              verifiedAt: Date.now(),
              stockStatus: 'available',
            }
          : c
      )
    );
  };

  const updateCartItemVariant: SelooContextValue['updateCartItemVariant'] = (id, patch) => {
    touchCartTimestamp();
    setCart((prev) =>
      prev.map((c) => {
        if (c.id !== id) return c;
        const nextPrice =
          typeof patch.unitPriceSar === 'number' ? patch.unitPriceSar : c.unitPriceSar;
        return {
          ...c,
          color: patch.color ?? c.color,
          size: patch.size ?? c.size,
          imageUrl: patch.imageUrl ?? c.imageUrl,
          previousPriceSar: nextPrice !== c.unitPriceSar ? c.unitPriceSar : c.previousPriceSar,
          unitPriceSar: nextPrice,
          verifiedAt: Date.now(),
        };
      })
    );
  };

  const updateOrderAddress = async (orderId: string, address: Address) => {
    try {
      await updateDoc(doc(db, 'orders', orderId), {
        address,
        receiverName: address.receiverName,
        receiverPhone: address.phone,
        shippingGovernorate: address.city,
        updatedAt: serverTimestamp(),
      });
    } catch {
      // Allow UI update locally if Firestore rules restrict order edit after review
    }
    setActiveOrderForPayment((prev) =>
      prev && prev.id === orderId
        ? {
            ...prev,
            address,
            receiverName: address.receiverName,
            receiverPhone: address.phone,
            shippingGovernorate: address.city,
          }
        : prev
    );
    await saveAddress(address);
    notifyToast('تم تحديث عنوان التوصيل في الطلب بنجاح', 'success');
  };

  const saveAddress = async (addr: Address) => {
    const cleanId = addr.id || `addr_${Date.now()}`;
    const fullAddr = { ...addr, id: cleanId };
    setSavedAddresses((prev) => {
      const rest = prev.filter((a) => a.id !== cleanId);
      return [fullAddr, ...rest];
    });
    setSelectedAddressId(cleanId);
    if (firebaseUid) {
      try {
        await setDoc(doc(db, 'users', firebaseUid, 'addresses', cleanId), fullAddr, {
          merge: true,
        });
        await setDoc(
          doc(db, 'users', firebaseUid),
          { phone: addr.phone, defaultCity: addr.city, updatedAt: serverTimestamp() },
          { merge: true }
        );
      } catch {
        // Saved locally even if rules fail
      }
    }
    notifyToast('تم حفظ العنوان بنجاح', 'success');
  };

  const deleteAddress = async (id: string) => {
    setSavedAddresses((prev) => prev.filter((a) => a.id !== id));
    if (firebaseUid) {
      try {
        await deleteDoc(doc(db, 'users', firebaseUid, 'addresses', id));
      } catch {
        // ignore
      }
    }
  };

  const pushCustomerNotification = async (
    targetUid: string,
    payload: Omit<NotificationItem, 'id' | 'read' | 'createdAt'>
  ) => {
    if (!targetUid) return;
    try {
      await addDoc(collection(db, 'notifications', targetUid, 'items'), {
        ...payload,
        read: false,
        createdAt: serverTimestamp(),
      });
    } catch {
      // non-blocking
    }
  };

  const recordAuditLog = async (
    action: string,
    targetType: string,
    targetId: string,
    details: string
  ) => {
    if (!firebaseUid || !isStaff) return;
    try {
      await addDoc(collection(db, 'audit_logs'), {
        action,
        targetType,
        targetId,
        actorUid: firebaseUid,
        actorName: firebaseDisplayName,
        actorRole: effectiveRole,
        details,
        createdAt: serverTimestamp(),
      });
    } catch {
      // non-blocking
    }
  };

  const createOrder: SelooContextValue['createOrder'] = async ({
    address,
    shippingMode,
    shippingGovernorate,
    shippingOffice,
    shippingOfficeChoice,
    driverName,
    driverPhone,
    driverMeetPoint,
    paymentPlan,
    couponCode,
    discountSar,
  }) => {
    if (!firebaseUid) {
      notifyToast('يرجى تسجيل الدخول بحساب Google أولاً لرفع الطلب', 'error');
      return null;
    }
    if (cart.length === 0) {
      notifyToast('السلة فارغة', 'error');
      return null;
    }

    const totals = computeCartTotals(
      cart,
      settings,
      currency,
      discountSar,
      shippingMode
    );
    const lockedRate = rateForCurrency(currency, settings);
    const chosenPlan =
      paymentPlan === 'half_deferred' && totals.canDeferred
        ? 'half_deferred'
        : 'full';
    const upfrontDueLocal =
      chosenPlan === 'half_deferred' ? totals.upfrontLocal : totals.totalLocal;
    const remainingLocal =
      chosenPlan === 'half_deferred'
        ? Math.max(0, totals.totalLocal - upfrontDueLocal)
        : 0;

    // Clean sequential Order No via Firestore counter (no random -95 suffix!)
    let nextSeq = Math.floor(1000 + (Date.now() % 9000));
    try {
      const counterRef = doc(db, 'counters', 'orders');
      nextSeq = await runTransaction(db, async (tx) => {
        const snap = await tx.get(counterRef);
        const curr = snap.exists() ? Number(snap.data().value || 1000) : 1000;
        const next = curr + 1;
        tx.set(counterRef, { value: next }, { merge: true });
        return next;
      });
    } catch {
      // clean numeric fallback without extra hyphen suffix
    }
    const orderNo = `YS${nextSeq}`;
    const deliveryPin = String(Math.floor(1000 + Math.random() * 9000));
    const nowMs = Date.now();

    const orderDocRef = doc(collection(db, 'orders'));
    const newOrder: Order = {
      id: orderDocRef.id,
      orderNo,
      userId: firebaseUid,
      customerName: firebaseDisplayName,
      customerEmail: firebaseEmail,
      currency,
      exchangeRate: lockedRate,
      usdRateNorth: settings.usdRateNorth,
      usdRateSouth: settings.usdRateSouth,
      sarPerUsd: settings.sarPerUsd,
      items: cart.map((c) => ({
        goodsId: c.goodsId,
        sku: c.sku || c.goodsId,
        title: c.title,
        imageUrl: c.imageUrl,
        size: c.size,
        color: c.color,
        qty: c.qty,
        unitPriceSar: c.unitPriceSar,
        productUrl: c.productUrl,
        nonRefundable: c.nonRefundable,
        nonRefundableReason: c.nonRefundableReason,
      })),
      subtotalSar: totals.subtotalSar,
      shippingFeeSar: totals.shippingFeeSar,
      deliveryFeeSar: totals.deliveryFeeSar,
      serviceFeeSar: totals.serviceFeeSar,
      discountSar,
      totalSar: totals.totalSar,
      totalLocal: totals.totalLocal,
      paymentPlan: chosenPlan,
      upfrontDueLocal,
      paidTotalLocal: 0,
      remainingLocal: totals.totalLocal,
      couponCode,
      address,
      status: OrderStatus.unpaid,
      timeline: [
        {
          status: OrderStatus.unpaid,
          at: nowMs,
          byName: firebaseDisplayName,
          note: 'تم إنشاء الطلب وبانتظار إرسال الحوالة واستمارة التأكيد',
        },
      ],
      payment: {
        accountId: '',
        accountTitleAr: '',
        accountNumber: '',
        amount: 0,
        senderName: '',
        refNo: '',
        note: '',
        proofUrl: '',
        creditLocal: 0,
        confirmedByName: '',
      },
      shippingMode,
      shippingGovernorate,
      shippingOffice,
      shippingOfficeChoice,
      receiverName: address.receiverName,
      receiverPhone: address.phone,
      driverName,
      driverPhone,
      driverMeetPoint,
      trackingNo: '',
      trackingUrl: '',
      trackingImageUrl: '',
      courierName: '',
      proofImageUrl: '',
      shippingStage: ShippingMilestone.preparing,
      shippingStageNote: '',
      whatsappSentTarget: '',
      orderSummaryImageUrl: '',
      priceSyncStatus: '',
      priceSyncNote: '',
      proposedTotalSar: 0,
      proposedTotalLocal: 0,
      proposedItems: [],
      replacementStatus: '',
      customerSignatureUrl: '',
      signedByName: '',
      deliveryPin,
      deliverySigned: false,
      deliveryPinVerified: false,
      refunds: [],
      refundedTotalSar: 0,
      editingLocked: false,
      approvedByName: '',
      deliveryMinDays: settings.deliveryMinDays,
      deliveryMaxDays: settings.deliveryMaxDays,
      createdAt: nowMs,
      updatedAt: nowMs,
    };

    try {
      await setDoc(orderDocRef, {
        ...newOrder,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'order_numbers', orderNo), {
        userId: firebaseUid,
        orderId: orderDocRef.id,
        createdAt: serverTimestamp(),
      });
      await pushCustomerNotification(firebaseUid, {
        title: `تم إنشاء الطلب ${orderNo}`,
        body: `المطلوب الآن ${upfrontDueLocal.toLocaleString('en-US')} — أرسل الحوالة واستمارة الواتساب لتأكيد الطلب.`,
        type: 'order',
        orderId: orderDocRef.id,
      });
      clearCart();
      setActiveOrderForPayment(newOrder);
      notifyToast(`تم رفع الطلب ${orderNo} بنجاح!`, 'success');
      return newOrder;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'تعذر حفظ الطلب في Firestore';
      notifyToast(msg, 'error');
      return null;
    }
  };

  const submitOrderPayment = async (orderId: string, payment: PaymentInfo) => {
    const orderRef = doc(db, 'orders', orderId);
    const snap = await getDoc(orderRef);
    const existing = snap.exists() ? mapOrderDoc(snap.id, snap.data()) : activeOrderForPayment;
    const timeline = [
      ...(existing?.timeline || []),
      {
        status: OrderStatus.verifying,
        at: Date.now(),
        byName: firebaseDisplayName || payment.senderName,
        note: `تم إرفاق الحوالة (${payment.accountTitleAr}) بقيمة ${payment.amount}`,
      },
    ];
    await updateDoc(orderRef, {
      status: OrderStatus.verifying,
      payment: { ...payment, submittedAt: Date.now() },
      proofImageUrl: payment.proofUrl,
      timeline,
      updatedAt: serverTimestamp(),
    });
    if (firebaseUid) {
      await pushCustomerNotification(firebaseUid, {
        title: `تم استلام حوالة الطلب ${existing?.orderNo || ''}`,
        body: 'الطلب الآن قيد المراجعة المحاسبية، أرسل استمارة التأكيد عبر واتساب لإسراع التجهيز.',
        type: 'payment',
        orderId,
      });
    }
    notifyToast('تم رفع بيانات وصورة الحوالة بنجاح', 'success');
  };

  const recordWhatsAppSubmission = async (
    orderId: string,
    targetPhone: string,
    summaryImageUrl: string
  ) => {
    await updateDoc(doc(db, 'orders', orderId), {
      whatsappSentAt: serverTimestamp(),
      whatsappSentTarget: targetPhone,
      orderSummaryImageUrl: summaryImageUrl,
      updatedAt: serverTimestamp(),
    });
  };

  const respondPriceSync = async (orderId: string, accept: boolean) => {
    const orderRef = doc(db, 'orders', orderId);
    await updateDoc(orderRef, {
      priceSyncStatus: accept ? 'accepted' : 'rejected',
      priceSyncDecision: accept ? 'accepted' : 'rejected',
      priceSyncRespondedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    notifyToast(
      accept
        ? 'تم إرسال موافقتك على التحديث الجديد للسعر'
        : 'تم تسجيل رفضك لتغيير السعر وسيراجعك فريق الدعم',
      accept ? 'success' : 'info'
    );
  };

  const submitReplacementProposal: SelooContextValue['submitReplacementProposal'] = async (
    orderId,
    replacement
  ) => {
    const orderRef = doc(db, 'orders', orderId);
    const snap = await getDoc(orderRef);
    if (!snap.exists()) return;
    const ord = mapOrderDoc(snap.id, snap.data());
    const targetPrice = ord.replacementProposal?.targetItemPriceSar || 0;
    const diffSar = replacement.priceSar - targetPrice;
    const diffLocal = convertSarToCurrency(Math.abs(diffSar), ord.currency, {
      ...settings,
      rateNorth: ord.currency === 'north' ? ord.exchangeRate : settings.rateNorth,
      rateSouth: ord.currency === 'south' ? ord.exchangeRate : settings.rateSouth,
    });

    let settlementNote = 'نفس القيمة — لا يوجد فرق مالي';
    if (diffSar > 0.01) {
      settlementNote = `قيمة أعلى بـ ${diffSar.toFixed(2)} ر.س (${diffLocal.toLocaleString('en-US')}) تُضاف للمتبقي أو الفارق`;
    } else if (diffSar < -0.01) {
      settlementNote =
        ord.paymentPlan === 'half_deferred'
          ? `قيمة أقل بـ ${Math.abs(diffSar).toFixed(2)} ر.س — يُخصم تلقائياً من المتبقي في الطلب الآجل`
          : `قيمة أقل بـ ${Math.abs(diffSar).toFixed(2)} ر.س — يُضاف رصيداً لمحفظتك بعد الاعتماد`;
    }

    await updateDoc(orderRef, {
      replacementStatus: 'pending_admin',
      replacementProposal: {
        ...ord.replacementProposal,
        replacementTitle: replacement.title,
        replacementUrl: replacement.url,
        replacementImageUrl: replacement.imageUrl || '',
        replacementPriceSar: replacement.priceSar,
        diffSar,
        settlementNote,
        submittedAt: Date.now(),
      },
      replacementSubmittedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    notifyToast('تم إرسال القطعة البديلة للإدارة للمراجعة والاعتماد', 'success');
  };

  const submitElectronicSignature = async (
    orderId: string,
    signatureDataUrl: string,
    pinInput: string
  ) => {
    const orderRef = doc(db, 'orders', orderId);
    const snap = await getDoc(orderRef);
    if (!snap.exists()) return;
    const ord = mapOrderDoc(snap.id, snap.data());
    if (ord.deliveryPin && pinInput.trim() !== ord.deliveryPin.trim()) {
      notifyToast('كود التحقق المكون من 4 أرقام غير صحيح', 'error');
      return;
    }
    await updateDoc(orderRef, {
      customerSignatureUrl: signatureDataUrl,
      signedAt: serverTimestamp(),
      signedByUid: firebaseUid,
      signedByName: firebaseDisplayName || ord.receiverName,
      deliverySigned: true,
      deliveryPinVerified: true,
      shippingStage: ShippingMilestone.delivered,
      status: OrderStatus.delivered,
      timeline: [
        ...ord.timeline,
        {
          status: OrderStatus.delivered,
          at: Date.now(),
          byName: firebaseDisplayName || ord.receiverName,
          note: 'تم توثيق الاستلام بالتوقيع الإلكتروني وكود التحقق ✅',
        },
      ],
      updatedAt: serverTimestamp(),
    });
    notifyToast('تم توثيق الاستلام والتوقيع الإلكتروني بنجاح ✅', 'success');
  };

  const submitOrderReceipt: SelooContextValue['submitOrderReceipt'] = async (
    order,
    payload
  ) => {
    if (!firebaseUid) return;
    const receiptNo = `RC-${Date.now().toString().slice(-6)}`;
    const amountSar =
      order.exchangeRate > 0 ? payload.amountLocal / order.exchangeRate : 0;
    await addDoc(collection(db, 'orders', order.id, 'receipts'), {
      receiptNo,
      orderId: order.id,
      orderNo: order.orderNo,
      customerId: firebaseUid,
      status: 'pending',
      source: 'customer',
      amountLocal: payload.amountLocal,
      amountSar,
      senderName: payload.senderName.trim(),
      refNo: payload.refNo.trim(),
      note: payload.note.trim(),
      proofUrl: payload.proofUrl,
      createdAt: serverTimestamp(),
    });
    notifyToast(`تم رفع الإيصال ${receiptNo} للمراجعة المحاسبية`, 'success');
  };

  const reviewOrderReceipt: SelooContextValue['reviewOrderReceipt'] = async (
    receipt,
    approve,
    rejectReason = ''
  ) => {
    await updateDoc(doc(db, 'orders', receipt.orderId, 'receipts', receipt.id), {
      status: approve ? 'approved' : 'rejected',
      reviewedBy: firebaseDisplayName,
      rejectReason: approve ? '' : rejectReason,
      reviewedAt: serverTimestamp(),
    });
    if (approve) {
      const ordSnap = await getDoc(doc(db, 'orders', receipt.orderId));
      if (ordSnap.exists()) {
        const ord = mapOrderDoc(ordSnap.id, ordSnap.data());
        const nextPaid = ord.paidTotalLocal + receipt.amountLocal;
        const nextRem = Math.max(0, ord.totalLocal - nextPaid);
        await updateDoc(doc(db, 'orders', receipt.orderId), {
          paidTotalLocal: nextPaid,
          remainingLocal: nextRem,
          status:
            ord.status === OrderStatus.unpaid || ord.status === OrderStatus.verifying
              ? OrderStatus.processing
              : ord.status,
          updatedAt: serverTimestamp(),
        });
      }
    }
    await recordAuditLog(
      approve ? 'اعتماد إيصال' : 'رفض إيصال',
      'receipt',
      receipt.receiptNo,
      `${receipt.orderNo} — ${receipt.amountLocal}`
    );
    notifyToast(approve ? 'تم اعتماد الإيصال وتقييد الرصيد' : 'تم رفض الإيصال', 'info');
  };

  const requestWalletWithdrawal = async (
    amountSar: number,
    bankOrWallet: string,
    accountNo: string
  ) => {
    if (!firebaseUid) return;
    if (amountSar <= 0 || amountSar > wallet.balanceSar) {
      notifyToast('المبلغ غير صالح أو يتجاوز رصيد المحفظة المتاح', 'error');
      return;
    }
    await addDoc(collection(db, 'wallet_requests'), {
      userId: firebaseUid,
      customerName: firebaseDisplayName,
      amountSar,
      bankOrWallet,
      accountNo,
      status: 'pending',
      createdAt: serverTimestamp(),
    });
    notifyToast('تم إرسال طلب سحب الرصيد للمحاسبة', 'success');
  };

  const submitRefundRequest: SelooContextValue['submitRefundRequest'] = async (
    orderId,
    req
  ) => {
    const orderRef = doc(db, 'orders', orderId);
    const snap = await getDoc(orderRef);
    if (!snap.exists()) return;
    const ord = mapOrderDoc(snap.id, snap.data());
    const hasNonRefundable = ord.items.some((i) => i.nonRefundable);
    if (hasNonRefundable && req.reasonType === 'other') {
      notifyToast(
        'الطلب يحتوي على قطع غير قابلة للاسترداد؛ يُقبل الاسترجاع فقط عند التلف أو خطأ القطعة',
        'error'
      );
      return;
    }
    const newRec: RefundRecord = {
      ...req,
      id: `ref_${Date.now()}`,
      status: 'pending',
      createdAt: Date.now(),
    };
    await updateDoc(orderRef, {
      refunds: [...ord.refunds, newRec],
      updatedAt: serverTimestamp(),
    });
    notifyToast('تم رفع طلب الاسترداد للمراجعة', 'success');
  };

  const markNotificationRead = async (id: string) => {
    if (!firebaseUid) return;
    try {
      await updateDoc(doc(db, 'notifications', firebaseUid, 'items', id), {
        read: true,
      });
    } catch {
      // ignore
    }
  };

  const markAllNotificationsRead = async () => {
    if (!firebaseUid) return;
    const unread = notifications.filter((n) => !n.read);
    await Promise.all(unread.map((n) => markNotificationRead(n.id)));
  };

  const sendSupportMessage = async (text: string, targetThreadId?: string) => {
    if (!firebaseUid || !text.trim()) return;
    const threadId = targetThreadId || firebaseUid;
    const threadRef = doc(db, 'support_threads', threadId);
    const actingAsStaff = Boolean(targetThreadId && isStaff);
    await setDoc(
      threadRef,
      {
        userId: threadId,
        customerName: actingAsStaff ? undefined : firebaseDisplayName,
        customerEmail: actingAsStaff ? undefined : firebaseEmail,
        customerPhone: actingAsStaff ? undefined : userPhone,
        lastMessage: text.trim(),
        status: 'open',
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );
    await addDoc(collection(db, 'support_threads', threadId, 'messages'), {
      senderUid: firebaseUid,
      senderName: firebaseDisplayName,
      isStaff: actingAsStaff,
      text: text.trim(),
      createdAt: serverTimestamp(),
    });
  };

  // Staff & Manager actions
  const saveAppSettings = async (next: AppSettings) => {
    await setDoc(doc(db, 'settings', 'app'), next, { merge: true });
    await recordAuditLog(
      'تحديث إعدادات الصرف والرسوم',
      'settings',
      'app',
      `شمال: ${next.rateNorth} | جنوب: ${next.rateSouth} | دولار شمال: ${next.usdRateNorth} | دولار جنوب: ${next.usdRateSouth}`
    );
    notifyToast('تم تحديث الأسعار والإعدادات لحظياً لجميع المستخدمين', 'success');
  };

  const notifyMarketerDiscount = async (
    title: string,
    oldPriceSar: number,
    newPriceSar: number,
    sourceUrl?: string
  ) => {
    const pct =
      oldPriceSar > 0
        ? Math.max(1, Math.round(((oldPriceSar - newPriceSar) / oldPriceSar) * 100))
        : 0;
    const msg = `انخفض سعر «${title.slice(0, 38)}» من ${oldPriceSar.toFixed(
      2
    )} إلى ${newPriceSar.toFixed(2)} SAR (-${pct}%)`;
    notifyToast(`🔥 تنبيه خصم للمسوّق والمتابعين: ${msg}`, 'success');
    if (firebaseUid) {
      await pushCustomerNotification(firebaseUid, {
        title: `تخفيض سعر بنسبة ${pct}%`,
        body: sourceUrl ? `${msg} — جاهز للترويج` : msg,
        type: 'alert',
      });
    }
  };

  const upsertCatalogItem = async (item: Omit<CatalogItem, 'id'>, id?: string) => {
    const prevMatch = id
      ? catalog.find((c) => c.id === id)
      : catalog.find((c) => c.goodsId === item.goodsId);
    const prevTotal = prevMatch ? prevMatch.basePriceSar + prevMatch.marginSar : 0;
    const nextTotal = item.basePriceSar + item.marginSar;

    if (id) {
      await setDoc(
        doc(db, 'catalog', id),
        { ...item, updatedAt: serverTimestamp() },
        { merge: true }
      );
      await recordAuditLog('تعديل منتج كتالوج', 'catalog', id, item.title);
      notifyToast('تم تحديث المنتج في الكتالوج', 'success');
    } else {
      const ref = await addDoc(collection(db, 'catalog'), {
        ...item,
        createdAt: serverTimestamp(),
      });
      await recordAuditLog('إضافة منتج كتالوج', 'catalog', ref.id, item.title);
      notifyToast('تم نشر المنتج في كتالوج يمن سيلو', 'success');
    }

    if (prevMatch && nextTotal < prevTotal - 0.1) {
      await notifyMarketerDiscount(item.title, prevTotal, nextTotal, item.sourceUrl);
    }
  };

  const deleteCatalogItem = async (item: CatalogItem, reason: string) => {
    await addDoc(collection(db, 'deleted_records'), {
      collection: 'catalog',
      originalId: item.id,
      label: item.title,
      reason: reason || 'حذف من الكتالوج بواسطة المدير',
      deletedByName: firebaseDisplayName,
      deletedByUid: firebaseUid,
      snapshot: { title: item.title, basePriceSar: item.basePriceSar, goodsId: item.goodsId },
      deletedAt: serverTimestamp(),
    });
    await deleteDoc(doc(db, 'catalog', item.id));
    await recordAuditLog('حذف منتج كتالوج', 'catalog', item.id, `${item.title} — ${reason}`);
    notifyToast('تم نقل المنتج إلى سجل المحذوفات والتدقيق', 'info');
  };

  const staffUpdateOrder: SelooContextValue['staffUpdateOrder'] = async (
    orderId,
    patch,
    auditAction
  ) => {
    const orderRef = doc(db, 'orders', orderId);
    const snap = await getDoc(orderRef);
    if (!snap.exists()) return;
    const ord = mapOrderDoc(snap.id, snap.data());
    const nextTimeline = [...ord.timeline];
    if (patch.note || patch.status) {
      nextTimeline.push({
        status: patch.status || ord.status,
        at: Date.now(),
        byName: firebaseDisplayName,
        note: patch.note || auditAction,
      });
    }
    const { note: _omitNote, ...cleanPatch } = patch;
    await updateDoc(orderRef, {
      ...cleanPatch,
      timeline: nextTimeline,
      updatedAt: serverTimestamp(),
    });
    await recordAuditLog(auditAction, 'order', ord.orderNo, patch.note || auditAction);
    await pushCustomerNotification(ord.userId, {
      title: `تحديث على الطلب ${ord.orderNo}`,
      body: patch.note || auditAction,
      type: patch.shippingStage ? 'shipping' : 'order',
      orderId,
    });
    notifyToast('تم تحديث الطلب وإبلاغ العميل', 'success');
  };

  const managerArchiveDeleteOrder = async (order: Order, reason: string) => {
    if (!isManager) return;
    await addDoc(collection(db, 'deleted_records'), {
      collection: 'orders',
      originalId: order.id,
      label: `${order.orderNo} — ${order.receiverName || order.customerName || ''}`,
      reason: reason || 'حذف إداري من المدير',
      deletedByName: firebaseDisplayName,
      deletedByUid: firebaseUid,
      createdByName: order.approvedByName || order.customerName || 'العميل',
      snapshot: {
        orderNo: order.orderNo,
        totalSar: order.totalSar,
        totalLocal: order.totalLocal,
        currency: order.currency,
        status: order.status,
      },
      deletedAt: serverTimestamp(),
    });
    await deleteDoc(doc(db, 'orders', order.id));
    await recordAuditLog(
      'حذف طلب وأرشفته',
      'order',
      order.orderNo,
      `السبب: ${reason || 'بدون سبب'}`
    );
    notifyToast(`تم حذف وأرشفة الطلب ${order.orderNo} في سجل المحذوفات`, 'info');
  };

  const saveCheckoutAlert: SelooContextValue['saveCheckoutAlert'] = async (alert, id) => {
    const payload = {
      ...alert,
      createdByName: firebaseDisplayName,
      createdAt: serverTimestamp(),
    };
    if (id) {
      await setDoc(doc(db, 'checkout_alerts', id), payload, { merge: true });
    } else {
      await addDoc(collection(db, 'checkout_alerts'), payload);
    }
    await recordAuditLog('تحديث تنبيه صفحة الدفع', 'checkout_alerts', id || 'new', alert.title);
    notifyToast('تم نشر تنبيه صفحة الدفع للعملاء', 'success');
  };

  const deleteCheckoutAlert = async (id: string) => {
    await deleteDoc(doc(db, 'checkout_alerts', id));
    notifyToast('تم إزالة التنبيه', 'info');
  };

  const saveStaffInvite = async (invite: StaffInvite) => {
    const emailKey = invite.email.trim().toLowerCase();
    await setDoc(
      doc(db, 'staff_invites', emailKey),
      {
        role: invite.role,
        name: invite.name || '',
        active: invite.active,
        addedBy: firebaseDisplayName,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );
    await recordAuditLog('تعيين دور موظف', 'staff_invites', emailKey, invite.role);
    notifyToast(`تم حفظ صلاحية ${emailKey}`, 'success');
  };

  const removeStaffInvite = async (email: string) => {
    const emailKey = email.trim().toLowerCase();
    await setDoc(
      doc(db, 'staff_invites', emailKey),
      { active: false, role: 'customer', updatedAt: serverTimestamp() },
      { merge: true }
    );
    await recordAuditLog('سحب صلاحية موظف', 'staff_invites', emailKey, 'revoked');
    notifyToast(`تم سحب صلاحية ${emailKey} فوراً`, 'info');
  };

  const unreadNotificationsCount = useMemo(
    () => notifications.filter((n) => !n.read).length,
    [notifications]
  );

  return (
    <SelooContext.Provider
      value={{
        theme,
        toggleTheme,
        language,
        setLanguage,
        t,
        currency,
        setCurrency,
        currencyModalOpen,
        setCurrencyModalOpen,
        activeTab,
        setActiveTab,
        settings,
        catalog,
        catalogLoading,
        followedProductIds,
        toggleFollowProduct,
        deepLinkedProductId,
        clearDeepLinkedProduct,
        cart,
        isCartAbandoned24h,
        cartAgeHours,
        dismissCartReminder,
        addToCart,
        updateCartQty,
        removeFromCart,
        clearCart,
        updateCartItemPrice,
        updateCartItemVariant,
        updateOrderAddress,
        notifyMarketerDiscount,
        user,
        authLoading,
        effectiveRole,
        isStaff,
        isManager,
        savedAccounts,
        signInGoogle,
        signOutUser,
        removeSavedAccount,
        savedAddresses,
        selectedAddressId,
        setSelectedAddressId,
        saveAddress,
        deleteAddress,
        orders,
        ordersLoading,
        activeOrderForPayment,
        setActiveOrderForPayment,
        selectedOrderId,
        setSelectedOrderId,
        checkoutAlerts,
        notifications,
        unreadNotificationsCount,
        markNotificationRead,
        markAllNotificationsRead,
        supportThread,
        supportMessages,
        allSupportThreads,
        sendSupportMessage,
        auditLogs,
        deletedRecords,
        staffInvites,
        allOrdersForStaff,
        wallet,
        orderReceipts,
        toasts,
        notifyToast,
        submitOrderReceipt,
        reviewOrderReceipt,
        requestWalletWithdrawal,
        createOrder,
        submitOrderPayment,
        recordWhatsAppSubmission,
        respondPriceSync,
        submitReplacementProposal,
        submitElectronicSignature,
        submitRefundRequest,
        saveAppSettings,
        upsertCatalogItem,
        deleteCatalogItem,
        staffUpdateOrder,
        managerArchiveDeleteOrder,
        saveCheckoutAlert,
        deleteCheckoutAlert,
        saveStaffInvite,
        removeStaffInvite,
        pushCustomerNotification,
      }}
    >
      {children}
    </SelooContext.Provider>
  );
};

function mapOrderDoc(id: string, m: Record<string, unknown>): Order {
  const status = (m.status as OrderStatus) || OrderStatus.unpaid;
  const rawAddr = (m.address as Partial<Address>) || {};
  const rawPay = (m.payment as Partial<PaymentInfo>) || {};
  const timelineRaw = Array.isArray(m.timeline) ? m.timeline : [];

  return {
    id,
    orderNo: String(m.orderNo || id.slice(0, 8).toUpperCase()),
    userId: String(m.userId || ''),
    customerName: m.customerName ? String(m.customerName) : '',
    customerEmail: m.customerEmail ? String(m.customerEmail) : '',
    currency: (m.currency as AppCurrency) || 'south',
    exchangeRate: Number(m.exchangeRate || 1),
    usdRateNorth: Number(m.usdRateNorth || 533),
    usdRateSouth: Number(m.usdRateSouth || 1570),
    sarPerUsd: Number(m.sarPerUsd || 3.75),
    items: Array.isArray(m.items) ? (m.items as Order['items']) : [],
    subtotalSar: Number(m.subtotalSar || 0),
    shippingFeeSar: Number(m.shippingFeeSar || 0),
    deliveryFeeSar: Number(m.deliveryFeeSar || 0),
    serviceFeeSar: Number(m.serviceFeeSar || 0),
    discountSar: Number(m.discountSar || 0),
    totalSar: Number(m.totalSar || 0),
    totalLocal: Number(m.totalLocal || 0),
    paymentPlan: (m.paymentPlan as 'full' | 'half_deferred') || 'full',
    upfrontDueLocal: Number(m.upfrontDueLocal || m.totalLocal || 0),
    paidTotalLocal: Number(m.paidTotalLocal || 0),
    remainingLocal: Number(m.remainingLocal ?? m.totalLocal ?? 0),
    couponCode: String(m.couponCode || ''),
    address: {
      id: String(rawAddr.id || ''),
      label: String(rawAddr.label || 'العنوان'),
      city: String(rawAddr.city || m.shippingGovernorate || 'صنعاء'),
      district: rawAddr.district ? String(rawAddr.district) : '',
      line: String(rawAddr.line || ''),
      phone: String(rawAddr.phone || m.receiverPhone || ''),
      receiverName: String(rawAddr.receiverName || m.receiverName || ''),
    },
    status,
    timeline: timelineRaw.map((t: Record<string, unknown>) => ({
      status: (t.status as OrderStatus) || status,
      at: toMillis(t.at),
      byName: String(t.byName || ''),
      note: String(t.note || ''),
    })),
    payment: {
      accountId: String(rawPay.accountId || ''),
      accountTitleAr: String(rawPay.accountTitleAr || ''),
      accountNumber: String(rawPay.accountNumber || ''),
      amount: Number(rawPay.amount || 0),
      senderName: String(rawPay.senderName || ''),
      refNo: String(rawPay.refNo || ''),
      note: String(rawPay.note || ''),
      proofUrl: String(rawPay.proofUrl || m.proofImageUrl || ''),
      creditLocal: Number(rawPay.creditLocal || 0),
      submittedAt: rawPay.submittedAt ? toMillis(rawPay.submittedAt) : undefined,
      confirmedAt: rawPay.confirmedAt ? toMillis(rawPay.confirmedAt) : undefined,
      confirmedByName: String(rawPay.confirmedByName || ''),
    },
    shippingMode: (m.shippingMode as 'office' | 'driver' | 'pickup') || 'office',
    shippingGovernorate: String(m.shippingGovernorate || rawAddr.city || ''),
    shippingOffice: String(m.shippingOffice || ''),
    shippingOfficeChoice: String(m.shippingOfficeChoice || ''),
    receiverName: String(m.receiverName || rawAddr.receiverName || ''),
    receiverPhone: String(m.receiverPhone || rawAddr.phone || ''),
    driverName: String(m.driverName || ''),
    driverPhone: String(m.driverPhone || ''),
    driverMeetPoint: String(m.driverMeetPoint || ''),
    trackingNo: String(m.trackingNo || ''),
    trackingUrl: String(m.trackingUrl || ''),
    trackingImageUrl: String(m.trackingImageUrl || ''),
    courierName: String(m.courierName || ''),
    courierPhone: m.courierPhone ? String(m.courierPhone) : '',
    proofImageUrl: String(m.proofImageUrl || ''),
    shippingStage: inferMilestoneFromOrder(status, m.shippingStage as ShippingMilestone | undefined),
    shippingStageNote: String(m.shippingStageNote || ''),
    shippingStageUpdatedAt: m.shippingStageUpdatedAt ? toMillis(m.shippingStageUpdatedAt) : undefined,
    whatsappSentAt: m.whatsappSentAt ? toMillis(m.whatsappSentAt) : undefined,
    whatsappSentTarget: String(m.whatsappSentTarget || ''),
    orderSummaryImageUrl: String(m.orderSummaryImageUrl || ''),
    priceSyncStatus: (m.priceSyncStatus as Order['priceSyncStatus']) || '',
    priceSyncNote: String(m.priceSyncNote || ''),
    proposedTotalSar: Number(m.proposedTotalSar || 0),
    proposedTotalLocal: Number(m.proposedTotalLocal || 0),
    proposedItems: Array.isArray(m.proposedItems) ? (m.proposedItems as Order['items']) : [],
    replacementStatus: (m.replacementStatus as Order['replacementStatus']) || '',
    replacementAlert: m.replacementAlert ? String(m.replacementAlert) : undefined,
    replacementProposal: m.replacementProposal as Order['replacementProposal'],
    customerSignatureUrl: String(m.customerSignatureUrl || ''),
    signedAt: m.signedAt ? toMillis(m.signedAt) : undefined,
    signedByName: String(m.signedByName || ''),
    deliveryPin: String(m.deliveryPin || ''),
    deliverySigned: Boolean(m.deliverySigned),
    deliveryPinVerified: Boolean(m.deliveryPinVerified),
    refunds: Array.isArray(m.refunds) ? (m.refunds as RefundRecord[]) : [],
    refundedTotalSar: Number(m.refundedTotalSar || 0),
    editingLocked: Boolean(m.editingLocked),
    approvedAt: m.approvedAt ? toMillis(m.approvedAt) : undefined,
    approvedByName: String(m.approvedByName || ''),
    deliveryMinDays: Number(m.deliveryMinDays || 15),
    deliveryMaxDays: Number(m.deliveryMaxDays || 20),
    createdAt: toMillis(m.createdAt),
    updatedAt: toMillis(m.updatedAt),
  };
}

export function useSeloo() {
  const ctx = useContext(SelooContext);
  if (!ctx) throw new Error('useSeloo must be used within SelooProvider');
  return ctx;
}
