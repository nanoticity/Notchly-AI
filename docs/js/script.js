document.addEventListener('DOMContentLoaded', () => {
    const backgroundLiquid = document.querySelector('.background-liquid-gray');
    const macScreenFrame = document.querySelector('.mac-screen-frame');

    // --- NEW: Page Load Elements Staggered Fade-In ---
    const animatableElements = document.querySelectorAll('.animatable-onload');
    let delay = 0;
    const delayIncrement = 150; // Milliseconds between each element's animation start

    animatableElements.forEach(element => {
        // Use requestAnimationFrame for smoother rendering
        requestAnimationFrame(() => {
            // Set a CSS custom property for the transition-delay
            element.style.setProperty('--animation-delay', `${delay}ms`);
            element.classList.add('loaded'); // Add 'loaded' class to trigger animation
        });
        delay += delayIncrement;
    });
    // --- END NEW ---


    // Subtle mouse parallax for the gray liquid background
    document.addEventListener('mousemove', (e) => {
        const x = (e.clientX / window.innerWidth - 0.5) * 20;
        const y = (e.clientY / window.innerHeight - 0.5) * 20;

        if (backgroundLiquid) {
            backgroundLiquid.style.transform = `translate(${x}px, ${y}px)`;
        }
    });

    // Animate app icon in notch on hover (simulating subtle activity)
    if (macScreenFrame) {
        const appIcon = macScreenFrame.querySelector('.app-icon-mac');
        const notchStatus = macScreenFrame.querySelector('.notch-status');
        let intervalId;

        macScreenFrame.addEventListener('mouseenter', () => {
            clearInterval(intervalId);
            appIcon.style.transition = 'transform 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94)';

            let pulseScale = 1;
            let growing = true;
            intervalId = setInterval(() => {
                if (growing) {
                    pulseScale += 0.02;
                    if (pulseScale >= 1.1) growing = false;
                } else {
                    pulseScale -= 0.02;
                    if (pulseScale <= 1) growing = true;
                }
                appIcon.style.transform = `scale(${pulseScale})`;
            }, 120);

            if (notchStatus) {
                notchStatus.textContent = 'Active';
            }
        });

        macScreenFrame.addEventListener('mouseleave', () => {
            clearInterval(intervalId);
            appIcon.style.transform = 'scale(1)';
            appIcon.style.transition = 'transform 0.3s ease-out';

            if (notchStatus) {
                notchStatus.textContent = 'Online';
            }
        });
    }

    // Overall subtle scale for all glass elements on hover
    const glassElements = document.querySelectorAll('.glass-nav, .glass-card, .glass-button, .feature-item');

    glassElements.forEach(el => {
        el.addEventListener('mouseenter', () => {
            el.style.transform = 'scale(1.005)';
        });

        el.addEventListener('mouseleave', () => {
            el.style.transform = 'scale(1)';
        });
    });
});