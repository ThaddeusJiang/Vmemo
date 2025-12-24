export const InfiniteScroll = {
    mounted() {
        const observer = new IntersectionObserver((entries) => {
            if (entries[0].isIntersecting) {
                this.pushEvent("load-more", {})
            }
        })

        observer.observe(this.el)
    },

}
