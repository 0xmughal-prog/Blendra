'use client';

import { useEffect, useRef, useState } from 'react';

interface AnimatedNumberProps {
  value: number | string;
  decimals?: number;
  duration?: number;
  prefix?: string;
  suffix?: string;
  className?: string;
}

export function AnimatedNumber({
  value,
  decimals = 0,
  duration = 2000,
  prefix = '',
  suffix = '',
  className = '',
}: AnimatedNumberProps) {
  const [displayValue, setDisplayValue] = useState(0);
  const [hasAnimated, setHasAnimated] = useState(false);
  const elementRef = useRef<HTMLSpanElement>(null);

  // Parse the input value
  const targetValue = typeof value === 'string'
    ? parseFloat(value.replace(/,/g, ''))
    : value;

  useEffect(() => {
    if (isNaN(targetValue) || hasAnimated) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !hasAnimated) {
          setHasAnimated(true);
          animateValue();
        }
      },
      { threshold: 0.1 }
    );

    if (elementRef.current) {
      observer.observe(elementRef.current);
    }

    return () => observer.disconnect();
  }, [targetValue, hasAnimated]);

  const animateValue = () => {
    const startTime = Date.now();
    const startValue = 0;

    const easeOutQuart = (t: number): number => {
      return 1 - Math.pow(1 - t, 4);
    };

    const updateValue = () => {
      const currentTime = Date.now();
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);

      const easedProgress = easeOutQuart(progress);
      const currentValue = startValue + (targetValue - startValue) * easedProgress;

      setDisplayValue(currentValue);

      if (progress < 1) {
        requestAnimationFrame(updateValue);
      } else {
        setDisplayValue(targetValue);
      }
    };

    requestAnimationFrame(updateValue);
  };

  const formatNumber = (num: number): string => {
    return num.toLocaleString('en-US', {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals,
    });
  };

  return (
    <span ref={elementRef} className={className}>
      {prefix}
      {formatNumber(displayValue)}
      {suffix}
    </span>
  );
}
