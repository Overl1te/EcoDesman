(function () {
  const html = document.documentElement;
  const themeToggle = document.querySelector("[data-theme-toggle]");
  const themeIcon = document.querySelector("[data-theme-icon]");
  const themeLabel = document.querySelector("[data-theme-label]");
  const themeModes = ["system", "light", "dark"];

  const applyTheme = (mode) => {
    if (mode === "system") {
      delete html.dataset.theme;
    } else {
      html.dataset.theme = mode;
    }

    if (!themeIcon || !themeLabel) {
      return;
    }

    if (mode === "light") {
      themeIcon.textContent = "light_mode";
      themeLabel.textContent = "Светлая";
      return;
    }

    if (mode === "dark") {
      themeIcon.textContent = "dark_mode";
      themeLabel.textContent = "Тёмная";
      return;
    }

    themeIcon.textContent = "brightness_auto";
    themeLabel.textContent = "Системная";
  };

  let currentTheme = window.localStorage.getItem("web-theme-mode") || "system";
  if (!themeModes.includes(currentTheme)) {
    currentTheme = "system";
  }
  applyTheme(currentTheme);

  if (themeToggle) {
    themeToggle.addEventListener("click", () => {
      const index = themeModes.indexOf(currentTheme);
      currentTheme = themeModes[(index + 1) % themeModes.length];
      window.localStorage.setItem("web-theme-mode", currentTheme);
      applyTheme(currentTheme);
    });
  }

  const lightbox = document.getElementById("lightbox");
  const lightboxImage = document.getElementById("lightbox-image");

  const closeLightbox = () => {
    if (!lightbox || !lightboxImage) {
      return;
    }
    lightbox.hidden = true;
    lightboxImage.src = "";
  };

  document.querySelectorAll("[data-lightbox-trigger]").forEach((element) => {
    element.addEventListener("click", () => {
      if (!lightbox || !lightboxImage) {
        return;
      }
      const source = element.getAttribute("data-lightbox-trigger");
      if (!source) {
        return;
      }
      lightboxImage.src = source;
      lightbox.hidden = false;
    });
  });

  document.querySelectorAll("[data-lightbox-close]").forEach((element) => {
    element.addEventListener("click", closeLightbox);
  });

  if (lightbox) {
    lightbox.addEventListener("click", (event) => {
      if (event.target === lightbox) {
        closeLightbox();
      }
    });
  }

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeLightbox();
    }
  });

  const avatarPreview = document.querySelector("[data-avatar-preview]");
  const avatarFileInput = document.querySelector("input[name='avatar_file']");
  const avatarXInput = document.querySelector("[data-avatar-x]");
  const avatarYInput = document.querySelector("[data-avatar-y]");
  const avatarScaleInput = document.querySelector("[data-avatar-scale]");
  const avatarPreviewBadge = document.querySelector(".avatar-preview");

  const ensureAvatarPreviewImage = () => {
    if (avatarPreview) {
      return avatarPreview;
    }
    if (!avatarPreviewBadge) {
      return null;
    }
    const image = document.createElement("img");
    image.alt = "Предпросмотр аватара";
    image.setAttribute("data-avatar-preview", "true");
    avatarPreviewBadge.replaceChildren(image);
    return image;
  };

  const updateAvatarPreview = () => {
    const image = document.querySelector("[data-avatar-preview]");
    if (!image) {
      return;
    }
    const x = avatarXInput?.value || "50";
    const y = avatarYInput?.value || "50";
    const scale = avatarScaleInput?.value || "1";
    image.style.objectPosition = `${x}% ${y}%`;
    image.style.transform = `scale(${scale})`;
  };

  [avatarXInput, avatarYInput, avatarScaleInput].forEach((input) => {
    if (input) {
      input.addEventListener("input", updateAvatarPreview);
    }
  });

  if (avatarFileInput) {
    avatarFileInput.addEventListener("change", () => {
      const file = avatarFileInput.files?.[0];
      if (!file) {
        return;
      }
      const image = ensureAvatarPreviewImage();
      if (!image) {
        return;
      }
      image.src = URL.createObjectURL(file);
      updateAvatarPreview();
    });
  }

  const bioInput = document.querySelector("[data-profile-bio]");
  const bioCount = document.querySelector("[data-profile-bio-count]");
  if (bioInput && bioCount) {
    bioInput.addEventListener("input", () => {
      bioCount.textContent = `${bioInput.value.length} / 500`;
    });
  }

  const mapElement = document.getElementById("map-view");
  const pointsElement = document.getElementById("map-points-data");

  if (!mapElement || !pointsElement || typeof window.L === "undefined") {
    return;
  }

  let points = [];
  try {
    points = JSON.parse(pointsElement.textContent || "[]");
  } catch (_error) {
    points = [];
  }

  const defaultCenter = [56.315048, 43.974881];
  const defaultMarkerColor = "#56616F";

  const hexToRgb = (hex) => {
    const normalized = String(hex || defaultMarkerColor).replace("#", "");
    const value = normalized.length === 3
      ? normalized
          .split("")
          .map((part) => `${part}${part}`)
          .join("")
      : normalized;
    const parsed = Number.parseInt(value, 16);
    return {
      r: (parsed >> 16) & 255,
      g: (parsed >> 8) & 255,
      b: parsed & 255,
    };
  };

  const hexToRgba = (hex, alpha) => {
    const { r, g, b } = hexToRgb(hex);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  };

  const mixWithWhite = (hex, ratio) => {
    const { r, g, b } = hexToRgb(hex);
    const mixChannel = (channel) => Math.round(channel * (1 - ratio) + 255 * ratio);
    const next = [mixChannel(r), mixChannel(g), mixChannel(b)]
      .map((channel) => channel.toString(16).padStart(2, "0"))
      .join("");
    return `#${next}`;
  };

  const getPointAppearance = (point) => {
    const baseColor = point?.primary_category?.color || defaultMarkerColor;
    return {
      color: baseColor,
      haloColor: hexToRgba(baseColor, 0.2),
      strokeColor: mixWithWhite(baseColor, 0.74),
      selectedColor: mixWithWhite(baseColor, 0.12),
      selectedStrokeColor: mixWithWhite(baseColor, 0.88),
    };
  };

  const map = window.L.map(mapElement, {
    center: defaultCenter,
    zoom: 11.7,
    minZoom: 10.5,
    zoomControl: false,
    attributionControl: false,
  });

  window.L.control
    .attribution({
      position: "bottomright",
      prefix: false,
    })
    .addTo(map);

  map.attributionControl.addAttribution("&copy; OpenStreetMap");

  window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 18,
  }).addTo(map);

  const selectedPoint = points.find((point) => point.selected);

  points.forEach((point) => {
    const appearance = getPointAppearance(point);
    const marker = window.L.circleMarker([point.latitude, point.longitude], {
      radius: point.selected ? 11 : 9,
      color: point.selected ? appearance.selectedStrokeColor : appearance.strokeColor,
      weight: 3,
      fillColor: point.selected ? appearance.selectedColor : appearance.color,
      fillOpacity: 0.96,
    });

    if (point.selected) {
      window.L.circleMarker([point.latitude, point.longitude], {
        radius: 17,
        color: appearance.haloColor,
        weight: 2,
        fillColor: appearance.haloColor,
        fillOpacity: 0.92,
      }).addTo(map);
    }

    marker.bindTooltip(point.title, {
      direction: "top",
      offset: [0, -8],
    });

    marker.addTo(map);
    marker.on("click", () => {
      window.location.href = point.url;
    });
  });

  if (selectedPoint) {
    map.setView([selectedPoint.latitude, selectedPoint.longitude], 13.2);
  }
})();
