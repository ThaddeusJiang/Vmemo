export const Toast = {
    mounted() {
        const id = this.el.id;
        const key = this.el.dataset.key;

        // Execute JS.push and hide after 5 seconds
        setTimeout(() => {
            // Send event to LiveView
            this.pushEvent("lv:clear-flash", { key: key });

            // Apply hide effect
            const element = document.getElementById(id);
            if (element) {
                element.style.transition = "opacity 0.5s ease-out";
                element.style.opacity = "0";

                // setTimeout(() => {
                //     element.remove(); // Fully remove from DOM
                // }, 500); // Wait for animation to finish
            }
        }, 5000); // 5-second delay
    }
}
