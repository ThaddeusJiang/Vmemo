export const Focus = {
    mounted() {
        // Listen to focus events globally
    },
    
    handleEvent(event, payload) {
        if (event === "focus") {
            const { selector, delay = 100 } = payload;
            this.focusElement(selector, delay, payload);
        }
    },
    
    focusElement(selector, delay, payload) {
        setTimeout(() => {
            const element = document.querySelector(selector);
            if (element && typeof element.focus === 'function') {
                element.focus();
                
                // Only attempt text selection for elements that support select()
                if (payload?.select_all && typeof element.select === 'function') {
                    element.select();
                }
            }
        }, delay);
    }
}

// Global window event listener
window.addEventListener('phx:focus', (event) => {
    const { selector, delay = 100 } = event.detail;
    setTimeout(() => {
        const element = document.querySelector(selector);
        if (element && typeof element.focus === 'function') {
            element.focus();
            
            // Only attempt text selection for elements that support select()
            if (event.detail.select_all && typeof element.select === 'function') {
                element.select();
            }
        }
    }, delay);
});