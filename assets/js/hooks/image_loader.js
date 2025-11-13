export const ImageLoader = {
    mounted() {
        this.el.classList.add('blur-sm');

        const removeBlur = () => {
            this.el.classList.remove('blur-sm');
        };

        this.el.addEventListener('load', removeBlur);
        this.el.addEventListener('error', removeBlur);

        if (this.el.complete && (this.el.naturalWidth > 0 || this.el.naturalHeight > 0)) {
            removeBlur();
        }
    }
}
