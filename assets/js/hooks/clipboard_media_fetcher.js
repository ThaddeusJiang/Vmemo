
export const ClipboardMediaFetcher = {
    mounted() {
        const fileInput = this.el.querySelector('input[type="file"]');
        
        window.addEventListener('paste', async (event) => {
            const items = event.clipboardData?.items;
            if (!items?.length) {
                return;
            }

            const dataTransfer = new DataTransfer();
            let hasNewImages = false;

            // 保留现有文件
            Array.from(fileInput.files).forEach(file => {
                dataTransfer.items.add(file);
            });
            
            // 添加粘贴的图片
            Array.from(items).forEach(item => {
                if (item.kind === 'file' && item.type.startsWith('image/')) {
                    const file = item.getAsFile();
                    if (file) {
                        dataTransfer.items.add(file);
                        hasNewImages = true;
                    }
                }
            });

            // 只在有新图片时更新
            if (hasNewImages) {
                fileInput.files = dataTransfer.files;
                fileInput.dispatchEvent(new Event('change', { bubbles: true }));
            }
        });
    }
}
