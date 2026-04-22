const isThumbnail = (el) => {
    const className = el.className || "";
    const rect = el.getBoundingClientRect();
    const width = rect.width || el.clientWidth || 0;
    const height = rect.height || el.clientHeight || 0;

    return (
        /\bnotification-item-thumb\b/.test(className) ||
        /\bh-(?:8|9|10|11|12|14|16)\b/.test(className) ||
        /\bw-(?:8|9|10|11|12|14|16)\b/.test(className) ||
        (width > 0 && width <= 96 && height > 0 && height <= 96)
    );
};

const BLANK_IMAGE_SRC =
    "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==";

export const applyImageFallback = (el) => {
    if (!el || el.dataset.fallbackApplied === "true") {
        return;
    }

    const useThumbFallback = isThumbnail(el);
    const wrapper = el.closest(".img-fallback-wrap");

    el.dataset.fallbackApplied = "true";
    el.classList.add("image-fallback");
    el.src = BLANK_IMAGE_SRC;
    el.alt = "Image unavailable";
    el.title = "Image unavailable";

    if (wrapper) {
        wrapper.classList.add("is-fallback");
        wrapper.title = "Image unavailable";

        if (useThumbFallback) {
            wrapper.classList.add("is-thumb-fallback");
            wrapper.classList.remove("is-block-fallback");
        } else {
            wrapper.classList.add("is-block-fallback");
            wrapper.classList.remove("is-thumb-fallback");
        }
    }
};

export const ImageLoader = {
    mounted() {
        this.el.classList.add('blur-sm');

        const removeBlur = () => {
            this.el.classList.remove('blur-sm');
        };

        const applyFallback = () => {
            applyImageFallback(this.el);
            removeBlur();
        };

        this.el.addEventListener('load', removeBlur);
        this.el.addEventListener('error', applyFallback);

        if (this.el.complete) {
            if (this.el.naturalWidth > 0 || this.el.naturalHeight > 0) {
                removeBlur();
            } else {
                applyFallback();
            }
        }
    }
}
