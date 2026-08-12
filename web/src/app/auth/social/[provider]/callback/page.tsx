import { Suspense } from "react";

import { SocialCallbackPage } from "@/components/auth/social-callback-page";
import { LoadingBlock } from "@/components/ui/loading-block";

interface SocialCallbackRouteProps {
  params: Promise<{
    provider: string;
  }>;
}

export default async function SocialCallbackRoute({ params }: SocialCallbackRouteProps) {
  const { provider } = await params;

  return (
    <Suspense fallback={<LoadingBlock />}>
      <SocialCallbackPage provider={provider} />
    </Suspense>
  );
}
