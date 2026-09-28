/**
 * Shizuku Documentation Platform - High Performance SPA Engine
 */

(function () {
  'use strict';

  // Navigation Items Manifest
  const NAV_TREE = [
    {
      group: '项目概述 / Overview',
      items: [
        { title: '🏠 资料库总览 (README)', route: '/readme' }
      ]
    },
    {
      group: '核心技术工程指南 / Flagship Articles',
      items: [
        { title: '🇨🇳 中文工程技术指南', route: '/articles/leaf-galgame-port-zh', lang: 'zh' },
        { title: '🇺🇸 English Technical Guide', route: '/articles/leaf-galgame-port-en', lang: 'en' },
        { title: '🇯🇵 日本語技術仕様書', route: '/articles/leaf-galgame-port-jp', lang: 'jp' }
      ]
    },
    {
      group: '数据格式逆向规范 / Format Specifications',
      items: [
        { title: '📦 LEAFPACK 归档与解密', route: '/docs/containers' },
        { title: '🖼 LFG 图像与位交织解码', route: '/docs/lfg' },
        { title: '📜 SCN 脚本与双层虚拟机', route: '/docs/scripts' },
        { title: '🎵 LAC 音频与 BGM 映射', route: '/docs/audio' },
        { title: '⏳ LVNS 引擎版本演进史', route: '/docs/history' },
        { title: '📁 Windows 95 原版文件清单', route: '/docs/original-files' },
        { title: '⚙️ 未知指令与 Skip Opcode', route: '/docs/unknown-opcodes' },
        { title: '🎮 GBALVNS 架构参考', route: '/docs/gbalvns' },
        { title: '🕹 GBA 移植对比分析', route: '/docs/sizuku-gba' }
      ]
    },
    {
      group: '研发报告与交接日志 / Reports & Logs',
      items: [
        { title: '🔬 Phase 0/1 初始研究报告', route: '/reports/SHIZUKU_PORT_RESEARCH_REPORT' },
        { title: '📝 完整研发交接日志 (HANDOVER)', route: '/reports/HANDOVER' },
        { title: '🎯 里程碑计划与验收标准', route: '/reports/MILESTONES' },
        { title: '📋 上下文恢复基线', route: '/reports/RESUME_PROMPT' }
      ]
    },
    {
      group: '逆向分析工具链 / Tools & Reference',
      items: [
        { title: '🧰 Python CLI 工具集与独立脚本', route: '/tools/overview' },
        { title: '🖼 视觉验证产物与字库图谱', route: '/preview/gallery' }
      ]
    }
  ];

  // Flattened ordered list for prev/next pagination
  const ORDERED_DOCS = [];
  NAV_TREE.forEach(group => {
    group.items.forEach(item => {
      ORDERED_DOCS.push(item);
    });
  });

  const state = {
    currentRoute: '',
    currentTheme: localStorage.getItem('shizuku_theme') || 'auto'
  };

  // DOM Elements
  const elSidebar = document.getElementById('sidebar-nav');
  const elContent = document.getElementById('doc-content');
  const elToc = document.getElementById('toc-list');
  const elBreadcrumb = document.getElementById('breadcrumb');
  const elSearchInput = document.getElementById('search-input');
  const elSearchResults = document.getElementById('search-results');
  const elThemeBtn = document.getElementById('theme-toggle-btn');
  const elMenuToggle = document.getElementById('menu-toggle');

  // Initialize Marked
  if (window.marked) {
    marked.setOptions({
      gfm: true,
      breaks: false,
      headerIds: true,
      mangle: false
    });
  }

  // 1. Theme Management
  function applyTheme(theme) {
    state.currentTheme = theme;
    localStorage.setItem('shizuku_theme', theme);
    if (theme === 'dark' || (theme === 'auto' && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      document.documentElement.setAttribute('data-theme', 'dark');
      if (elThemeBtn) elThemeBtn.textContent = '☀️';
    } else {
      document.documentElement.removeAttribute('data-theme');
      if (elThemeBtn) elThemeBtn.textContent = '🌙';
    }
  }

  if (elThemeBtn) {
    elThemeBtn.addEventListener('click', () => {
      const nextTheme = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      applyTheme(nextTheme);
    });
  }
  applyTheme(state.currentTheme);

  // 2. Render Left Sidebar Navigation
  function renderSidebar() {
    if (!elSidebar) return;
    let html = '';
    NAV_TREE.forEach(group => {
      html += `<div class="nav-group">`;
      html += `<div class="nav-group-title">${group.group}</div>`;
      group.items.forEach(item => {
        const isActive = (state.currentRoute === item.route || (item.route === '/readme' && state.currentRoute === '/'));
        html += `<a href="#${item.route}" class="nav-link ${isActive ? 'active' : ''}" data-route="${item.route}">${item.title}</a>`;
      });
      html += `</div>`;
    });
    elSidebar.innerHTML = html;
  }

  // 3. Link Translation (Turns internal relative markdown links into SPA hash routes)
  function translateInternalLinks(container) {
    const links = container.querySelectorAll('a');
    links.forEach(a => {
      const href = a.getAttribute('href');
      if (!href) return;

      // Skip external links
      if (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('mailto:') || href.startsWith('#')) {
        if (!href.startsWith('#')) {
          a.setAttribute('target', '_blank');
          a.setAttribute('rel', 'noopener noreferrer');
        }
        return;
      }

      // Check for known markdown file mapping
      let targetRoute = '';
      if (href.includes('leaf-galgame-port-zh')) targetRoute = '/articles/leaf-galgame-port-zh';
      else if (href.includes('leaf-galgame-port-en')) targetRoute = '/articles/leaf-galgame-port-en';
      else if (href.includes('leaf-galgame-port-jp')) targetRoute = '/articles/leaf-galgame-port-jp';
      else if (href.includes('containers')) targetRoute = '/docs/containers';
      else if (href.includes('lfg')) targetRoute = '/docs/lfg';
      else if (href.includes('scripts')) targetRoute = '/docs/scripts';
      else if (href.includes('audio')) targetRoute = '/docs/audio';
      else if (href.includes('history')) targetRoute = '/docs/history';
      else if (href.includes('original-files')) targetRoute = '/docs/original-files';
      else if (href.includes('unknown-opcodes')) targetRoute = '/docs/unknown-opcodes';
      else if (href.includes('gbalvns')) targetRoute = '/docs/gbalvns';
      else if (href.includes('sizuku-gba')) targetRoute = '/docs/sizuku-gba';
      else if (href.includes('SHIZUKU_PORT_RESEARCH_REPORT')) targetRoute = '/reports/SHIZUKU_PORT_RESEARCH_REPORT';
      else if (href.includes('HANDOVER')) targetRoute = '/reports/HANDOVER';
      else if (href.includes('MILESTONES')) targetRoute = '/reports/MILESTONES';
      else if (href.includes('RESUME_PROMPT')) targetRoute = '/reports/RESUME_PROMPT';

      if (targetRoute) {
        a.setAttribute('href', `#${targetRoute}`);
      }
    });
  }

  // 4. Code Blocks Enhancement (Copy button + language badge)
  function enhanceCodeBlocks(container) {
    const preBlocks = container.querySelectorAll('pre');
    preBlocks.forEach(pre => {
      const code = pre.querySelector('code');
      if (!code) return;

      const langMatch = code.className.match(/language-([a-z0-9_-]+)/i);
      const langName = langMatch ? langMatch[1] : 'text';

      const wrapper = document.createElement('div');
      wrapper.className = 'code-wrapper';

      const header = document.createElement('div');
      header.className = 'code-header';
      header.innerHTML = `<span>${langName}</span><button class="copy-btn">Copy</button>`;

      const btn = header.querySelector('.copy-btn');
      btn.addEventListener('click', () => {
        navigator.clipboard.writeText(code.innerText).then(() => {
          btn.textContent = 'Copied!';
          setTimeout(() => { btn.textContent = 'Copy'; }, 1800);
        });
      });

      pre.parentNode.insertBefore(wrapper, pre);
      wrapper.appendChild(header);
      wrapper.appendChild(pre);
    });

    if (window.Prism) {
      Prism.highlightAllUnder(container);
    }
  }

  // 5. Dynamic TOC Generation & Scrollspy
  function buildToc(container) {
    if (!elToc) return;
    elToc.innerHTML = '';

    const headings = container.querySelectorAll('h2, h3');
    if (headings.length === 0) {
      elToc.innerHTML = '<li class="toc-item"><span style="color:var(--text-muted);font-size:0.8rem;">无章节目录</span></li>';
      return;
    }

    headings.forEach((heading, idx) => {
      let id = heading.id;
      if (!id) {
        id = 'heading-' + idx;
        heading.id = id;
      }
      const isH3 = heading.tagName.toLowerCase() === 'h3';
      const li = document.createElement('li');
      li.className = `toc-item ${isH3 ? 'h3' : 'h2'}`;
      li.innerHTML = `<a href="#${id}" class="toc-link" data-id="${id}">${heading.textContent}</a>`;
      elToc.appendChild(li);
    });

    // Smooth scroll for TOC links
    elToc.querySelectorAll('.toc-link').forEach(link => {
      link.addEventListener('click', e => {
        e.preventDefault();
        const id = link.getAttribute('data-id');
        const target = document.getElementById(id);
        if (target) {
          window.scrollTo({
            top: target.offsetTop - 75,
            behavior: 'smooth'
          });
        }
      });
    });

    // Setup IntersectionObserver for Scrollspy
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const id = entry.target.id;
          elToc.querySelectorAll('.toc-link').forEach(link => {
            if (link.getAttribute('data-id') === id) {
              link.classList.add('active');
            } else {
              link.classList.remove('active');
            }
          });
        }
      });
    }, { rootMargin: '-60px 0px -70% 0px' });

    headings.forEach(h => observer.observe(h));
  }

  // 6. Pagination (Prev / Next Cards)
  function renderPagination(currentRoute) {
    const normRoute = (currentRoute === '/' ? '/readme' : currentRoute);
    const currIdx = ORDERED_DOCS.findIndex(d => d.route === normRoute);
    if (currIdx === -1) return '';

    const prevDoc = currIdx > 0 ? ORDERED_DOCS[currIdx - 1] : null;
    const nextDoc = currIdx < ORDERED_DOCS.length - 1 ? ORDERED_DOCS[currIdx + 1] : null;

    let html = `<div class="pagination-nav">`;
    if (prevDoc) {
      html += `<a href="#${prevDoc.route}" class="page-card prev">
        <span class="page-card-sub">← Previous</span>
        <span class="page-card-title">${prevDoc.title}</span>
      </a>`;
    } else {
      html += `<div></div>`;
    }
    if (nextDoc) {
      html += `<a href="#${nextDoc.route}" class="page-card next" style="text-align:right;">
        <span class="page-card-sub">Next →</span>
        <span class="page-card-title">${nextDoc.title}</span>
      </a>`;
    }
    html += `</div>`;
    return html;
  }

  // 7. Route Navigator & Loader
  async function loadDocument(route) {
    let cleanRoute = route.split('#')[0];
    if (!cleanRoute || cleanRoute === '/') cleanRoute = '/readme';

    state.currentRoute = cleanRoute;
    renderSidebar();

    // Update Top Language Selector Active State
    document.querySelectorAll('.lang-tab').forEach(tab => {
      const tabLang = tab.getAttribute('data-lang');
      if (cleanRoute.includes('-' + tabLang)) {
        tab.classList.add('active');
      } else {
        tab.classList.remove('active');
      }
    });

    // Update Breadcrumb
    const activeItem = ORDERED_DOCS.find(d => d.route === cleanRoute);
    if (elBreadcrumb) {
      elBreadcrumb.innerHTML = `<a href="#/readme">资料库</a> &gt; <span>${activeItem ? activeItem.title : cleanRoute}</span>`;
    }

    // Retrieve Markdown Text
    let mdText = '';
    if (window.DOCS_DATA && window.DOCS_DATA[cleanRoute]) {
      mdText = window.DOCS_DATA[cleanRoute];
    } else {
      try {
        const resp = await fetch(cleanRoute.replace('/', '') + '.md');
        if (resp.ok) {
          mdText = await resp.text();
        }
      } catch (err) {
        console.warn('Fetch fallback error:', err);
      }
    }

    if (!mdText) {
      elContent.innerHTML = `<h1>404 · 文档未找到</h1><p>请求的路径 <code>${cleanRoute}</code> 不存在。</p><p><a href="#/readme">返回首页</a></p>`;
      return;
    }

    // Convert Markdown to HTML
    const htmlBody = marked.parse(mdText);
    const paginationHtml = renderPagination(cleanRoute);

    // Standard requested footer
    const footerHtml = `
      <footer class="doc-footer">
        <div class="footer-inner">
          <p class="footer-title">Shizuku_macos_restore_study · Leaf LVNS Engine Reverse Engineering & Native macOS Restoration</p>
          <p class="footer-author">jill 推特<a href="https://x.com/jill05617147" target="_blank" rel="noopener noreferrer">@jill05617147</a> 微博<a href="https://weibo.com/n/jill_mk3" target="_blank" rel="noopener noreferrer">@jill_mk3</a></p>
        </div>
      </footer>
    `;

    elContent.innerHTML = htmlBody + paginationHtml + footerHtml;

    translateInternalLinks(elContent);
    enhanceCodeBlocks(elContent);
    buildToc(elContent);

    // Close mobile drawer if open
    const sidebar = document.querySelector('aside.left-sidebar');
    if (sidebar) sidebar.classList.remove('open');

    // Scroll to Top or Anchor
    const anchorMatch = route.match(/#([^/]+)$/);
    if (anchorMatch && anchorMatch[1]) {
      const anchorEl = document.getElementById(anchorMatch[1]);
      if (anchorEl) {
        anchorEl.scrollIntoView({ behavior: 'smooth' });
        return;
      }
    }
    window.scrollTo(0, 0);
  }

  // 8. Hash Change Listener
  function handleHashChange() {
    const rawHash = window.location.hash.slice(1) || '/readme';
    loadDocument(rawHash);
  }

  window.addEventListener('hashchange', handleHashChange);

  // 9. Real-time Search Engine
  if (elSearchInput && elSearchResults) {
    elSearchInput.addEventListener('input', e => {
      const q = e.target.value.trim().toLowerCase();
      if (!q) {
        elSearchResults.style.display = 'none';
        return;
      }

      const results = [];
      if (window.DOCS_DATA) {
        for (const [route, text] of Object.entries(window.DOCS_DATA)) {
          if (route === '/') continue;
          const matchIdx = text.toLowerCase().indexOf(q);
          if (matchIdx !== -1) {
            const docInfo = ORDERED_DOCS.find(d => d.route === route);
            const start = Math.max(0, matchIdx - 30);
            const snippet = text.substring(start, start + 90).replace(/\n/g, ' ');
            results.push({
              title: docInfo ? docInfo.title : route,
              route: route,
              snippet: snippet
            });
            if (results.length >= 8) break;
          }
        }
      }

      if (results.length > 0) {
        let resHtml = '';
        results.forEach(r => {
          resHtml += `<div class="search-result-item" data-route="${r.route}">
            <div class="search-result-title">${r.title}</div>
            <div class="search-result-snippet">...${r.snippet}...</div>
          </div>`;
        });
        elSearchResults.innerHTML = resHtml;
        elSearchResults.style.display = 'block';

        elSearchResults.querySelectorAll('.search-result-item').forEach(item => {
          item.addEventListener('click', () => {
            const targetRoute = item.getAttribute('data-route');
            window.location.hash = '#' + targetRoute;
            elSearchResults.style.display = 'none';
            elSearchInput.value = '';
          });
        });
      } else {
        elSearchResults.innerHTML = '<div style="padding:10px;color:var(--text-muted);font-size:0.85rem;">未找到相关文档内容</div>';
        elSearchResults.style.display = 'block';
      }
    });

    document.addEventListener('click', e => {
      if (!elSearchInput.contains(e.target) && !elSearchResults.contains(e.target)) {
        elSearchResults.style.display = 'none';
      }
    });
  }

  // 10. Mobile Menu Drawer Toggle
  if (elMenuToggle) {
    elMenuToggle.addEventListener('click', () => {
      const sidebar = document.querySelector('aside.left-sidebar');
      if (sidebar) sidebar.classList.toggle('open');
    });
  }

  // Initial Boot
  renderSidebar();
  handleHashChange();
})();
