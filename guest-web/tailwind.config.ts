import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './src/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        kl: {
          canvas: '#FAF7F2',     // Warm Alabaster
          surface: '#FFFFFF',    // Pure Linen
          subtle: '#F2ECE4',     // Stone Wash
          dark: '#141413',       // Espresso Ink
          charcoal: '#1C1B19',   // Primary Ink
          muted: '#6E6A63',      // Warm Slate
          terracotta: '#C84B31', // Primary Accent
          sage: '#3D5A45',       // Secondary / Dietary
          emerald: '#10B981',    // LAN Relay Active
          amber: '#F59E0B',      // Offline / Warning
          border: '#E6E0D6',     // Warm Hairline
        },
      },
      fontFamily: {
        sans: ['var(--font-sans)', 'system-ui', 'sans-serif'],
        serif: ['var(--font-serif)', 'Georgia', 'serif'],
        mono: ['var(--font-mono)', 'monospace'],
      },
      borderRadius: {
        card: '0.75rem',
      },
    },
  },
  plugins: [],
};

export default config;
