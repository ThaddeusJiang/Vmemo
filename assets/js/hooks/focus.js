export const Focus = {
    mounted() {
        // 全局监听 focus 事件
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
                
                // 只有支持 select() 方法的元素才尝试选中文本
                if (payload?.select_all && typeof element.select === 'function') {
                    element.select();
                }
            }
        }, delay);
    }
}

// 全局的 window 事件监听器
window.addEventListener('phx:focus', (event) => {
    const { selector, delay = 100 } = event.detail;
    setTimeout(() => {
        const element = document.querySelector(selector);
        if (element && typeof element.focus === 'function') {
            element.focus();
            
            // 只有支持 select() 方法的元素才尝试选中文本
            if (event.detail.select_all && typeof element.select === 'function') {
                element.select();
            }
        }
    }, delay);
});