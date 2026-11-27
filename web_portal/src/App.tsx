import React, { useState } from 'react';
import {
  Bell,
  CheckCheck,
  Home,
  LayoutGrid,
  Link2,
  Moon,
  Package,
  ShoppingBag,
  Sun,
  User,
  X,
} from 'lucide-react';
import { CartTab } from './components/CartTab';
import { CatalogTab } from './components/CatalogTab';
import { CurrencyModal } from './components/CurrencyModal';
import { HomeTab } from './components/HomeTab';
import { OrdersTab } from './components/OrdersTab';
import { ProfileScreen } from './components/ProfileScreen';
import { SheinStoreTab } from './components/SheinStoreTab';
import { SelooProvider, useSeloo } from './context/SelooContext';
import { TabKey } from './types/seloo';

const ShellContent: React.FC = () => {
  const {
    theme,
    toggleTheme,
    currency,
    setCurrencyModalOpen,
    activeTab,
    setActiveTab,
    cart,
    notifications,
    unreadNotificationsCount,
    markNotificationRead,
    markAllNotificationsRead,
    setSelectedOrderId,
    toasts,
    t,
  } = useSeloo();

  const [notifOpen, setNotifOpen] = useState(false);
  const cartCount = cart.reduce((s, c) => s + Math.max(1, c.qty), 0);

  const navItems: { key: TabKey; label: string; icon: React.ReactNode }[] = [
    { key: 'home', label: t('home'), icon: <Home className="w-4 h-4" /> },
    { key: 'catalog', label: t('catalog'), icon: <LayoutGrid className="w-4 h-4" /> },
    { key: 'shein', label: t('shein'), icon: <Link2 className="w-4 h-4" /> },
    { key: 'orders', label: t('orders'), icon: <Package className="w-4 h-4" /> },
    { key: 'me', label: t('me'), icon: <User className="w-4 h-4" /> },
  ];

  const currencyShort =
    currency === 'south'
      ? 'جنوب'
      : currency === 'north'
      ? 'شمال'
      : currency === 'usd'
      ? 'USD'
      : 'SAR';

  return (
    <div className="min-h-screen flex flex-col bg-[#FAF8F5] text-[#171321] dark:bg-[#0D0B14] dark:text-[#F6F3EC] transition-colors">
      {/* Clean 3-Zone Top Header */}
      <header className="sticky top-0 z-40 border-b border-black/10 dark:border-white/10 bg-[#FAF8F5]/90 dark:bg-[#0D0B14]/90 backdrop-blur-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between gap-4">
          {/* Zone 1: Brand Wordmark */}
          <button
            type="button"
            onClick={() => setActiveTab('home')}
            className="flex items-center gap-2.5 text-start shrink-0"
          >
            <span className="w-9 h-9 rounded-xl bg-gradient-to-br from-violet-700 to-amber-600 text-white font-extrabold flex items-center justify-center text-sm shadow-sm">
              YS
            </span>
            <div>
              <div className="font-extrabold text-base leading-none tracking-tight">
                {t('brand')}
              </div>
              <div className="text-[10px] text-[#5F5870] dark:text-[#A9A1BA] mt-0.5 hidden sm:block">
                YEMEN SELOO
              </div>
            </div>
          </button>

          {/* Zone 2: Primary Desktop Navigation */}
          <nav className="hidden md:flex items-center gap-1">
            {navItems.map((item) => {
              const active = activeTab === item.key;
              return (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => setActiveTab(item.key)}
                  className={`px-3.5 py-2 rounded-xl text-sm font-bold transition-colors whitespace-nowrap ${
                    active
                      ? 'bg-violet-600 text-white'
                      : 'text-[#5F5870] dark:text-[#A9A1BA] hover:text-[#171321] dark:hover:text-white hover:bg-black/5 dark:hover:bg-white/5'
                  }`}
                >
                  {item.label}
                </button>
              );
            })}
          </nav>

          {/* Zone 3: Compact Actions + Primary Cart CTA */}
          <div className="flex items-center gap-2 shrink-0">
            <button
              type="button"
              onClick={() => setCurrencyModalOpen(true)}
              className="px-2.5 py-2 rounded-xl border border-black/10 dark:border-white/10 text-xs font-bold hover:border-violet-500/50 transition-colors"
              title="العملة"
            >
              {currencyShort}
            </button>

            <button
              type="button"
              onClick={toggleTheme}
              className="p-2 rounded-xl border border-black/10 dark:border-white/10 hover:border-violet-500/50 transition-colors"
              aria-label="تبديل الثيم"
            >
              {theme === 'dark' ? (
                <Sun className="w-4 h-4 text-amber-400" />
              ) : (
                <Moon className="w-4 h-4 text-violet-700" />
              )}
            </button>

            <button
              type="button"
              onClick={() => setNotifOpen(true)}
              className="relative p-2 rounded-xl border border-black/10 dark:border-white/10 hover:border-violet-500/50 transition-colors"
              aria-label="جرس الإشعارات"
            >
              <Bell className="w-4 h-4" />
              {unreadNotificationsCount > 0 && (
                <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-rose-600 text-white text-[10px] font-mono-num font-bold flex items-center justify-center">
                  {unreadNotificationsCount}
                </span>
              )}
            </button>

            <button
              type="button"
              onClick={() => setActiveTab('cart')}
              className="px-3.5 py-2 rounded-xl bg-violet-600 hover:bg-violet-700 text-white text-xs font-bold flex items-center gap-1.5 transition-colors"
            >
              <ShoppingBag className="w-4 h-4" />
              <span className="hidden sm:inline">{t('cart')}</span>
              <span className="font-mono-num">({cartCount})</span>
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 pt-6 sm:pt-8 pb-24 md:pb-12">
        {activeTab === 'home' && <HomeTab />}
        {activeTab === 'catalog' && <CatalogTab />}
        {activeTab === 'shein' && <SheinStoreTab />}
        {activeTab === 'cart' && <CartTab />}
        {activeTab === 'orders' && <OrdersTab />}
        {activeTab === 'me' && <ProfileScreen />}
      </main>

      {/* Mobile Bottom Navigation Bar */}
      <nav className="md:hidden fixed bottom-0 inset-x-0 z-40 h-16 border-t border-black/10 dark:border-white/10 bg-white/95 dark:bg-[#151122]/95 backdrop-blur-md grid grid-cols-6">
        {[
          ...navItems.slice(0, 3),
          {
            key: 'cart' as TabKey,
            label: `${t('cart')}${cartCount > 0 ? ` (${cartCount})` : ''}`,
            icon: <ShoppingBag className="w-4 h-4" />,
          },
          ...navItems.slice(3),
        ].map((item) => {
          const active = activeTab === item.key;
          return (
            <button
              key={item.key}
              type="button"
              onClick={() => setActiveTab(item.key)}
              className={`flex flex-col items-center justify-center gap-0.5 text-[10px] font-bold ${
                active
                  ? 'text-violet-700 dark:text-violet-300'
                  : 'text-[#5F5870] dark:text-[#A9A1BA]'
              }`}
            >
              {item.icon}
              <span className="truncate max-w-[56px]">{item.label}</span>
            </button>
          );
        })}
      </nav>

      {/* Notification Center Drawer (Point 6) */}
      {notifOpen && (
        <div
          className="fixed inset-0 z-50 flex justify-end bg-black/50 backdrop-blur-sm"
          onClick={() => setNotifOpen(false)}
        >
          <div
            className="w-full max-w-md h-full bg-white dark:bg-[#151122] border-r border-black/10 dark:border-white/10 p-5 flex flex-col justify-between shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="space-y-4 overflow-y-auto">
              <div className="flex items-center justify-between border-b border-black/10 dark:border-white/10 pb-3">
                <div className="flex items-center gap-2 font-extrabold text-base">
                  <Bell className="w-5 h-5 text-violet-600 dark:text-violet-400" />
                  <span>مركز الإشعارات</span>
                </div>
                <div className="flex items-center gap-2">
                  {unreadNotificationsCount > 0 && (
                    <button
                      type="button"
                      onClick={markAllNotificationsRead}
                      className="text-xs font-bold text-violet-700 dark:text-violet-300 flex items-center gap-1"
                    >
                      <CheckCheck className="w-3.5 h-3.5" />
                      <span>قراءة الكل</span>
                    </button>
                  )}
                  <button
                    type="button"
                    onClick={() => setNotifOpen(false)}
                    className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/10"
                  >
                    <X className="w-5 h-5" />
                  </button>
                </div>
              </div>

              {notifications.length === 0 ? (
                <div className="py-20 text-center text-sm text-[#5F5870] dark:text-[#A9A1BA]">
                  لا توجد إشعارات جديدة حالياً.
                </div>
              ) : (
                <div className="space-y-2.5">
                  {notifications.map((n) => (
                    <button
                      key={n.id}
                      type="button"
                      onClick={async () => {
                        await markNotificationRead(n.id);
                        if (n.orderId) {
                          setSelectedOrderId(n.orderId);
                          setActiveTab('orders');
                        }
                        setNotifOpen(false);
                      }}
                      className={`w-full text-start p-3.5 rounded-2xl border transition-colors ${
                        n.read
                          ? 'border-black/10 dark:border-white/10 opacity-75'
                          : 'border-violet-600/40 bg-violet-600/8'
                      }`}
                    >
                      <div className="font-bold text-xs">{n.title}</div>
                      <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA] mt-1">
                        {n.body}
                      </div>
                      <div className="text-[10px] font-mono-num text-[#5F5870] dark:text-[#A9A1BA] mt-1.5">
                        {new Date(n.createdAt).toLocaleString('ar-YE')}
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Toast Feed */}
      <div className="fixed bottom-20 md:bottom-6 left-4 right-4 md:left-6 md:right-auto z-50 flex flex-col gap-2 max-w-sm pointer-events-none">
        {toasts.map((toast) => (
          <div
            key={toast.id}
            className={`px-4 py-3 rounded-xl shadow-lg text-xs font-bold text-white pointer-events-auto ${
              toast.tone === 'error'
                ? 'bg-rose-600'
                : toast.tone === 'success'
                ? 'bg-emerald-600'
                : 'bg-[#171321] dark:bg-violet-600'
            }`}
          >
            {toast.text}
          </div>
        ))}
      </div>

      <CurrencyModal />
    </div>
  );
};

export function App() {
  return (
    <SelooProvider>
      <ShellContent />
    </SelooProvider>
  );
}

export default App;
