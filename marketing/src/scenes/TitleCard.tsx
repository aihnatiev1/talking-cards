import React from 'react';
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';

export const TitleCard: React.FC<{ title: string }> = ({ title }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const scale = spring({ frame, fps, config: { damping: 12, stiffness: 120, mass: 0.8 } });
  const opacity = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: 'clamp' });

  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        opacity,
      }}
    >
      <div
        style={{
          fontSize: 180,
          transform: `scale(${scale})`,
          marginBottom: 40,
        }}
      >
        🗣️
      </div>
      <div
        style={{
          fontSize: 92,
          fontWeight: 700,
          color: '#4A4A4A',
          textAlign: 'center',
          transform: `scale(${scale})`,
          padding: '0 60px',
        }}
      >
        {title}
      </div>
    </AbsoluteFill>
  );
};
