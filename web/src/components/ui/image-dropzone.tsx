"use client";

import { ImagePlus, Upload, X } from "lucide-react";
import { useEffect, useId, useMemo, useRef, useState } from "react";

type ExistingImageItem = {
  id: string | number;
  alt: string;
  url: string;
  mediaType?: "image" | "video";
};

export function ImageDropzone({
  title,
  description,
  files,
  existingImages = [],
  emptyHint = "Перетащите изображения сюда или откройте системный выбор файлов.",
  browseLabel = "Выбрать фото",
  accept = "image/*",
  allowVideo = false,
  disabled = false,
  onAddFiles,
  onRemoveFile,
  onRemoveExistingImage,
}: {
  title: string;
  description: string;
  files: File[];
  existingImages?: ExistingImageItem[];
  emptyHint?: string;
  browseLabel?: string;
  accept?: string;
  allowVideo?: boolean;
  disabled?: boolean;
  onAddFiles: (files: File[]) => void;
  onRemoveFile?: (index: number) => void;
  onRemoveExistingImage?: (imageId: string | number) => void;
}) {
  const inputId = useId();
  const inputRef = useRef<HTMLInputElement | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const previewImages = useMemo(
    () =>
      files.map((file, index) => ({
        id: `${file.name}-${file.lastModified}-${index}`,
        alt: file.name,
        url: URL.createObjectURL(file),
        mediaType: file.type.startsWith("video/") ? "video" : "image",
      })),
    [files],
  );

  useEffect(() => {
    return () => {
      previewImages.forEach((item) => URL.revokeObjectURL(item.url));
    };
  }, [previewImages]);

  const hasImages = existingImages.length > 0 || previewImages.length > 0;
  const zoneClassName = useMemo(
    () =>
      `image-dropzone-zone${isDragging ? " is-dragging" : ""}${disabled ? " is-disabled" : ""}`,
    [disabled, isDragging],
  );

  function normalizeFiles(list: FileList | File[] | null | undefined): File[] {
    if (!list) {
      return [];
    }

    return Array.from(list).filter((file) => {
      if (file.type.startsWith("image/")) {
        return true;
      }
      return allowVideo && file.type.startsWith("video/");
    });
  }

  function appendFiles(list: FileList | File[] | null | undefined) {
    if (disabled) {
      return;
    }

    const nextFiles = normalizeFiles(list);
    if (nextFiles.length > 0) {
      onAddFiles(nextFiles);
    }
  }

  function openFilePicker() {
    if (!disabled) {
      inputRef.current?.click();
    }
  }

  return (
    <div className="image-dropzone">
      <input
        id={inputId}
        ref={inputRef}
        type="file"
        accept={accept}
        multiple
        className="visually-hidden"
        onChange={(event) => {
          appendFiles(event.target.files);
          event.target.value = "";
        }}
      />

      <div
        className={zoneClassName}
        role="button"
        tabIndex={disabled ? -1 : 0}
        aria-describedby={`${inputId}-hint`}
        onClick={openFilePicker}
        onKeyDown={(event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            openFilePicker();
          }
        }}
        onDragEnter={(event) => {
          event.preventDefault();
          if (!disabled) {
            setIsDragging(true);
          }
        }}
        onDragOver={(event) => {
          event.preventDefault();
          if (!disabled) {
            setIsDragging(true);
          }
        }}
        onDragLeave={(event) => {
          event.preventDefault();
          if (event.currentTarget === event.target) {
            setIsDragging(false);
          }
        }}
        onDrop={(event) => {
          event.preventDefault();
          setIsDragging(false);
          appendFiles(event.dataTransfer.files);
        }}
      >
        <span className="image-dropzone-icon">
          {hasImages ? <Upload className="nav-icon" /> : <ImagePlus className="nav-icon" />}
        </span>

        <div className="image-dropzone-copy">
          <strong>{title}</strong>
          <p>{description}</p>
          <small id={`${inputId}-hint`}>{emptyHint}</small>
        </div>

        <button
          type="button"
          className="button button-muted button-inline image-dropzone-button"
          onClick={(event) => {
            event.stopPropagation();
            openFilePicker();
          }}
          disabled={disabled}
        >
          <ImagePlus className="button-icon" />
          <span>{browseLabel}</span>
        </button>
      </div>

      {hasImages ? (
        <div className="image-dropzone-grid">
          {existingImages.map((image) => (
            <div key={`existing-${image.id}`} className="image-dropzone-card">
              {image.mediaType === "video" ? (
                <video src={image.url} className="gallery-image" controls />
              ) : (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={image.url} alt={image.alt} className="gallery-image" />
              )}
              {onRemoveExistingImage ? (
                <button
                  type="button"
                  className="icon-button icon-button-muted image-dropzone-remove"
                  aria-label="Убрать изображение"
                  onClick={(event) => {
                    event.stopPropagation();
                    onRemoveExistingImage(image.id);
                  }}
                >
                  <X className="nav-icon" />
                </button>
              ) : null}
            </div>
          ))}

          {previewImages.map((image, index) => (
            <div key={image.id} className="image-dropzone-card">
              {image.mediaType === "video" ? (
                <video src={image.url} className="gallery-image" controls />
              ) : (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={image.url} alt={image.alt} className="gallery-image" />
              )}
              {onRemoveFile ? (
                <button
                  type="button"
                  className="icon-button icon-button-muted image-dropzone-remove"
                  aria-label={`Убрать новое изображение ${index + 1}`}
                  onClick={(event) => {
                    event.stopPropagation();
                    onRemoveFile(index);
                  }}
                >
                  <X className="nav-icon" />
                </button>
              ) : null}
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}
