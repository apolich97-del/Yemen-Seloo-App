import React from 'react';
import { X, Check, ArrowLeftRight } from 'lucide-react';
import { useSeloo } from '../context/SelooContext';
import { AppCurrency } from '../types/seloo';

export const CurrencyModal: React.FC = () => {
  const {
    currency,
    setCurrency,
    currencyModalOpen,
    setCurrencyModalOpen,
    settings,
    language,
  } = useSeloo();

  if (!currencyModalOpen) return null;

  const options: {
    key: AppCurrency;
    titleAr: string;
    titleEn: string;
    subtitle: string;
    rateLine: string;
  }[] = [
    {
      key: 'south',
      titleAr: 'ريال يمني — عدن والجنوب',
      titleEn: 'Yemeni Rial — South',
      subtitle: 'عدن · حضرموت · مأرب · شبوة · لحج · أبين',
      rateLine: `1 ر.س = ${settings.rateSouth} ر.ي  ·  1 USD = ${settings.usdRateSouth} ر.ي`,
    },
    {
      key: 'north',
      titleAr: 'ريال يمني — صنعاء والشمال',
      titleEn: 'Yemeni Rial — North',
      subtitle: 'صنعاء · تعز · إب · الحديدة · ذمار',
      rateLine: `1 ر.س = ${settings.rateNorth} ر.ي  ·  1 USD = ${settings.usdRateNorth} ر.ي`,
    },
    {
      key: 'sar',
      titleAr: 'الريال السعودي (SAR)',
      titleEn: 'Saudi Riyal (SAR)',
      subtitle: 'تسعير المصدر المباشر للتحويل السعودي',
      rateLine: `1 USD = ${settings.sarPerUsd} ر.س`,
    },
    {
      key: 'usd',
      titleAr: 'الدولار الأمريكي (USD)',
      titleEn: 'US Dollar (USD)',
      subtitle: 'عرض وتحويل مباشر بسعر الصرف المعتمد',
      rateLine: `$1 = ${settings.sarPerUsd} ر.س · ${settings.usdRateNorth} شمال / ${settings.usdRateSouth} جنوب`,
    },
  ];

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
      onClick={() => setCurrencyModalOpen(false)}
    >
      <div
        className="w-full max-w-lg rounded-2xl border border-black/10 dark:border-white/10 bg-white dark:bg-[#151122] shadow-2xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-black/10 dark:border-white/10">
          <div className="flex items-center gap-2.5">
            <ArrowLeftRight className="w-5 h-5 text-violet-600 dark:text-violet-400" />
            <h2 className="text-lg font-bold">
              {language === 'ar' ? 'عملة العرض ومنطقة الصرف' : 'Display Currency & Region'}
            </h2>
          </div>
          <button
            type="button"
            onClick={() => setCurrencyModalOpen(false)}
            className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/10 transition-colors"
            aria-label="إغلاق"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-5 space-y-3">
          {options.map((opt) => {
            const active = currency === opt.key;
            return (
              <button
                key={opt.key}
                type="button"
                onClick={() => {
                  setCurrency(opt.key);
                  setCurrencyModalOpen(false);
                }}
                className={`w-full text-start p-4 rounded-xl border transition-all flex items-start justify-between gap-4 ${
                  active
                    ? 'border-violet-600 bg-violet-600/8 dark:border-violet-400 dark:bg-violet-500/15'
                    : 'border-black/10 dark:border-white/10 hover:border-violet-500/50'
                }`}
              >
                <div className="space-y-1">
                  <div className="font-bold text-base">
                    {language === 'ar' ? opt.titleAr : opt.titleEn}
                  </div>
                  <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
                    {opt.subtitle}
                  </div>
                  <div className="text-xs font-mono-num text-violet-700 dark:text-violet-300 pt-1">
                    {opt.rateLine}
                  </div>
                </div>
                <span
                  className={`mt-1 w-6 h-6 rounded-full flex items-center justify-center shrink-0 border ${
                    active
                      ? 'bg-violet-600 border-violet-600 text-white'
                      : 'border-black/20 dark:border-white/20'
                  }`}
                >
                  {active && <Check className="w-3.5 h-3.5" />}
                </span>
              </button>
            );
          })}
        </div>

        <div className="px-6 py-3.5 bg-[#F3EFE9] dark:bg-[#1E1830] text-xs text-[#5F5870] dark:text-[#A9A1BA]">
          {language === 'ar'
            ? 'تتحدث الأسعار لحظياً من لوحة الإدارة، وتُثبَّت قيمة الصرف لكل طلب بمجرد إنشائه (بما في ذلك الطلبات الآجلة 50%).'
            : 'Exchange rates sync live from Firestore and lock on order creation.'}
        </div>
      </div>
    </div>
  );
};
