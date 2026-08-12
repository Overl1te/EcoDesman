"use client";

import { Search, X } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useState, useTransition } from "react";

export function TopbarSearch({ placeholder }: { placeholder: string }) {
  const searchParams = useSearchParams();
  const pathname = usePathname();
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [value, setValue] = useState(searchParams.get("search") || "");

  return (
    <form
      className="topbar-search"
      onSubmit={(event) => {
        event.preventDefault();
        const params = new URLSearchParams(searchParams.toString());
        if (value.trim()) {
          params.set("search", value.trim());
        } else {
          params.delete("search");
        }
        params.delete("page");
        startTransition(() => {
          router.replace(`${pathname}?${params.toString()}`);
        });
      }}
    >
      <Search className="topbar-search-icon" />
      <input
        type="search"
        placeholder={placeholder}
        value={value}
        onChange={(event) => setValue(event.target.value)}
      />
      {value ? (
        <button
          type="button"
          className="icon-button icon-button-muted"
          onClick={() => {
            setValue("");
            const params = new URLSearchParams(searchParams.toString());
            params.delete("search");
            params.delete("page");
            startTransition(() => {
              router.replace(`${pathname}?${params.toString()}`);
            });
          }}
          disabled={isPending}
          aria-label="Очистить поиск"
        >
          <X className="topbar-search-icon" />
        </button>
      ) : null}
    </form>
  );
}
