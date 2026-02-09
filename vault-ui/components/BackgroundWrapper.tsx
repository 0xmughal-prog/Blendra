'use client';

import { useTheme } from '@/lib/contexts/ThemeContext';

export function BackgroundWrapper() {
  const { theme } = useTheme();

  return (
    <div className="fixed inset-0 z-0">
      {/* Day background */}
      <div
        className={`absolute inset-0 transition-opacity duration-[2000ms] ease-in-out ${
          theme === 'day' ? 'opacity-100' : 'opacity-0'
        }`}
        style={{
          backgroundImage: 'url(/countryside-day.png)',
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          backgroundRepeat: 'no-repeat',
          imageRendering: 'auto' as any,
          WebkitBackfaceVisibility: 'hidden',
          transform: 'translateZ(0)',
        }}
      />

      {/* Night background */}
      <div
        className={`absolute inset-0 transition-opacity duration-[2000ms] ease-in-out ${
          theme === 'night' ? 'opacity-100' : 'opacity-0'
        }`}
        style={{
          backgroundImage: 'url(/countryside-night.png)',
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          backgroundRepeat: 'no-repeat',
          imageRendering: 'auto' as any,
          WebkitBackfaceVisibility: 'hidden',
          transform: 'translateZ(0)',
        }}
      />

      {/* Sky Color Transition Overlay */}
      {/* Warm overlay for sunset/sunrise effect */}
      <div
        className={`absolute inset-0 pointer-events-none transition-opacity duration-[2000ms] ease-in-out ${
          theme === 'day' ? 'opacity-0' : 'opacity-30'
        }`}
        style={{
          background: 'linear-gradient(to bottom, rgba(255, 140, 60, 0.4) 0%, rgba(255, 100, 40, 0.3) 30%, rgba(100, 60, 140, 0.2) 70%, transparent 100%)',
        }}
      />

      {/* Cool overlay for night */}
      <div
        className={`absolute inset-0 pointer-events-none transition-opacity duration-[2000ms] ease-in-out ${
          theme === 'night' ? 'opacity-25' : 'opacity-0'
        }`}
        style={{
          background: 'linear-gradient(to bottom, rgba(30, 50, 100, 0.3) 0%, rgba(50, 30, 80, 0.2) 50%, transparent 100%)',
        }}
      />
    </div>
  );
}
