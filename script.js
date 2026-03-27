gsap.registerPlugin(ScrollTrigger);

// Custom Cursor & Ripple
const cursor = document.querySelector('.cursor');
document.addEventListener('mousemove', (e) => {
    gsap.to(cursor, { x: e.clientX, y: e.clientY, duration: 0.15 });
});

document.addEventListener('click', (e) => {
    const ripple = document.createElement('div');
    ripple.className = 'ripple';
    ripple.style.left = e.clientX + 'px';
    ripple.style.top = e.clientY + 'px';
    document.body.appendChild(ripple);
    setTimeout(() => ripple.remove(), 1000);
});

const hoverTargets = document.querySelectorAll('.hover-target, .magnetic, .btn, .logo, .nav-links a');
hoverTargets.forEach(t => {
    t.addEventListener('mouseenter', () => cursor.classList.add('hover-active'));
    t.addEventListener('mouseleave', () => cursor.classList.remove('hover-active'));
});

// Magnetic Buttons
document.querySelectorAll('.magnetic').forEach(m => {
    m.addEventListener('mousemove', (e) => {
        const rect = m.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;
        gsap.to(m.querySelector('.btn'), { x: x * 0.4, y: y * 0.4, duration: 0.3 });
    });
    m.addEventListener('mouseleave', (e) => {
        gsap.to(m.querySelector('.btn'), { x: 0, y: 0, duration: 0.7, ease: "elastic.out(1, 0.3)" });
    });
});

// 3D Tilt
document.querySelectorAll('.iphone-frame').forEach(el => {
    el.addEventListener('mousemove', (e) => {
        const rect = el.getBoundingClientRect();
        const x = (e.clientX - rect.left) / rect.width - 0.5;
        const y = (e.clientY - rect.top) / rect.height - 0.5;
        gsap.to(el, { rotationY: x * 20, rotationX: -y * 20, transformPerspective: 1000, duration: 0.6 });
    });
    el.addEventListener('mouseleave', (e) => {
        gsap.to(el, { rotationY: 0, rotationX: 0, duration: 1 });
    });
});

// Chaos to Zen Slider Logic
const slider = document.getElementById('zen-slider');
const divider = document.getElementById('slider-divider');
const sideZen = document.querySelector('.side-zen');
const zenHaiku = document.getElementById('zen-haiku');

if (slider) {
    slider.addEventListener('mousemove', (e) => {
        const rect = slider.getBoundingClientRect();
        const x = ((e.clientX - rect.left) / rect.width) * 100;
        if (x > 0 && x < 100) {
            divider.style.left = x + '%';
            sideZen.style.clipPath = `inset(0 ${100 - x}% 0 0)`;
            zenHaiku.style.opacity = x > 80 ? 1 : 0; 
        }
    });
}

// Animations
gsap.to('.char', { y: 0, stagger: 0.05, delay: 0.2, ease: "power4.out" });
gsap.to('.hero-subtitle span', { y: 0, stagger: 0.1, delay: 0.6 });

// Levitation (Continuous Floating)
gsap.utils.toArray('.iphone-frame').forEach((frame, i) => {
    gsap.to(frame, {
        y: "-=20",
        duration: 2 + (i * 0.5),
        repeat: -1,
        yoyo: true,
        ease: "sine.inOut",
        delay: i * 0.3
    });
});

// Parallax Scroll for Mockups
gsap.utils.toArray('.mockup-block').forEach(block => {
    gsap.fromTo(block, 
        { y: 50 },
        {
            y: -50,
            ease: "none",
            scrollTrigger: {
                trigger: block,
                start: "top bottom",
                end: "bottom top",
                scrub: 1.5
            }
        }
    );
});

// Entrance Animation for Mockups
gsap.utils.toArray('.iphone-frame').forEach(frame => {
    gsap.from(frame, {
        scale: 0.8,
        opacity: 0,
        duration: 1.5,
        ease: "expo.out",
        scrollTrigger: {
            trigger: frame,
            start: "top 90%"
        }
    });
});

gsap.utils.toArray('.reveal-text').forEach(text => {
    gsap.from(text.children, {
        y: 50, opacity: 0, duration: 1, stagger: 0.1,
        scrollTrigger: { trigger: text, start: "top 80%" }
    });
});
