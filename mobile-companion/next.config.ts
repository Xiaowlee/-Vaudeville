import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  outputFileTracingRoot: process.cwd(),
  distDir: process.env.VAUDEVILLE_HOSTED === "1" ? ".next-hosted" : ".next",
  allowedDevOrigins: ["192.168.0.61"],
  devIndicators: false,
};

export default nextConfig;
