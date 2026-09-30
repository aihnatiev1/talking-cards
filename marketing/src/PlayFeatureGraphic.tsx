import React from 'react';
import { AbsoluteFill, Img, staticFile } from 'remotion';
import { z } from 'zod';
import { loadFont as loadComfortaa } from '@remotion/google-fonts/Comfortaa';
import { loadFont as loadNunito } from '@remotion/google-fonts/Nunito';

// Google Play feature graphic, 1024×500. Same palette and type as the
// store screenshots; the art is the app's own — card illustrations from
// assets/images/webp and Bloom rendered from the app's painter
// (test_tools/render_bloom_test.dart). No microphone, no rating, no
// promise of results: the app plays words, it does not listen.
const comfortaa = loadComfortaa('normal', {
  weights: ['700'],
  subsets: ['latin', 'cyrillic'],
});
const nunito = loadNunito('normal', {
  weights: ['700', '800'],
  subsets: ['latin', 'cyrillic'],
});

export const playFeatureSchema = z.object({
  locale: z.enum(['en', 'uk']),
});

const COPY = {
  uk: {
    name: ['Картки-', 'розмовлялки'],
    sub: 'Перші слова для малюків 1–4 років',
    words: ['КОТИК', 'СОБАЧКА', 'ЯБЛУКО'],
  },
  en: {
    name: ['FirstWords', 'Cards'],
    sub: 'First words for little ones, ages 1–4',
    words: ['CAT', 'DOG', 'APPLE'],
  },
};

const ACCENT = '#AE491B';
const INK = '#3A2E2A';

const Card: React.FC<{
  img: string;
  word: string;
  x: number;
  y: number;
  rotate: number;
  z: number;
}> = ({ img, word, x, y, rotate, z }) => (
  <div
    style={{
      position: 'absolute',
      left: x,
      top: y,
      width: 150,
      height: 205,
      borderRadius: 26,
      background: '#FFFDF7',
      boxShadow: '0 14px 30px rgba(120,60,20,0.22)',
      transform: `rotate(${rotate}deg)`,
      zIndex: z,
      overflow: 'hidden',
      display: 'flex',
      flexDirection: 'column',
    }}
  >
    <Img
      src={staticFile(`banner/${img}.webp`)}
      style={{ width: 150, height: 150, objectFit: 'cover' }}
    />
    <div
      style={{
        flex: 1,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: nunito.fontFamily,
        fontWeight: 800,
        fontSize: 21,
        letterSpacing: 0.5,
        color: ACCENT,
      }}
    >
      {word}
    </div>
  </div>
);

export const PlayFeatureGraphic: React.FC<z.infer<typeof playFeatureSchema>> = ({
  locale,
}) => {
  const c = COPY[locale];
  return (
    <AbsoluteFill
      style={{ background: 'linear-gradient(135deg, #FFF3E4 0%, #FFD9B0 100%)' }}
    >
      {/* Soft circles, as on the screenshots */}
      {[
        [90, 420, 190],
        [960, 60, 170],
        [640, 520, 150],
      ].map(([x, y, r]) => (
        <div
          key={`${x}-${y}`}
          style={{
            position: 'absolute',
            left: x - r,
            top: y - r,
            width: r * 2,
            height: r * 2,
            borderRadius: '50%',
            background: 'rgba(255,255,255,0.35)',
          }}
        />
      ))}

      <div style={{ position: 'absolute', left: 64, top: 118, width: 470 }}>
        <div
          style={{
            fontFamily: comfortaa.fontFamily,
            fontWeight: 700,
            fontSize: locale === 'uk' ? 64 : 70,
            lineHeight: 1.05,
            color: INK,
          }}
        >
          {c.name[0]}
          <br />
          <span style={{ color: ACCENT }}>{c.name[1]}</span>
        </div>
        <div
          style={{
            marginTop: 22,
            fontFamily: nunito.fontFamily,
            fontWeight: 700,
            fontSize: 26,
            lineHeight: 1.3,
            color: '#6B5A52',
          }}
        >
          {c.sub}
        </div>
      </div>

      <Card img="dog" word={c.words[1]} x={548} y={82} rotate={-9} z={1} />
      <Card img="apple" word={c.words[2]} x={850} y={82} rotate={9} z={1} />
      <Card img="cat" word={c.words[0]} x={699} y={52} rotate={0} z={2} />

      <Img
        src={staticFile('bloom/bloom-wave-left.png')}
        style={{
          position: 'absolute',
          left: 679,
          top: 296,
          width: 190,
          height: 190,
          zIndex: 3,
        }}
      />
    </AbsoluteFill>
  );
};
