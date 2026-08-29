import "package:eco_nizhny/core/config/app_config.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  const config = AppConfig(
    environment: "production",
    apiBaseUrl: AppConfig.fallbackApiBaseUrl,
  );

  test("production API lives on the public site host, not api. or an IP", () {
    expect(
      AppConfig.fallbackApiBaseUrl,
      "https://xn--b1apekb3anb5cpb.xn--p1ai/api/v1",
    );
    expect(config.rootBaseUrl, "https://xn--b1apekb3anb5cpb.xn--p1ai");
    expect(
      config.mapRasterTileTemplate,
      "https://xn--b1apekb3anb5cpb.xn--p1ai/map-raster/{z}/{x}/{y}.png",
    );
  });

  test("relative media paths are resolved against the site origin", () {
    expect(
      config.resolveMediaUrl("/media/uploads/posts/cover.png"),
      "https://xn--b1apekb3anb5cpb.xn--p1ai/media/uploads/posts/cover.png",
    );
  });

  test("stale API and IP media hosts are rewritten to the public domain", () {
    expect(
      config.resolveMediaUrl(
        "https://api.xn--b1apekb3anb5cpb.xn--p1ai/media/uploads/posts/a.png",
      ),
      "https://xn--b1apekb3anb5cpb.xn--p1ai/media/uploads/posts/a.png",
    );
    expect(
      config.resolveMediaUrl("http://45.88.15.78/media/uploads/points/b.png"),
      "https://xn--b1apekb3anb5cpb.xn--p1ai/media/uploads/points/b.png",
    );
  });

  test("unrelated absolute URLs stay untouched", () {
    expect(
      config.resolveMediaUrl("https://tile.openstreetmap.org/1/2/3.png"),
      "https://tile.openstreetmap.org/1/2/3.png",
    );
  });
}
