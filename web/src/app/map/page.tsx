import type { Metadata } from "next";

import { MapPage } from "@/components/map/map-page";
import { StructuredDataScript } from "@/components/seo/structured-data-script";
import {
  buildCollectionPageStructuredData,
  buildPageMetadata,
} from "@/lib/seo";

export const metadata: Metadata = buildPageMetadata({
  title: "Карта экоточек и пунктов переработки в Нижнем Новгороде",
  description:
    "Интерактивная карта ЭкоВыхухоли показывает экоточки, пункты переработки, полезные места и пользовательские метки в Нижнем Новгороде. Находите нужные локации, смотрите отзывы и уточнения сообщества.",
  path: "/map",
});

export default function MapRoutePage() {
  return (
    <>
      <StructuredDataScript
        data={[
          buildCollectionPageStructuredData({
            path: "/map",
            name: "Карта экоточек и пунктов переработки в Нижнем Новгороде",
            description:
              "Интерактивная карта пунктов переработки, экоточек, полезных мест и пользовательских меток.",
            about: [
              "экоточки",
              "пункты переработки",
              "раздельный сбор",
              "городские экоместа",
              "экологическая карта",
            ],
          }),
        ]}
      />
      <MapPage />
    </>
  );
}
