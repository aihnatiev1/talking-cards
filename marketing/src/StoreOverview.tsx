import React from 'react';
import { AbsoluteFill } from 'remotion';
import { StoreScreenshot } from './StoreScreenshot';

/** A review sheet rendered from the exact same components as the store PNGs. */
export const StoreOverview: React.FC = () => (
  <AbsoluteFill style={{ background: '#FFFDF8', fontFamily: 'sans-serif' }}>
    <div style={{ position: 'absolute', top: 22, left: 24, fontSize: 28, color: '#3F3635' }}>
      FirstWords Cards · Українська / English
    </div>
    {(['uk', 'en'] as const).flatMap((locale, row) =>
      Array.from({ length: 7 }, (_, index) => (
        <div key={`${locale}-${index}`} style={{ position: 'absolute', left: 16 + index * 320, top: 90 + row * 690 }}>
          <div style={{ position: 'absolute', top: -22, fontSize: 14, color: '#6B605B' }}>{locale.toUpperCase()} · {index + 1}</div>
          <div style={{ width: 288, height: 624, overflow: 'hidden', borderRadius: 12, boxShadow: '0 5px 18px #3f36351a' }}>
            <div style={{ width: 1290, height: 2796, position: 'relative', transformOrigin: 'top left', transform: `scale(${288 / 1290})` }}>
              <StoreScreenshot locale={locale} slot={index + 1} />
            </div>
          </div>
        </div>
      )),
    )}
  </AbsoluteFill>
);
