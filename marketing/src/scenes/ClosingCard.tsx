import React from 'react';
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

export const ClosingCard: React.FC<{
  closing: string;
  cta: string;
  /// Optional family/multi-profile selling line, fades in after the CTA so
  /// it never competes with the primary download button.
  familyBadge?: string;
}> = ({ closing, cta, familyBadge }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const scale = spring({ frame, fps, config: { damping: 12, stiffness: 140 } });
  const ctaOpacity = interpolate(frame, [20, 40], [0, 1], {
    extrapolateRight: 'clamp',
  });
  const ctaY = spring({
    frame: frame - 20,
    fps,
    config: { damping: 14, stiffness: 100 },
  });
  const familyOpacity = interpolate(frame, [50, 75], [0, 1], {
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        padding: '0 80px',
      }}
    >
      <div
        style={{
          fontSize: 84,
          fontWeight: 800,
          color: '#FF7043',
          textAlign: 'center',
          lineHeight: 1.15,
          whiteSpace: 'pre-line',
          transform: `scale(${scale})`,
          marginBottom: 60,
        }}
      >
        {closing}
      </div>
      <div
        style={{
          fontSize: 150,
          transform: `scale(${scale})`,
          marginBottom: 80,
        }}
      >
        🎉
      </div>

      <div
        style={{
          padding: '28px 56px',
          borderRadius: 60,
          background: '#6C63FF',
          color: 'white',
          fontSize: 56,
          fontWeight: 700,
          boxShadow: '0 14px 40px rgba(108, 99, 255, 0.45)',
          opacity: ctaOpacity,
          transform: `translateY(${(1 - ctaY) * 40}px)`,
        }}
      >
        {cta}
      </div>
      {familyBadge ? (
        <div
          style={{
            marginTop: 36,
            fontSize: 36,
            fontWeight: 600,
            color: '#5D4037',
            textAlign: 'center',
            lineHeight: 1.3,
            opacity: familyOpacity,
          }}
        >
          {familyBadge}
        </div>
      ) : null}
    </AbsoluteFill>
  );
};
