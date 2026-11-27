import React, { useMemo, useState } from 'react';
import {
  AlertTriangle,
  ChevronLeft,
  MessageCircle,
  Package,
  Search,
} from 'lucide-react';
import { useSeloo } from '../context/SelooContext';
import { formatMoney } from '../services/pricingService';
import {
  ORDER_STAGE_BAR,
  orderStatusLabelAr,
} from '../services/shipmentTrackingService';
import { Order, OrderStatus } from '../types/seloo';
import { OrderDetailView } from './OrderDetailView';
import { PaymentScreen } from './PaymentScreen';

export const OrdersTab: React.FC = () => {
  const {
    user,
    signInGoogle,
    orders,
    ordersLoading,
    selectedOrderId,
    setSelectedOrderId,
    setActiveTab,
  } = useSeloo();

  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [payingOrder, setPayingOrder] = useState<Order | null>(null);

  const selectedOrder = orders.find((o) => o.id === selectedOrderId) || null;

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return orders.filter((o) => {
      const stOk = filterStatus === 'all' || o.status === filterStatus;
      const qOk =
        !q ||
        o.orderNo.toLowerCase().includes(q) ||
        o.receiverPhone.includes(q) ||
        o.shippingGovernorate.toLowerCase().includes(q);
      return stOk && qOk;
    });
  }, [orders, search, filterStatus]);

  if (!user) {
    return (
      <div className="max-w-lg mx-auto py-16 text-center space-y-5">
        <div className="w-16 h-16 rounded-2xl bg-[#F3EFE9] dark:bg-[#1E1830] mx-auto flex items-center justify-center">
          <Package className="w-8 h-8 text-violet-600 dark:text-violet-400" />
        </div>
        <h1 className="text-2xl font-extrabold">متابعة طلباتي</h1>
        <p className="text-sm text-[#5F5870] dark:text-[#A9A1BA]">
          سجّل الدخول بحساب Google لعرض طلباتك وتتبع الشحنات والتوقيع الإلكتروني للاستلام.
        </p>
        <button
          type="button"
          onClick={() => signInGoogle()}
          className="px-6 py-3 rounded-xl bg-violet-600 hover:bg-violet-700 text-white text-sm font-bold"
        >
          تسجيل الدخول بحساب Google
        </button>
      </div>
    );
  }

  if (payingOrder) {
    return (
      <PaymentScreen
        order={payingOrder}
        onBack={() => setPayingOrder(null)}
        onComplete={() => {
          setSelectedOrderId(payingOrder.id);
          setPayingOrder(null);
        }}
      />
    );
  }

  if (selectedOrder) {
    return (
      <OrderDetailView
        order={selectedOrder}
        onBack={() => setSelectedOrderId(null)}
        onOpenPayment={(ord) => setPayingOrder(ord)}
      />
    );
  }

  return (
    <div className="space-y-6 pb-16">
      <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 border-b border-black/10 dark:border-white/10 pb-5">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold">طلباتي ({orders.length})</h1>
          <p className="text-xs text-[#5F5870] dark:text-[#A9A1BA] mt-1">
            يظهر شريط المراحل الست مباشرة على كل طلب مع تنبيهات الاستمارة والبديل الذكي.
          </p>
        </div>

        <div className="relative w-full sm:w-72">
          <Search className="w-4 h-4 text-[#5F5870] absolute top-1/2 -translate-y-1/2 right-3.5" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="بحث برقم الطلب أو الهاتف..."
            className="w-full pr-10 pl-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
          />
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        {[
          { key: 'all', label: 'الكل' },
          { key: OrderStatus.unpaid, label: 'بانتظار السداد' },
          { key: OrderStatus.verifying, label: 'قيد التحقق' },
          { key: OrderStatus.processing, label: 'قيد التجهيز' },
          { key: OrderStatus.shipped, label: 'في الشحن' },
          { key: OrderStatus.delivered, label: 'تم التسليم' },
        ].map((f) => (
          <button
            key={f.key}
            type="button"
            onClick={() => setFilterStatus(f.key)}
            className={`px-3.5 py-2 rounded-xl text-xs font-bold border transition-colors ${
              filterStatus === f.key
                ? 'bg-violet-600 text-white border-violet-600'
                : 'bg-white dark:bg-[#151122] border-black/10 dark:border-white/10'
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {ordersLoading ? (
        <div className="space-y-4">
          {[1, 2].map((i) => (
            <div
              key={i}
              className="h-36 rounded-2xl bg-black/5 dark:bg-white/5 animate-pulse"
            />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="p-12 text-center rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-3">
          <p className="font-bold text-lg">لا توجد طلبات حتى الآن</p>
          <button
            type="button"
            onClick={() => setActiveTab('catalog')}
            className="px-5 py-2.5 rounded-xl bg-violet-600 text-white text-xs font-bold"
          >
            ابدأ التسوق الآن
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {filtered.map((ord) => {
            const stageIdx = Math.max(
              0,
              ORDER_STAGE_BAR.findIndex((s) => s.status === ord.status)
            );
            return (
              <div
                key={ord.id}
                onClick={() => setSelectedOrderId(ord.id)}
                className="p-5 rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] hover:border-violet-500/60 cursor-pointer transition-all space-y-4"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="flex items-center gap-2.5">
                      <span className="font-mono-num font-extrabold text-base text-violet-700 dark:text-violet-300">
                        {ord.orderNo}
                      </span>
                      <span className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                        · {new Date(ord.createdAt).toLocaleDateString('ar-YE')} ·{' '}
                        {ord.items.length} أصناف
                      </span>
                    </div>
                    <div className="text-sm font-bold mt-1">
                      {orderStatusLabelAr(ord.status)}
                    </div>
                  </div>

                  <div className="text-end">
                    <div className="font-mono-num font-extrabold text-base">
                      {formatMoney(ord.totalLocal, ord.currency)}
                    </div>
                    <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA] flex items-center justify-end gap-1 mt-0.5">
                      <span>التفاصيل والتتبع</span>
                      <ChevronLeft className="w-3.5 h-3.5" />
                    </div>
                  </div>
                </div>

                {/* Inline 6-Stage OrderStageBar directly on Order Card */}
                <div className="grid grid-cols-6 gap-1.5">
                  {ORDER_STAGE_BAR.map((st, idx) => (
                    <div key={st.status} className="space-y-1">
                      <div
                        className={`h-1.5 rounded-full ${
                          ord.status !== OrderStatus.cancelled && idx <= stageIdx
                            ? 'bg-violet-600'
                            : 'bg-black/10 dark:bg-white/10'
                        }`}
                      />
                      <div className="text-[10px] text-center truncate text-[#5F5870] dark:text-[#A9A1BA]">
                        {st.labelAr}
                      </div>
                    </div>
                  ))}
                </div>

                {/* Quick Alerts (WhatsApp confirmation / Price Sync / Smart Replacement) */}
                {(ord.whatsappSentAt ||
                  ord.priceSyncStatus === 'pending_customer' ||
                  ord.replacementStatus === 'pending_customer') && (
                  <div className="flex flex-wrap gap-3 text-xs pt-2 border-t border-black/10 dark:border-white/10">
                    {ord.whatsappSentAt && (
                      <span className="flex items-center gap-1 text-emerald-700 dark:text-emerald-300 font-semibold">
                        <MessageCircle className="w-3.5 h-3.5" />
                        <span>تم إرسال استمارة واتساب بانتظار الاعتماد</span>
                      </span>
                    )}
                    {ord.priceSyncStatus === 'pending_customer' && (
                      <span className="flex items-center gap-1 text-amber-700 dark:text-amber-300 font-bold">
                        <AlertTriangle className="w-3.5 h-3.5" />
                        <span>مطلوب موافقتك على تحديث السعر</span>
                      </span>
                    )}
                    {ord.replacementStatus === 'pending_customer' && (
                      <span className="flex items-center gap-1 text-violet-700 dark:text-violet-300 font-bold">
                        <AlertTriangle className="w-3.5 h-3.5" />
                        <span>مطلوب اختيار بديل ذكي (نفاد قطعة)</span>
                      </span>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
