/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ["nodemailer", "imapflow", "mailparser", "bullmq", "ioredis"],
  },
};

export default nextConfig;
