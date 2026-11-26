import React from 'react';
import { AbsoluteFill, Img, staticFile } from 'remotion';
import { z } from 'zod';
import { loadFont as loadComfortaa } from '@remotion/google-fonts/Comfortaa';
import { loadFont as loadNunito } from '@remotion/google-fonts/Nunito';
import { storeShotsV3, V3Theme } from './storeShotsV3';

// The iPad twin of StoreScreenshotV3: the same copy and order, a 13-inch
// canvas (2064 × 2752) and an iPad frame holding a real iPad capture
// (SHOTS_DIR=marketing/public/screenshots/v3-ipad). The farm is captured
// with the tablet on its side (the rig turns it), and shown that way.
const comfortaa = loadComfortaa('normal', {
  weights: ['700'],
  subsets: ['latin', 'cyrillic'],
});
const nunito = loadNunito('normal', {
  weights: ['600', '700'],
  subsets: ['latin', 'cyrillic'],
});

export const storeScreenshotV3IpadSchema = z.object({
  locale: z.enum(['en', 'uk']),
  slot: z.number().int().min(1).max(7),
});

const W = 2064;
const H = 2752;

const THEMES: Record<V3Theme, { bg: string; accent: string }> = {
  sky: {
    bg: 'linear-gradient(180deg, #CFEFFF 0%, #EAF8FF 55%, #DDF3D2 100%)',
    accent: '#2F6FCB',
  },
  meadow: {
    bg: 'linear-gradient(180deg, #E8F8DD 0%, #FFF8E8 100%)',
    accent: '#3E8A12',
  },
  peach: {
    bg: 'linear-gradient(180deg, #FFF1E2 0%, #FFE0C4 100%)',
    accent: '#B4511E',
  },
};

// The friend who peeks in at the tablet's corner, per slide.
const PEEK = ['cow', 'chicken', 'cat', 'bird', 'dog', 'owl', 'bee'];

export const StoreScreenshotV3Ipad: React.FC<
  z.input<typeof storeScreenshotV3IpadSchema>
> = ({ locale, slot }) => {
  const s = storeShotsV3[locale][slot - 1];
  if (!s) throw new Error(`No v3 slot ${slot} for ${locale}`);
  const file = s.file.replace('v3/', 'v3-ipad/');
  const theme = THEMES[s.theme];
  const i = s.headline.indexOf(s.tint);
  const frameW = W * 0.8;
  const bezel = 26;
  const innerW = frameW - bezel * 2;
  const top = 560;
  const left = (slot - 1) % 2 === 0;
  if (s.landscape) return <Landscape file={file} s={s} theme={theme} i={i} />;
  return (
    <AbsoluteFill style={{ background: theme.bg }}>
      <div style={{ paddingTop: 130, textAlign: 'center' }}>
        <div
          style={{
            fontFamily: comfortaa.fontFamily,
            fontWeight: 700,
            fontSize: 128,
            lineHeight: 1.08,
            color: '#2D3436',
            padding: '0 120px',
          }}
        >
          {i >= 0 ? s.headline.slice(0, i) : s.headline}
          <span style={{ color: theme.accent }}>{i >= 0 ? s.tint : ''}</span>
          {i >= 0 ? s.headline.slice(i + s.tint.length) : ''}
        </div>
        <div
          style={{
            fontFamily: nunito.fontFamily,
            fontWeight: 600,
            fontSize: 60,
            color: '#4F5A5E',
            marginTop: 28,
            padding: '0 200px',
            lineHeight: 1.3,
          }}
        >
          {s.sub}
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          top,
          left: (W - frameW) / 2,
          width: frameW,
          height: H - top + 200,
          background: '#2D3436',
          borderRadius: 110,
          borderBottomLeftRadius: 0,
          borderBottomRightRadius: 0,
          padding: bezel,
          boxShadow: '0 50px 140px rgba(45,52,54,0.25)',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            width: innerW,
            height: '100%',
            borderRadius: 86,
            borderBottomLeftRadius: 0,
            borderBottomRightRadius: 0,
            overflow: 'hidden',
            background: '#fff',
          }}
        >
          <Img
            src={staticFile(`screenshots/${file}`)}
            style={{ width: innerW, display: 'block' }}
          />
        </div>
      </div>
      <Img
        src={staticFile(`friends/${PEEK[slot - 1]}.webp`)}
        style={{
          position: 'absolute',
          left: left ? -10 : W + 10 - 400,
          top: H - 400,
          width: 400,
          height: 400,
          objectFit: 'contain',
          objectPosition: 'bottom',
          transform: left ? undefined : 'scaleX(-1)',
          filter: 'drop-shadow(0 18px 24px rgba(45,52,54,0.18))',
        }}
      />
    </AbsoluteFill>
  );
};

const CROWD = ['horse', 'cow', 'dog', 'pig', 'cat'];

const Landscape: React.FC<{
  file: string;
  s: (typeof storeShotsV3)['uk'][number];
  theme: { bg: string; accent: string };
  i: number;
}> = ({ file, s, theme, i }) => {
  const frameW = W * 0.9;
  const bezel = 26;
  const innerW = frameW - bezel * 2;
  const innerH = innerW * (2064 / 2752);
  const top = 520;
  return (
    <AbsoluteFill style={{ background: theme.bg }}>
      <div
        style={{
          position: 'absolute',
          left: -300,
          right: -300,
          top: 1700,
          bottom: -400,
          borderRadius: '50% 50% 0 0',
          background: 'linear-gradient(180deg, #9ED67A 0%, #7CC05A 100%)',
        }}
      />
      <div style={{ paddingTop: 110, textAlign: 'center' }}>
        <div
          style={{
            fontFamily: comfortaa.fontFamily,
            fontWeight: 700,
            fontSize: 128,
            lineHeight: 1.08,
            color: '#2D3436',
          }}
        >
          {i >= 0 ? s.headline.slice(0, i) : s.headline}
          <span style={{ color: theme.accent }}>{i >= 0 ? s.tint : ''}</span>
          {i >= 0 ? s.headline.slice(i + s.tint.length) : ''}
        </div>
        <div
          style={{
            fontFamily: nunito.fontFamily,
            fontWeight: 600,
            fontSize: 60,
            color: '#4F5A5E',
            marginTop: 24,
          }}
        >
          {s.sub}
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          top,
          left: (W - frameW) / 2,
          width: frameW,
          height: innerH + bezel * 2,
          background: '#2D3436',
          borderRadius: 100,
          padding: bezel,
          boxShadow: '0 50px 140px rgba(45,52,54,0.25)',
        }}
      >
        <div
          style={{
            width: innerW,
            height: innerH,
            borderRadius: 76,
            overflow: 'hidden',
          }}
        >
          <Img
            src={staticFile(`screenshots/${file}`)}
            style={{ width: innerW, height: innerH, display: 'block' }}
          />
        </div>
      </div>
      {CROWD.map((name, k) => (
        <Img
          key={name}
          src={staticFile(`friends/${name}.webp`)}
          style={{
            position: 'absolute',
            left: 60 + k * 390,
            top: H - 560,
            width: 500,
            height: 500,
            objectFit: 'contain',
            objectPosition: 'bottom',
            transform: k > 2 ? 'scaleX(-1)' : undefined,
            filter: 'drop-shadow(0 18px 24px rgba(45,52,54,0.18))',
          }}
        />
      ))}
    </AbsoluteFill>
  );
};
