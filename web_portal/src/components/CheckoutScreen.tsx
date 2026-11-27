import React, { useEffect, useState } from 'react';
import { doc, getDoc } from 'firebase/firestore';
import {
  AlertCircle,
  AlertTriangle,
  ArrowRight,
  Check,
  Edit3,
  Lock,
  MapPin,
  ShieldAlert,
  Tag,
} from 'lucide-react';
import { db } from '../config/firebase';
import { SELOO_POLICIES, YEMEN_GOVERNORATES } from '../config/selooConfig';
import { useSeloo } from '../context/SelooContext';
import { computeCartTotals, formatMoney } from '../services/pricingService';
import { Address, Order } from '../types/seloo';

interface CheckoutScreenProps {
  onBack: () => void;
  onOrderCreated: (order: Order) => void;
}

export const CheckoutScreen: React.FC<CheckoutScreenProps> = ({
  onBack,
  onOrderCreated,
}) => {
  const {
    user,
    signInGoogle,
    cart,
    settings,
    currency,
    savedAddresses,
    selectedAddressId,
    setSelectedAddressId,
    saveAddress,
    checkoutAlerts,
    createOrder,
    notifyToast,
  } = useSeloo();

  const activeAddress =
    savedAddresses.find((a) => a.id === selectedAddressId) || savedAddresses[0];

  const [editingAddress, setEditingAddress] = useState(!activeAddress);
  const [receiverName, setReceiverName] = useState(
    activeAddress?.receiverName || user?.displayName || ''
  );
  const [phone, setPhone] = useState(activeAddress?.phone || user?.phone || '');
  const [city, setCity] = useState(
    activeAddress?.city || YEMEN_GOVERNORATES[0].name
  );
  const [district, setDistrict] = useState(activeAddress?.district || '');
  const [line, setLine] = useState(activeAddress?.line || '');

  const [shippingMode, setShippingMode] = useState<'office' | 'driver' | 'pickup'>(
    'office'
  );
  const govMeta =
    YEMEN_GOVERNORATES.find((g) => g.name === city) || YEMEN_GOVERNORATES[0];
  const [shippingOffice, setShippingOffice] = useState(govMeta.offices[0] || '');
  const [driverName, setDriverName] = useState('');
  const [driverPhone, setDriverPhone] = useState('');
  const [driverMeetPoint, setDriverMeetPoint] = useState('');

  const [paymentPlan, setPaymentPlan] = useState<'full' | 'half_deferred'>('full');
  const [couponInput, setCouponInput] = useState('');
  const [appliedCoupon, setAppliedCoupon] = useState('');
  const [discountSar, setDiscountSar] = useState(0);
  const [ackUrgentAlerts, setAckUrgentAlerts] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const found = YEMEN_GOVERNORATES.find((g) => g.name === city);
    if (found && found.offices.length > 0) {
      setShippingOffice(found.offices[0]);
    }
  }, [city]);

  useEffect(() => {
    if (activeAddress && !editingAddress) {
      setReceiverName(activeAddress.receiverName);
      setPhone(activeAddress.phone);
      setCity(activeAddress.city);
      setDistrict(activeAddress.district || '');
      setLine(activeAddress.line);
    }
  }, [activeAddress, editingAddress]);

  const totals = computeCartTotals(
    cart,
    settings,
    currency,
    discountSar,
    shippingMode
  );

  const hasUrgentAlertRequiringAck = checkoutAlerts.some((a) => a.requireAck);

  const handleSaveInlineAddress = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!receiverName.trim() || !phone.trim() || !line.trim()) {
      notifyToast('يرجى إدخال اسم المستلم ورقم الهاتف وتفاصيل العنوان', 'error');
      return;
    }
    const addr: Address = {
      id: activeAddress?.id || `addr_${Date.now()}`,
      label: `${city} — ${district || 'المركز'}`,
      receiverName: receiverName.trim(),
      phone: phone.trim(),
      city,
      district: district.trim(),
      line: line.trim(),
    };
    await saveAddress(addr);
    setEditingAddress(false);
  };

  const handleVerifyCoupon = async () => {
    const code = couponInput.trim().toUpperCase();
    if (!code) return;
    try {
      const snap = await getDoc(doc(db, 'coupons', code));
      if (!snap.exists() || snap.data().active === false) {
        notifyToast('الكوبون غير صالح أو منتهي الصلاحية', 'error');
        return;
      }
      const data = snap.data();
      const minSar = Number(data.minOrderSar || 0);
      if (totals.subtotalSar < minSar) {
        notifyToast(`الحد الأدنى لهذا الكوبون ${minSar} ر.س`, 'error');
        return;
      }
      const disc =
        data.type === 'fixedSar'
          ? Number(data.value || 0)
          : (totals.subtotalSar * Number(data.value || 0)) / 100;
      setDiscountSar(Math.min(totals.subtotalSar, disc));
      setAppliedCoupon(code);
      notifyToast(`تم تطبيق الخصم (${disc.toFixed(2)} ر.س)`, 'success');
    } catch {
      notifyToast('تعذر التحقق من الكوبون حالياً', 'error');
    }
  };

  const handleSubmitOrder = async () => {
    if (!user) {
      await signInGoogle();
      return;
    }
    if (!receiverName.trim() || !phone.trim() || !line.trim()) {
      setEditingAddress(true);
      notifyToast('أكمل بيانات المستلم والعنوان أولاً', 'error');
      return;
    }
    if (hasUrgentAlertRequiringAck && !ackUrgentAlerts) {
      notifyToast('يرجى تأكيد الاطلاع على التنبيه العاجل أعلى الصفحة', 'error');
      return;
    }

    setSubmitting(true);
    const addrObj: Address = {
      id: activeAddress?.id || `addr_${Date.now()}`,
      label: `${city}${district ? ` - ${district}` : ''}`,
      receiverName: receiverName.trim(),
      phone: phone.trim(),
      city,
      district: district.trim(),
      line: line.trim(),
    };
    if (!activeAddress) {
      await saveAddress(addrObj);
    }

    const created = await createOrder({
      address: addrObj,
      shippingMode,
      shippingGovernorate: city,
      shippingOffice: shippingMode === 'office' ? shippingOffice : 'استلام مباشر',
      shippingOfficeChoice: shippingOffice,
      driverName,
      driverPhone,
      driverMeetPoint,
      paymentPlan,
      couponCode: appliedCoupon,
      discountSar,
    });
    setSubmitting(false);
    if (created) {
      onOrderCreated(created);
    }
  };

  return (
    <div className="max-w-5xl mx-auto space-y-6 pb-16">
      <div className="flex items-center justify-between border-b border-black/10 dark:border-white/10 pb-4">
        <button
          type="button"
          onClick={onBack}
          className="flex items-center gap-2 text-sm font-bold text-[#5F5870] dark:text-[#A9A1BA] hover:text-violet-600"
        >
          <ArrowRight className="w-4 h-4" />
          <span>العودة إلى السلة</span>
        </button>
        <h1 className="text-xl font-extrabold">تأكيد العنوان وخطة السداد</h1>
      </div>

      {/* Point 5: Live Checkout Alerts from Manager / Support / Shipping */}
      {checkoutAlerts.length > 0 && (
        <div className="space-y-3">
          {checkoutAlerts.map((alert) => (
            <div
              key={alert.id}
              className={`p-4 rounded-2xl border flex gap-3 ${
                alert.severity === 'urgent'
                  ? 'bg-rose-500/10 border-rose-500/35 text-rose-800 dark:text-rose-200'
                  : alert.severity === 'warning'
                  ? 'bg-amber-500/10 border-amber-500/35 text-amber-800 dark:text-amber-200'
                  : 'bg-violet-500/10 border-violet-500/30 text-violet-900 dark:text-violet-200'
              }`}
            >
              {alert.severity === 'urgent' ? (
                <ShieldAlert className="w-5 h-5 shrink-0 mt-0.5" />
              ) : alert.severity === 'warning' ? (
                <AlertTriangle className="w-5 h-5 shrink-0 mt-0.5" />
              ) : (
                <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" />
              )}
              <div className="space-y-1 text-sm">
                <div className="font-bold">
                  {alert.title} · <span className="text-xs opacity-80">{alert.createdByName}</span>
                </div>
                <p className="text-xs leading-relaxed opacity-90">{alert.message}</p>
              </div>
            </div>
          ))}

          {hasUrgentAlertRequiringAck && (
            <label className="flex items-center gap-2.5 p-3 rounded-xl border border-rose-500/30 bg-white dark:bg-[#151122] text-xs font-bold cursor-pointer">
              <input
                type="checkbox"
                checked={ackUrgentAlerts}
                onChange={(e) => setAckUrgentAlerts(e.target.checked)}
                className="rounded text-violet-600 focus:ring-violet-500"
              />
              <span>اطلعت على تنبيه الشحن/الأسعار أعلاه وأوافق على المتابعة</span>
            </label>
          )}
        </div>
      )}

      <div className="grid lg:grid-cols-12 gap-6 items-start">
        <div className="lg:col-span-7 space-y-6">
          {/* Point 12: Inline Address Editor inside Pre-Payment */}
          <section className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 font-extrabold text-base">
                <MapPin className="w-5 h-5 text-violet-600 dark:text-violet-400" />
                <span>عنوان الاستلام والمستلم</span>
              </div>
              {!editingAddress && (
                <button
                  type="button"
                  onClick={() => setEditingAddress(true)}
                  className="px-3 py-1.5 rounded-xl border border-violet-600/30 text-violet-700 dark:text-violet-300 text-xs font-bold flex items-center gap-1.5 hover:bg-violet-600/10"
                >
                  <Edit3 className="w-3.5 h-3.5" />
                  <span>تعديل العنوان</span>
                </button>
              )}
            </div>

            {savedAddresses.length > 1 && !editingAddress && (
              <div className="flex flex-wrap gap-2">
                {savedAddresses.map((addr) => (
                  <button
                    key={addr.id}
                    type="button"
                    onClick={() => setSelectedAddressId(addr.id)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold border ${
                      addr.id === activeAddress?.id
                        ? 'border-violet-600 bg-violet-600/10 text-violet-700 dark:text-violet-300'
                        : 'border-black/10 dark:border-white/10'
                    }`}
                  >
                    {addr.label}
                  </button>
                ))}
              </div>
            )}

            {editingAddress ? (
              <form onSubmit={handleSaveInlineAddress} className="space-y-3">
                <div className="grid sm:grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs font-bold block mb-1">اسم المستلم الكامل *</label>
                    <input
                      type="text"
                      value={receiverName}
                      onChange={(e) => setReceiverName(e.target.value)}
                      className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
                    />
                  </div>
                  <div>
                    <label className="text-xs font-bold block mb-1">رقم الهاتف (واتساب) *</label>
                    <input
                      type="tel"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      placeholder="77xxxxxxx"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
                    />
                  </div>
                </div>
                <div className="grid sm:grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs font-bold block mb-1">المحافظة *</label>
                    <select
                      value={city}
                      onChange={(e) => setCity(e.target.value)}
                      className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
                    >
                      {YEMEN_GOVERNORATES.map((g) => (
                        <option key={g.name} value={g.name}>
                          {g.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="text-xs font-bold block mb-1">المديرية / الحي (اختياري)</label>
                    <input
                      type="text"
                      value={district}
                      onChange={(e) => setDistrict(e.target.value)}
                      placeholder="مثال: حدة / المنصورة"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
                    />
                  </div>
                </div>
                <div>
                  <label className="text-xs font-bold block mb-1">تفاصيل العنوان / أقرب معلم *</label>
                  <input
                    type="text"
                    value={line}
                    onChange={(e) => setLine(e.target.value)}
                    placeholder="الشارع أو جوار..."
                    className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
                  />
                </div>
                <div className="flex justify-end gap-2 pt-1">
                  {activeAddress && (
                    <button
                      type="button"
                      onClick={() => setEditingAddress(false)}
                      className="px-4 py-2 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold"
                    >
                      إلغاء
                    </button>
                  )}
                  <button
                    type="submit"
                    className="px-5 py-2 rounded-xl bg-violet-600 text-white text-xs font-bold"
                  >
                    حفظ وتثبيت العنوان
                  </button>
                </div>
              </form>
            ) : (
              <div className="p-4 rounded-2xl bg-[#F3EFE9] dark:bg-[#1E1830] text-sm space-y-1">
                <div className="font-bold">
                  {receiverName} · <span className="font-mono-num">{phone}</span>
                </div>
                <div className="text-[#5F5870] dark:text-[#A9A1BA]">
                  {city}
                  {district ? ` - ${district}` : ''} — {line}
                </div>
              </div>
            )}
          </section>

          {/* Shipping Method */}
          <section className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
            <h2 className="font-extrabold text-base">طريقة استلام الشحنة في اليمن</h2>
            <div className="grid grid-cols-3 gap-2.5 text-xs font-bold">
              {[
                { key: 'office' as const, label: 'مكتب نقل / فرع' },
                { key: 'driver' as const, label: 'توصيل مع سائق/مندوب' },
                { key: 'pickup' as const, label: 'استلام من المركز' },
              ].map((m) => (
                <button
                  key={m.key}
                  type="button"
                  onClick={() => setShippingMode(m.key)}
                  className={`p-3 rounded-xl border text-center transition-colors ${
                    shippingMode === m.key
                      ? 'border-violet-600 bg-violet-600/10 text-violet-700 dark:text-violet-300'
                      : 'border-black/10 dark:border-white/10'
                  }`}
                >
                  {m.label}
                </button>
              ))}
            </div>

            {shippingMode === 'office' && (
              <div className="space-y-2">
                <label className="text-xs font-bold block">مكتب الشحن المفضل في {city}</label>
                <select
                  value={shippingOffice}
                  onChange={(e) => setShippingOffice(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-white dark:bg-[#151122] text-sm"
                >
                  {govMeta.offices.map((o) => (
                    <option key={o} value={o}>
                      {o}
                    </option>
                  ))}
                </select>
                <p className="text-[11px] text-[#5F5870] dark:text-[#A9A1BA]">
                  رسوم نقل المحافظات تُحدَّد بالاتفاق مع مكتب الشحن عند الوصول ولا تُدفع مسبقاً.
                </p>
              </div>
            )}

            {shippingMode === 'driver' && (
              <div className="grid sm:grid-cols-3 gap-2.5">
                <input
                  type="text"
                  value={driverName}
                  onChange={(e) => setDriverName(e.target.value)}
                  placeholder="اسم السائق (اختياري)"
                  className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
                />
                <input
                  type="tel"
                  value={driverPhone}
                  onChange={(e) => setDriverPhone(e.target.value)}
                  placeholder="رقم السائق"
                  className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm font-mono-num"
                />
                <input
                  type="text"
                  value={driverMeetPoint}
                  onChange={(e) => setDriverMeetPoint(e.target.value)}
                  placeholder="نقطة الالتقاء"
                  className="px-3.5 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-sm"
                />
              </div>
            )}
          </section>

          {/* Payment Plan */}
          <section className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
            <h2 className="font-extrabold text-base">خطة الدفع</h2>
            <div className="grid sm:grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setPaymentPlan('full')}
                className={`p-4 rounded-2xl border text-start space-y-1 ${
                  paymentPlan === 'full'
                    ? 'border-violet-600 bg-violet-600/8'
                    : 'border-black/10 dark:border-white/10'
                }`}
              >
                <div className="flex items-center justify-between font-bold text-sm">
                  <span>الدفع الكامل (100%)</span>
                  {paymentPlan === 'full' && <Check className="w-4 h-4 text-violet-600" />}
                </div>
                <div className="font-mono-num font-extrabold text-base text-violet-700 dark:text-violet-300">
                  {formatMoney(totals.totalLocal, currency)}
                </div>
              </button>

              <button
                type="button"
                disabled={!totals.canDeferred}
                onClick={() => setPaymentPlan('half_deferred')}
                className={`p-4 rounded-2xl border text-start space-y-1 disabled:opacity-50 ${
                  paymentPlan === 'half_deferred'
                    ? 'border-violet-600 bg-violet-600/8'
                    : 'border-black/10 dark:border-white/10'
                }`}
              >
                <div className="flex items-center justify-between font-bold text-sm">
                  <span>دفعة أولى 50% (آجل)</span>
                  {paymentPlan === 'half_deferred' && (
                    <Check className="w-4 h-4 text-violet-600" />
                  )}
                </div>
                <div className="font-mono-num font-extrabold text-base text-amber-700 dark:text-amber-300">
                  {totals.canDeferred
                    ? `الآن ${formatMoney(totals.upfrontLocal, currency)}`
                    : `يتطلب +${settings.deferredThresholdSar} ر.س`}
                </div>
              </button>
            </div>
            <div className="flex items-center gap-2 text-xs text-[#5F5870] dark:text-[#A9A1BA]">
              <Lock className="w-3.5 h-3.5 text-amber-600 shrink-0" />
              <span>{SELOO_POLICIES.deferredRule}</span>
            </div>
          </section>
        </div>

        {/* Order Review & Coupon */}
        <div className="lg:col-span-5 space-y-4">
          <div className="p-6 rounded-3xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] space-y-4">
            <h2 className="font-extrabold text-base">مراجعة النهائي</h2>

            <div className="flex gap-2">
              <div className="relative flex-1">
                <Tag className="w-4 h-4 text-[#5F5870] absolute top-1/2 -translate-y-1/2 right-3" />
                <input
                  type="text"
                  value={couponInput}
                  onChange={(e) => setCouponInput(e.target.value)}
                  placeholder="كود الخصم (اختياري)"
                  className="w-full pr-9 pl-3 py-2.5 rounded-xl border border-black/15 dark:border-white/15 bg-transparent text-xs uppercase"
                />
              </div>
              <button
                type="button"
                onClick={handleVerifyCoupon}
                className="px-4 py-2.5 rounded-xl border border-black/15 dark:border-white/15 text-xs font-bold hover:bg-black/5 dark:hover:bg-white/5"
              >
                تطبيق
              </button>
            </div>

            <div className="space-y-2 text-sm pt-2 border-t border-black/10 dark:border-white/10">
              <div className="flex justify-between">
                <span className="text-[#5F5870] dark:text-[#A9A1BA]">المجموع بالريال السعودي</span>
                <span className="font-mono-num font-bold">{totals.totalSar.toFixed(2)} ر.س</span>
              </div>
              {discountSar > 0 && (
                <div className="flex justify-between text-emerald-600 dark:text-emerald-400">
                  <span>خصم الكوبون ({appliedCoupon})</span>
                  <span className="font-mono-num font-bold">-{discountSar.toFixed(2)} ر.س</span>
                </div>
              )}
              <div className="flex justify-between font-extrabold text-base pt-2 border-t border-black/10 dark:border-white/10">
                <span>المطلوب تحويله الآن</span>
                <span className="font-mono-num text-violet-700 dark:text-violet-300">
                  {formatMoney(
                    paymentPlan === 'half_deferred' && totals.canDeferred
                      ? totals.upfrontLocal
                      : totals.totalLocal,
                    currency
                  )}
                </span>
              </div>
              {paymentPlan === 'half_deferred' && totals.canDeferred && (
                <div className="flex justify-between text-xs text-amber-700 dark:text-amber-300">
                  <span>المتبقي عند الوصول (مثبت السعر)</span>
                  <span className="font-mono-num font-bold">
                    {formatMoney(totals.remainingLocal, currency)}
                  </span>
                </div>
              )}
            </div>

            <button
              type="button"
              onClick={handleSubmitOrder}
              disabled={submitting}
              className="w-full py-3.5 rounded-xl bg-violet-600 hover:bg-violet-700 text-white font-bold text-sm disabled:opacity-60"
            >
              {!user
                ? 'سجّل الدخول بحساب Google لإصدار الطلب'
                : submitting
                ? 'جاري إصدار الطلب...'
                : 'إصدار الطلب والانتقال للدفع'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
