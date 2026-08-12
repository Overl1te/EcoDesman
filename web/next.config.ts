import type { NextConfig } from "next";

const CANONICAL_HOST = "xn--b1apekb3anb5cpb.xn--p1ai";
const WWW_HOST_PATTERNS = [
  "www\\.xn--b1apekb3anb5cpb\\.xn--p1ai(?::\\d+)?",
  "www\\.эковыхухоль\\.рф(?::\\d+)?",
];

const nextConfig: NextConfig = {
  output: "standalone",
  async rewrites() {
    return [
      {
        source: "/map-raster/:path*",
        destination: "https://tile.openstreetmap.org/:path*",
      },
    ];
  },
  async redirects() {
    return WWW_HOST_PATTERNS.map((host) => ({
      source: "/:path*",
      has: [
        {
          type: "host" as const,
          value: host,
        },
      ],
      destination: `https://${CANONICAL_HOST}/:path*`,
      permanent: true,
    }));
  },
};

export default nextConfig;
