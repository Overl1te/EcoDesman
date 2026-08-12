import type { UserSummary } from "@/lib/types";

interface AvatarProps {
  user: Pick<UserSummary, "avatar_url" | "name" | "username">;
  size?: "sm" | "md" | "lg";
}

export function Avatar({ user, size = "md" }: AvatarProps) {
  const fallback = (user.name || user.username || "?").trim().charAt(0).toUpperCase();

  return (
    <span className={`avatar avatar-${size}`}>
      {user.avatar_url ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={user.avatar_url} alt={user.name || user.username} />
      ) : (
        <span>{fallback}</span>
      )}
    </span>
  );
}
