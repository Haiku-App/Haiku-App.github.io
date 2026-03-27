gsap.registerPlugin(ScrollTrigger);

// Custom Cursor
const cursor = document.querySelector('.cursor');
document.addEventListener('mousemove', (e) => {
    gsap.to(cursor, {
        x: e.clientX,
        y: e.clientY,
        duration: 0.1,
        ease: "power2.out"
    });
});

// Hover effects for cursor
document.querySelectorAll('a, .cta-btn').forEach(el => {
    el.addEventListener('mouseenter', () => {
        gsap.to(cursor, { scale: 4, opacity: 0.5, duration: 0.3 });
    });
    el.addEventListener('mouseleave', () => {
        gsap.to(cursor, { scale: 1, opacity: 1, duration: 0.3 });
    });
});

// Hero Animation
const tl = gsap.timeline();
tl.to('.hero-title', { opacity: 1, y: 0, duration: 2, ease: "expo.out" })
  .to('.hero-tagline', { opacity: 1, duration: 1.5, ease: "power2.out" }, "-=1")
  .to('.cta-btn', { opacity: 1, duration: 1, ease: "power2.out" }, "-=0.5");

// Background Visual Animation (Parallax-ish)
gsap.to('.flow-ring', {
    scale: 1.5,
    opacity: 0,
    stagger: 0.5,
    duration: 10,
    repeat: -1,
    ease: "none"
});

// Scroll Reveal for Haiku Text
gsap.utils.toArray('.haiku-text').forEach(text => {
    const lines = text.querySelectorAll('.haiku-line');
    gsap.to(lines, {
        opacity: 1,
        y: 0,
        stagger: 0.3,
        duration: 1.5,
        ease: "power3.out",
        scrollTrigger: {
            trigger: text,
            start: "top 80%",
            end: "bottom 20%",
            toggleActions: "play none none reverse"
        }
    });
});

// Scroll Reveal for Description
gsap.utils.toArray('.description').forEach(desc => {
    gsap.to(desc, {
        opacity: 1,
        duration: 2,
        ease: "power2.out",
        scrollTrigger: {
            trigger: desc,
            start: "top 85%",
        }
    });
});

// Visual Elements Paralax/Float
gsap.utils.toArray('.soul-visual').forEach(visual => {
    gsap.fromTo(visual, 
        { y: 100, opacity: 0 },
        { 
            y: -100, 
            opacity: 1,
            ease: "none",
            scrollTrigger: {
                trigger: visual,
                start: "top bottom",
                end: "bottom top",
                scrub: 1
            }
        }
    );
});

// Clock Hands Animation
gsap.to('.clock-hands', {
    rotation: 360,
    duration: 60,
    repeat: -1,
    ease: "none",
    transformOrigin: "center center"
});

// Smooth Scroll Feel (Native CSS is often better, but we can nudge it)
// Optional: Add a simple lerp for scroll if needed, but standard scrub is fine for now.
