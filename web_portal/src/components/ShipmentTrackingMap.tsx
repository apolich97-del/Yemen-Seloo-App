import React, { useState } from 'react';
import { ChevronDown, Info } from 'lucide-react';
import {
  getMilestoneMeta,
  SHIPPING_MILESTONES,
  SHIPPING_STAFF_GUIDE,
} from '../services/shipmentTrackingService';
import { ShippingMilestone } from '../types/seloo';

interface ShipmentTrackingMapProps {
  currentMilestone: ShippingMilestone;
  destinationCity: string;
  showStaffGuideOption?: boolean;
}

export const ShipmentTrackingMap: React.FC<ShipmentTrackingMapProps> = ({
  currentMilestone,
  destinationCity,
  showStaffGuideOption = true,
}) => {
  const [guideOpen, setGuideOpen] = useState(false);
  const activeMeta = getMilestoneMeta(currentMilestone);
  const activeIdx = SHIPPING_MILESTONES.findIndex((m) => m.key === currentMilestone);

  const routeNodes = [
    { key: ShippingMilestone.chinaWarehouse, title: 'مطار الصين 🇨🇳', x: 540, y: 85 },
    { key: ShippingMilestone.uaeTransit, title: 'مستودعات الإمارات 🇦🇪', x: 380, y: 112 },
    { key: ShippingMilestone.saudiCustoms, title: 'جمارك السعودية 🇸🇦', x: 245, y: 128 },
    {
      key: ShippingMilestone.yemenArrival,
      title: `مقر تعز 🇾🇪 (${destinationCity || 'اليمن'})`,
      x: 105,
      y: 170,
    },
  ];

  return (
    <div className="rounded-2xl border border-black/10 dark:border-white/10 bg-[#FAF8F5] dark:bg-[#0D0B14] p-5 space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <div className="text-xs text-[#5F5870] dark:text-[#A9A1BA]">
            خريطة المسار التفاعلية للشحنة (الصين ← الإمارات ← الرياض/جدة ← مقر تعز)
          </div>
          <div className="font-extrabold text-sm text-violet-700 dark:text-violet-300 mt-0.5">
            {activeMeta.emoji} {activeMeta.labelAr}
          </div>
        </div>
        <div className="font-mono-num text-xs font-bold px-3 py-1 rounded-lg bg-violet-600/10 text-violet-700 dark:text-violet-300">
          {activeMeta.progress}% مكتمل
        </div>
      </div>

      {/* Architectural SVG Route Diagram */}
      <div className="w-full overflow-hidden rounded-xl border border-black/5 dark:border-white/5 bg-white dark:bg-[#151122] p-3">
        <svg viewBox="0 0 640 230" className="w-full h-auto" role="img" aria-label="مسار الشحنة من الصين إلى مقر الشركة في تعز">
          <defs>
            <pattern id="selooGrid" width="32" height="32" patternUnits="userSpaceOnUse">
              <path
                d="M 32 0 L 0 0 0 32"
                fill="none"
                stroke="currentColor"
                className="text-black/[0.04] dark:text-white/[0.04]"
                strokeWidth="1"
              />
            </pattern>
          </defs>
          <rect width="640" height="230" fill="url(#selooGrid)" rx="12" />

          <path
            d="M 540 85 Q 460 72, 380 112 T 245 128 T 105 170"
            fill="none"
            stroke="currentColor"
            className="text-black/15 dark:text-white/15"
            strokeWidth="3"
            strokeDasharray="6 6"
          />

          {activeIdx >= 1 && (
            <path
              d={
                activeIdx === 1
                  ? 'M 540 85 L 540 85'
                  : activeIdx === 2
                  ? 'M 540 85 Q 460 72, 380 112'
                  : activeIdx === 3
                  ? 'M 540 85 Q 460 72, 380 112 T 245 128'
                  : 'M 540 85 Q 460 72, 380 112 T 245 128 T 105 170'
              }
              fill="none"
              stroke="#7C3AED"
              strokeWidth="4"
              strokeLinecap="round"
            />
          )}

          {routeNodes.map((node) => {
            const nodeIdx = SHIPPING_MILESTONES.findIndex((m) => m.key === node.key);
            const reached = activeIdx >= nodeIdx;
            const current =
              activeIdx === nodeIdx ||
              (node.key === ShippingMilestone.yemenArrival && activeIdx > nodeIdx);
            return (
              <g key={node.key}>
                {current && (
                  <circle
                    cx={node.x}
                    cy={node.y}
                    r="16"
                    fill="#7C3AED"
                    fillOpacity="0.18"
                  />
                )}
                <circle
                  cx={node.x}
                  cy={node.y}
                  r="8"
                  fill={reached ? '#7C3AED' : '#D4D0DC'}
                  stroke="#FFFFFF"
                  strokeWidth="2.5"
                />
                <text
                  x={node.x}
                  y={node.y - 18}
                  textAnchor="middle"
                  className="fill-[#171321] dark:fill-[#F6F3EC] text-[11px] font-bold"
                >
                  {node.title}
                </text>
              </g>
            );
          })}
        </svg>
      </div>

      {/* Detailed Milestone Stepper */}
      <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-2">
        {SHIPPING_MILESTONES.map((step, i) => {
          const done = i <= activeIdx;
          return (
            <div
              key={step.key}
              className={`p-2.5 rounded-xl border text-center text-[11px] transition-colors ${
                done
                  ? 'border-violet-600/40 bg-violet-600/10 text-violet-800 dark:text-violet-200 font-bold'
                  : 'border-black/10 dark:border-white/10 text-[#5F5870] dark:text-[#A9A1BA]'
              }`}
            >
              <div className="text-base mb-0.5">{step.emoji}</div>
              <div className="leading-tight">{step.shortAr}</div>
            </div>
          );
        })}
      </div>

      {showStaffGuideOption && (
        <div className="pt-1">
          <button
            type="button"
            onClick={() => setGuideOpen((v) => !v)}
            className="text-xs font-bold text-[#5F5870] dark:text-[#A9A1BA] hover:text-violet-700 dark:hover:text-violet-300 flex items-center gap-1.5"
          >
            <Info className="w-3.5 h-3.5" />
            <span>توضيح مراحل المسار السبع وآلية التحديث</span>
            <ChevronDown className={`w-3.5 h-3.5 transition-transform ${guideOpen ? 'rotate-180' : ''}`} />
          </button>
          {guideOpen && (
            <div className="mt-2.5 grid sm:grid-cols-2 gap-2 text-[11px]">
              {SHIPPING_STAFF_GUIDE.map((g) => (
                <div
                  key={g.stage}
                  className="p-2.5 rounded-xl bg-white dark:bg-[#151122] border border-black/10 dark:border-white/10"
                >
                  <div className="font-bold text-violet-700 dark:text-violet-300">{g.stage}</div>
                  <div className="text-[#5F5870] dark:text-[#A9A1BA] mt-0.5">{g.meaning}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
};
