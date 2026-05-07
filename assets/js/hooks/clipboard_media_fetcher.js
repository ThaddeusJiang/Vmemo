
export const ClipboardMediaFetcher = {
    mounted() {
        const fileInput = this.el.querySelector('input[type="file"]');

        if (!fileInput) {
            return;
        }

        const enableClickUpload = this.el.dataset.clickUploadArea === "true";

        if (enableClickUpload) {
            this.el.addEventListener("click", (event) => {
                const target = event.target;
                if (!(target instanceof Element)) return;
                if (target === fileInput || target.closest('button, a, input:not([type="file"]), textarea, select, [role="button"]')) {
                    return;
                }

                fileInput.click();
            });
        }

        window.addEventListener('paste', async (event) => {
            const items = event.clipboardData?.items;
            if (!items?.length) {
                return;
            }

            const dataTransfer = new DataTransfer();
            let hasNewImages = false;

            Array.from(fileInput.files).forEach(file => {
                dataTransfer.items.add(file);
            });

            Array.from(items).forEach(item => {
                if (item.kind === 'file' && item.type.startsWith('image/')) {
                    const file = item.getAsFile();
                    if (file) {
                        dataTransfer.items.add(file);
                        hasNewImages = true;
                    }
                }
            });
            if (hasNewImages) {
                fileInput.files = dataTransfer.files;
                fileInput.dispatchEvent(new Event('change', { bubbles: true }));
            }
        });
    }
}
