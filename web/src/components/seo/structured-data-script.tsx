type StructuredDataValue = Record<string, unknown>;

export function StructuredDataScript({
  data,
}: {
  data: StructuredDataValue | StructuredDataValue[];
}) {
  const payload = Array.isArray(data)
    ? {
        "@context": "https://schema.org",
        "@graph": data,
      }
    : {
        "@context": "https://schema.org",
        ...data,
      };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(payload) }}
    />
  );
}
