/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    optimizePackageImports: ['lodash', 'date-fns'], // Tree-shake
    bundlePagesRouterDependencies: true,
  },
  swcMinify: true,        // Быстрее Terser
  compress: true,         // Gzip в standalone
  images: {
    unoptimized: true     // Нет Sharp (экономия 20MB)
  },
  trailingSlash: true,
  poweredByHeader: false, // Убираем Next.js хедер
};
module.exports = nextConfig;
