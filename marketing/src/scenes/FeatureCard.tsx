import React from 'react';
import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

// Displays a device-framed screenshot with a feature caption above it.
// Animates in from the bottom with a gentle spring.
export const FeatureCard: React.FC<{
  text: string;
  screenshot: string;
  accent: string;
}> = ({ text, screenshot, accent }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const textY = spring({
    frame: frame - 5,
    fps,
    config: { damping: 14, stiffness: 100 },
  });
  const deviceY = spring({
    frame,
    fps,
    config: { damping: 14, stiffness: 80 },
  });
  const textOpacity = interpolate(frame, [5, 20], [0, 1], {
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        padding: '80px 60px',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          marginTop: 60,
          padding: '22px 40px',
          borderRadius: 28,
          background: `${accent}15`,
          border: `3px solid ${accent}40`,
          opacity: textOpacity,
          transform: `translateY(${(1 - textY) * 30}px)`,
        }}
      >
        <div
          style={{
            fontSize: 64,
            fontWeight: 700,
            color: accent,
            textAlign: 'center',
            lineHeight: 1.1,
            whiteSpace: 'pre-line',
          }}
        >
          {text}
        </div>
      </div>

      <div
        style={{
          marginTop: 60,
          transform: `translateY(${(1 - deviceY) * 100}px)`,
          flex: 1,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div
          style={{
            borderRadius: 60,
            overflow: 'hidden',
            boxShadow: `0 20px 60px ${accent}55`,
            border: `10px solid #1A1A1A`,
            width: 620,
            height: 1280,
          }}
        >
          <Img
            src={screenshot}
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'cover',
            }}
          />
        </div>
      </div>
    </AbsoluteFill>
  );
};
