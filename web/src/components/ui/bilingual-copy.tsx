import type { ElementType } from "react";

export function BilingualCopy(props: {
  primary: string;
  secondary?: string;
  primaryAs?: ElementType;
  primaryClassName?: string;
  secondaryAs?: ElementType;
  secondaryClassName?: string;
}) {
  const PrimaryTag = props.primaryAs ?? "p";

  return <PrimaryTag className={props.primaryClassName}>{props.primary}</PrimaryTag>;
}
