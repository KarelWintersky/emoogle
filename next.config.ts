/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  swcMinify: true,
  images: { unoptimized: true },
  poweredByHeader: false,
};
module.exports = nextConfig;