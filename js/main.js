/* Nico SW Photographie — interactions */
(function () {
  'use strict';

  var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var isTouch = window.matchMedia('(hover: none), (pointer: coarse)').matches;

  /* ---------- Curtain transition ---------- */
  var curtain = document.querySelector('.curtain');

  function openCurtain() {
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        curtain.classList.add('is-open');
      });
    });
  }
  openCurtain();

  document.addEventListener('click', function (e) {
    if (e.defaultPrevented) return; // already handled (e.g. lightbox trigger)
    var link = e.target.closest('a[href]');
    if (!link) return;
    if (link.target === '_blank' || link.hasAttribute('download') || link.hasAttribute('data-lightbox')) return;
    var url;
    try { url = new URL(link.href, window.location.href); } catch (err) { return; }
    if (url.origin !== window.location.origin) return;
    if (url.pathname === window.location.pathname && url.hash) return; // in-page anchors
    if (link.href === window.location.href) return;

    e.preventDefault();
    curtain.classList.remove('is-open');
    curtain.classList.add('is-leaving');
    var duration = reducedMotion ? 0 : 700;
    window.setTimeout(function () {
      window.location.href = link.href;
    }, duration);
  });

  /* ---------- Header scroll state + mobile nav ---------- */
  var header = document.querySelector('.site-header');
  var navToggle = document.querySelector('.nav-toggle');
  var mainNav = document.querySelector('.main-nav');

  function onScroll() {
    if (!header) return;
    if (window.scrollY > 40) header.classList.add('is-scrolled');
    else header.classList.remove('is-scrolled');
  }
  document.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  if (navToggle && mainNav) {
    navToggle.addEventListener('click', function () {
      var open = mainNav.classList.toggle('is-open');
      navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    mainNav.querySelectorAll('a').forEach(function (a) {
      a.addEventListener('click', function () {
        mainNav.classList.remove('is-open');
        navToggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  /* ---------- Custom cursor ---------- */
  if (!isTouch) {
    var ring = document.querySelector('.cursor-ring');
    var dot = document.querySelector('.cursor-dot');
    if (ring && dot) {
      var mouseX = window.innerWidth / 2, mouseY = window.innerHeight / 2;
      var ringX = mouseX, ringY = mouseY;

      document.addEventListener('mousemove', function (e) {
        mouseX = e.clientX; mouseY = e.clientY;
        dot.style.transform = 'translate(' + mouseX + 'px,' + mouseY + 'px) translate(-50%,-50%)';
        ring.classList.remove('is-hidden');
        dot.classList.remove('is-hidden');
      });
      document.addEventListener('mouseleave', function () {
        ring.classList.add('is-hidden'); dot.classList.add('is-hidden');
      });

      function raf() {
        ringX += (mouseX - ringX) * 0.16;
        ringY += (mouseY - ringY) * 0.16;
        ring.style.transform = 'translate(' + ringX + 'px,' + ringY + 'px) translate(-50%,-50%)';
        requestAnimationFrame(raf);
      }
      requestAnimationFrame(raf);

      var hoverTargets = 'a, button, .gallery__item, .duality__card, input, textarea';
      document.addEventListener('mouseover', function (e) {
        if (e.target.closest(hoverTargets)) ring.classList.add('is-active');
      });
      document.addEventListener('mouseout', function (e) {
        if (e.target.closest(hoverTargets)) ring.classList.remove('is-active');
      });
    }
  }

  /* ---------- Scroll reveal ---------- */
  var revealEls = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window && revealEls.length) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.15, rootMargin: '0px 0px -60px 0px' });
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add('is-visible'); });
  }

  /* ---------- Lightbox (cosplay gallery) ---------- */
  var triggers = Array.prototype.slice.call(document.querySelectorAll('[data-lightbox]'));
  if (triggers.length) {
    var lightbox = document.querySelector('.lightbox');
    var lbImg = lightbox.querySelector('img');
    var lbCaption = lightbox.querySelector('.lightbox__caption');
    var current = 0;

    function showImage(i) {
      current = (i + triggers.length) % triggers.length;
      var t = triggers[current];
      lbImg.src = t.getAttribute('href') || t.dataset.full;
      lbImg.alt = t.dataset.caption || '';
      lbCaption.textContent = t.dataset.caption || '';
    }
    function openLightbox(i) {
      showImage(i);
      lightbox.classList.add('is-open');
      document.body.style.overflow = 'hidden';
    }
    function closeLightbox() {
      lightbox.classList.remove('is-open');
      document.body.style.overflow = '';
    }
    triggers.forEach(function (t, i) {
      t.addEventListener('click', function (e) {
        e.preventDefault();
        openLightbox(i);
      });
    });
    lightbox.querySelector('.lightbox__close').addEventListener('click', closeLightbox);
    lightbox.addEventListener('click', function (e) { if (e.target === lightbox) closeLightbox(); });
    var prevBtn = lightbox.querySelector('.lightbox__prev');
    var nextBtn = lightbox.querySelector('.lightbox__next');
    if (prevBtn) prevBtn.addEventListener('click', function () { showImage(current - 1); });
    if (nextBtn) nextBtn.addEventListener('click', function () { showImage(current + 1); });
    document.addEventListener('keydown', function (e) {
      if (!lightbox.classList.contains('is-open')) return;
      if (e.key === 'Escape') closeLightbox();
      if (e.key === 'ArrowRight') showImage(current + 1);
      if (e.key === 'ArrowLeft') showImage(current - 1);
    });
  }

  /* ---------- Contact form (FormSubmit AJAX) ---------- */
  var contactForm = document.getElementById('contact-form');
  if (contactForm) {
    var statusEl = contactForm.querySelector('.form-status');
    var submitBtn = contactForm.querySelector('.form-submit');

    function setStatus(text, kind) {
      statusEl.textContent = text;
      statusEl.className = 'form-status is-visible is-' + kind;
    }

    contactForm.addEventListener('submit', function (e) {
      e.preventDefault();
      if (contactForm.querySelector('[name="_honey"]').value) return; // bot trap

      submitBtn.setAttribute('disabled', 'disabled');
      statusEl.className = 'form-status';

      fetch(contactForm.action, {
        method: 'POST',
        headers: { Accept: 'application/json' },
        body: new FormData(contactForm)
      }).then(function (res) {
        if (res.ok) {
          setStatus('Message envoyé — merci, je reviens vers toi rapidement !', 'success');
          contactForm.reset();
        } else {
          setStatus("L'envoi a échoué. Réessaie, ou écris-moi directement sur Instagram.", 'error');
        }
      }).catch(function () {
        setStatus("L'envoi a échoué. Réessaie, ou écris-moi directement sur Instagram.", 'error');
      }).finally(function () {
        submitBtn.removeAttribute('disabled');
      });
    });
  }

  /* ---------- Intime veil interaction ---------- */
  var veil = document.querySelector('.veil-panel__reveal');
  if (veil) {
    var panel = document.querySelector('.veil-panel');
    function setPos(x, y) {
      var rect = panel.getBoundingClientRect();
      var mx = ((x - rect.left) / rect.width) * 100;
      var my = ((y - rect.top) / rect.height) * 100;
      veil.style.setProperty('--mx', mx + '%');
      veil.style.setProperty('--my', my + '%');
    }
    panel.addEventListener('mousemove', function (e) { setPos(e.clientX, e.clientY); });
    panel.addEventListener('touchmove', function (e) {
      var t = e.touches[0];
      if (t) setPos(t.clientX, t.clientY);
    }, { passive: true });

    if (!isTouch) {
      var t0 = 0;
      function idleDrift(ts) {
        if (!t0) t0 = ts;
        var elapsed = (ts - t0) / 1000;
        var rect = panel.getBoundingClientRect();
        var cx = rect.width * (0.5 + 0.28 * Math.sin(elapsed * 0.35));
        var cy = rect.height * (0.5 + 0.22 * Math.cos(elapsed * 0.27));
        veil.style.setProperty('--mx', cx + 'px');
        veil.style.setProperty('--my', cy + 'px');
        requestAnimationFrame(idleDrift);
      }
      requestAnimationFrame(idleDrift);
    }
  }
})();
