import React from 'react';
import { AbsoluteFill, Img, staticFile } from 'remotion';
import { z } from 'zod';
import { loadFont as loadComfortaa } from '@remotion/google-fonts/Comfortaa';
import { loadFont as loadNunito } from '@remotion/google-fonts/Nunito';
import { storeShots, StoreSlotConfig } from './storeShots';

// Comfortaa (not Fredoka/Baloo): the headline font must cover Cyrillic.
const comfortaa = loadComfortaa('normal', {
  weights: ['700'],
  subsets: ['latin', 'cyrillic'],
});
const nunito = loadNunito('normal', {
  weights: ['600', '700'],
  subsets: ['latin', 'cyrillic'],
});

export const storeScreenshotSchema = z.object({
  locale: z.enum(['en', 'uk']),
  variant: z.enum(['control', 'play']).default('control'),
  /** 1-based index into storeShots[locale] */
  slot: z.number().int().min(1).max(7),
});

const CANVAS_W = 1290;

const GRADIENTS = {
  warm: 'linear-gradient(180deg, #FFF3E4 0%, #FFD9B0 100%)',
  teal: 'linear-gradient(180deg, #E9FBF8 0%, #BDEEE6 100%)',
};
const ACCENTS = { warm: '#AE491B', teal: '#0F7A6F' };

const Circle: React.FC<{ x: number; y: number; r: number }> = ({ x, y, r }) => (
  <div
    style={{
      position: 'absolute',
      left: x - r,
      top: y - r,
      width: r * 2,
      height: r * 2,
      borderRadius: '50%',
      background: 'rgba(255,255,255,0.12)',
    }}
  />
);

const Headline: React.FC<{ cfg: StoreSlotConfig }> = ({ cfg }) => {
  const accent = ACCENTS[cfg.theme];
  const idx = cfg.headline.indexOf(cfg.tintWord);
  const before = idx >= 0 ? cfg.headline.slice(0, idx) : cfg.headline;
  const tinted = idx >= 0 ? cfg.tintWord : '';
  const after = idx >= 0 ? cfg.headline.slice(idx + cfg.tintWord.length) : '';
  return (
    <div style={{ paddingTop: 140, textAlign: 'center' }}>
      <div
        style={{
          fontFamily: comfortaa.fontFamily,
          fontWeight: 700,
          fontSize: 108,
          lineHeight: 1.08,
          letterSpacing: '-0.01em',
          color: '#2D3436',
          padding: '0 60px',
        }}
      >
        {before}
        <span style={{ color: accent }}>{tinted}</span>
        {after}
      </div>
      <div
        style={{
          fontFamily: nunito.fontFamily,
          fontWeight: 600,
          fontSize: 48,
          color: '#5A6265',
          marginTop: 28,
          padding: '0 96px',
          lineHeight: 1.35,
        }}
      >
        {cfg.sub}
      </div>
    </div>
  );
};

const Badges: React.FC<{ badges: string[] }> = ({ badges }) => {
  if (badges.length === 0) return null;
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'center',
        flexWrap: 'wrap',
        gap: 24,
        marginTop: 36,
        padding: '0 40px',
      }}
    >
      {badges.map((b) => (
        <div
          key={b}
          style={{
            background: 'rgba(255,255,255,0.92)',
            borderRadius: 48,
            padding: '28px 48px',
            fontFamily: nunito.fontFamily,
            fontWeight: 700,
            fontSize: 44,
            color: '#2D3436',
            boxShadow: '0 12px 40px rgba(45,52,54,0.12)',
            whiteSpace: 'nowrap',
          }}
        >
          {b}
        </div>
      ))}
    </div>
  );
};

const Device: React.FC<{ cfg: StoreSlotConfig }> = ({ cfg }) => {
  const widthPct = cfg.small ? 0.58 : 0.82;
  const frameW = CANVAS_W * widthPct;
  const bezel = cfg.small ? 12 : 16;
  const innerW = frameW - bezel * 2;
  const scale = innerW / 1290;
  const innerH = cfg.small ? 2796 * scale : undefined;
  return (
    <div
      style={{
        position: 'absolute',
        top: cfg.small ? 1050 : 620,
        left: '50%',
        transform: `translateX(-50%) rotate(${cfg.tilt}deg)`,
        width: frameW,
        height: cfg.small ? (innerH ?? 0) + bezel * 2 : 2796 - 620 + 200,
        background: '#2D3436',
        borderRadius: cfg.small ? 64 : 88,
        borderBottomLeftRadius: cfg.small ? 64 : 0,
        borderBottomRightRadius: cfg.small ? 64 : 0,
        padding: bezel,
        boxShadow: '0 40px 120px rgba(45,52,54,0.25)',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          width: innerW,
          height: '100%',
          borderRadius: cfg.small ? 52 : 68,
          borderBottomLeftRadius: cfg.small ? 52 : 0,
          borderBottomRightRadius: cfg.small ? 52 : 0,
          overflow: 'hidden',
          background: '#fff',
        }}
      >
        <Img
          src={staticFile(`screenshots/${cfg.file}`)}
          style={{
            width: innerW,
            display: 'block',
            // Crop stays proportional when the source PNG resolution changes.
            transform: `translateY(-${cfg.cropTop / 2796 * 100}%)`,
          }}
        />
      </div>
    </div>
  );
};

export const StoreScreenshot: React.FC<z.input<typeof storeScreenshotSchema>> = ({
  locale,
  slot,
  variant = 'control',
}) => {
  const base = storeShots[locale][slot - 1];
  const cfg = base && slot === 1 && variant === 'play'
    ? { ...base,
        headline: locale === 'uk' ? 'Перші слова через гру' : 'First Words Through Play',
        tintWord: locale === 'uk' ? 'через гру' : 'Play',
      }
    : base;
  if (!cfg) {
    throw new Error(`No slot ${slot} for locale ${locale}`);
  }
  return (
    <AbsoluteFill style={{ background: GRADIENTS[cfg.theme] }}>
      <Circle x={140} y={300} r={340} />
      <Circle x={1180} y={860} r={420} />
      <Circle x={260} y={2500} r={500} />
      <Headline cfg={cfg} />
      <Badges badges={cfg.badges} />
      <Device cfg={cfg} />
    </AbsoluteFill>
  );
};
