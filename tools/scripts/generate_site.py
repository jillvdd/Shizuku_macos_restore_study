# -*- coding: utf-8 -*-
import os
import re
import markdown

ROOT_DIR = "/Users/abc/Documents/Shizuku_macos_restore_study"
ARTICLES_DIR = os.path.join(ROOT_DIR, "articles")

CSS_CONTENT = """/* Modern Clean Typography & Responsive Theme */
:root {
    --bg-color: #f8fafc;
    --card-bg: #ffffff;
    --text-color: #1e293b;
    --text-muted: #64748b;
    --accent: #2563eb;
    --accent-hover: #1d4ed8;
    --border-color: #e2e8f0;
    --code-bg: #0f172a;
    --code-text: #f8fafc;
    --inline-code-bg: #f1f5f9;
    --inline-code-text: #0f172a;
    --header-bg: rgba(255, 255, 255, 0.85);
    --table-stripe: #f8fafc;
    --blockquote-border: #3b82f6;
    --shadow: 0 4px 6px -1px rgb(0 0 0 / 0.05), 0 2px 4px -2px rgb(0 0 0 / 0.05);
}

@media (prefers-color-scheme: dark) {
    :root {
        --bg-color: #0b0f19;
        --card-bg: #111827;
        --text-color: #f3f4f6;
        --text-muted: #9ca3af;
        --accent: #60a5fa;
        --accent-hover: #93c5fd;
        --border-color: #1f2937;
        --code-bg: #030712;
        --code-text: #e5e7eb;
        --inline-code-bg: #1f2937;
        --inline-code-text: #93c5fd;
        --header-bg: rgba(17, 24, 39, 0.85);
        --table-stripe: #131c2e;
        --blockquote-border: #60a5fa;
        --shadow: 0 4px 6px -1px rgb(0 0 0 / 0.3);
    }
}

* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Yu Gothic", "Meiryo", sans-serif;
    line-height: 1.75;
    background-color: var(--bg-color);
    color: var(--text-color);
    -webkit-font-smoothing: antialiased;
}

/* Header & Nav */
header.site-header {
    position: sticky;
    top: 0;
    z-index: 100;
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    background-color: var(--header-bg);
    border-bottom: 1px solid var(--border-color);
}

.nav-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0.85rem 1.5rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.logo-area {
    font-weight: 700;
    font-size: 1.1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.logo-area a {
    color: var(--text-color);
    text-decoration: none;
    transition: color 0.2s;
}

.logo-area a:hover {
    color: var(--accent);
}

.nav-links {
    display: flex;
    gap: 0.75rem;
    align-items: center;
    flex-wrap: wrap;
}

.lang-btn {
    padding: 0.4rem 0.8rem;
    border-radius: 6px;
    font-size: 0.88rem;
    font-weight: 500;
    text-decoration: none;
    border: 1px solid var(--border-color);
    color: var(--text-color);
    background-color: var(--card-bg);
    transition: all 0.2s;
}

.lang-btn:hover {
    border-color: var(--accent);
    color: var(--accent);
}

.lang-btn.active {
    background-color: var(--accent);
    color: #ffffff;
    border-color: var(--accent);
}

/* Layout */
.main-wrapper {
    max-width: 1200px;
    margin: 2rem auto;
    padding: 0 1.5rem;
    display: grid;
    grid-template-columns: 280px 1fr;
    gap: 2.5rem;
    align-items: start;
}

@media (max-width: 900px) {
    .main-wrapper {
        grid-template-columns: 1fr;
    }
}

/* Sidebar / TOC */
aside.toc-sidebar {
    position: sticky;
    top: 5rem;
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 10px;
    padding: 1.25rem;
    max-height: calc(100vh - 7rem);
    overflow-y: auto;
    box-shadow: var(--shadow);
}

aside.toc-sidebar h3 {
    font-size: 0.95rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-muted);
    margin-bottom: 0.75rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 0.5rem;
}

aside.toc-sidebar .toc > ul {
    list-style: none;
    padding-left: 0;
    font-size: 0.85rem;
}

aside.toc-sidebar .toc ul ul {
    padding-left: 1rem;
    list-style: none;
}

aside.toc-sidebar .toc a {
    color: var(--text-muted);
    text-decoration: none;
    display: block;
    padding: 0.25rem 0;
    line-height: 1.4;
    transition: color 0.15s;
}

aside.toc-sidebar .toc a:hover {
    color: var(--accent);
}

/* Article Content */
article.markdown-body {
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 2.5rem 3rem;
    box-shadow: var(--shadow);
    overflow-x: hidden;
}

@media (max-width: 640px) {
    article.markdown-body {
        padding: 1.5rem;
    }
}

.markdown-body h1 {
    font-size: 2rem;
    line-height: 1.3;
    margin-bottom: 0.5rem;
    padding-bottom: 0.75rem;
    border-bottom: 2px solid var(--border-color);
}

.markdown-body h2 {
    font-size: 1.5rem;
    margin-top: 2rem;
    margin-bottom: 0.75rem;
    padding-bottom: 0.4rem;
    border-bottom: 1px solid var(--border-color);
}

.markdown-body h3 {
    font-size: 1.25rem;
    margin-top: 1.5rem;
    margin-bottom: 0.5rem;
}

.markdown-body h4 {
    font-size: 1.05rem;
    margin-top: 1.25rem;
    margin-bottom: 0.5rem;
}

.markdown-body p {
    margin-bottom: 1.1rem;
}

.markdown-body a {
    color: var(--accent);
    text-decoration: none;
}

.markdown-body a:hover {
    text-decoration: underline;
}

.markdown-body ul, .markdown-body ol {
    margin-bottom: 1.25rem;
    padding-left: 1.75rem;
}

.markdown-body li {
    margin-bottom: 0.35rem;
}

.markdown-body blockquote {
    border-left: 4px solid var(--blockquote-border);
    padding: 0.75rem 1.25rem;
    margin: 1.25rem 0;
    background-color: var(--inline-code-bg);
    border-radius: 0 8px 8px 0;
    color: var(--text-muted);
}

.markdown-body blockquote p:last-child {
    margin-bottom: 0;
}

.markdown-body pre {
    background-color: var(--code-bg);
    color: var(--code-text);
    padding: 1.2rem;
    border-radius: 8px;
    overflow-x: auto;
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
    font-size: 0.88rem;
    line-height: 1.6;
    margin: 1.25rem 0;
    border: 1px solid var(--border-color);
}

.markdown-body code {
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
    font-size: 0.88em;
}

.markdown-body :not(pre) > code {
    background-color: var(--inline-code-bg);
    color: var(--inline-code-text);
    padding: 0.2em 0.4em;
    border-radius: 4px;
    border: 1px solid var(--border-color);
}

.markdown-body table {
    width: 100%;
    border-collapse: collapse;
    margin: 1.5rem 0;
    font-size: 0.92rem;
    overflow-x: auto;
    display: block;
}

.markdown-body th, .markdown-body td {
    border: 1px solid var(--border-color);
    padding: 0.65rem 0.9rem;
    text-align: left;
}

.markdown-body th {
    background-color: var(--inline-code-bg);
    font-weight: 600;
}

.markdown-body tr:nth-child(even) {
    background-color: var(--table-stripe);
}

.markdown-body hr {
    border: 0;
    height: 1px;
    background-color: var(--border-color);
    margin: 2rem 0;
}

.markdown-body img {
    max-width: 100%;
    height: auto;
    border-radius: 6px;
    margin: 1rem 0;
    border: 1px solid var(--border-color);
}

/* Footer */
footer.site-footer {
    border-top: 1px solid var(--border-color);
    background-color: var(--card-bg);
    padding: 2.5rem 1.5rem;
    margin-top: 4rem;
    text-align: center;
}

.footer-content {
    max-width: 900px;
    margin: 0 auto;
}

.footer-title {
    font-weight: 600;
    font-size: 1rem;
    margin-bottom: 0.5rem;
    color: var(--text-color);
}

.footer-author {
    font-size: 0.92rem;
    color: var(--text-muted);
}

.footer-author a {
    color: var(--accent);
    text-decoration: none;
    font-weight: 500;
}

.footer-author a:hover {
    text-decoration: underline;
}

/* Portal Landing Styles */
.hero-section {
    max-width: 1100px;
    margin: 2.5rem auto 1.5rem auto;
    padding: 2.5rem 2rem;
    background: linear-gradient(135deg, rgba(37, 99, 235, 0.08) 0%, rgba(147, 51, 234, 0.08) 100%);
    border: 1px solid var(--border-color);
    border-radius: 16px;
    text-align: center;
}

.hero-title {
    font-size: 2.4rem;
    font-weight: 800;
    letter-spacing: -0.02em;
    margin-bottom: 0.75rem;
    color: var(--text-color);
}

.hero-subtitle {
    font-size: 1.15rem;
    color: var(--text-muted);
    max-width: 800px;
    margin: 0 auto 1.5rem auto;
    line-height: 1.6;
}

.article-cards {
    max-width: 1100px;
    margin: 2rem auto;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
    gap: 1.5rem;
}

.article-card {
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 1.75rem;
    box-shadow: var(--shadow);
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    transition: transform 0.2s, border-color 0.2s;
}

.article-card:hover {
    transform: translateY(-3px);
    border-color: var(--accent);
}

.card-tag {
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--accent);
    margin-bottom: 0.5rem;
}

.card-title {
    font-size: 1.35rem;
    font-weight: 700;
    margin-bottom: 0.75rem;
    color: var(--text-color);
}

.card-desc {
    font-size: 0.92rem;
    color: var(--text-muted);
    margin-bottom: 1.25rem;
    flex-grow: 1;
}

.card-btn {
    display: inline-block;
    padding: 0.6rem 1.2rem;
    background-color: var(--accent);
    color: #ffffff;
    text-decoration: none;
    border-radius: 6px;
    font-weight: 600;
    font-size: 0.9rem;
    text-align: center;
    transition: background-color 0.2s;
}

.card-btn:hover {
    background-color: var(--accent-hover);
}

.feature-grid {
    max-width: 1100px;
    margin: 3rem auto;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 1.25rem;
}

.feature-box {
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 10px;
    padding: 1.25rem;
}

.feature-box h4 {
    font-size: 1.05rem;
    margin-bottom: 0.4rem;
    color: var(--text-color);
}

.feature-box p {
    font-size: 0.88rem;
    color: var(--text-muted);
}
"""

def generate_article_html(md_path, lang_code, title_suffix, active_tab):
    with open(md_path, 'r', encoding='utf-8') as f:
        text = f.read()

    md = markdown.Markdown(extensions=['tables', 'fenced_code', 'toc'])
    body_html = md.convert(text)
    toc_html = md.toc

    html = f"""<!DOCTYPE html>
<html lang="{lang_code}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title_suffix} - Shizuku_macos_restore_study</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header class="site-header">
        <div class="nav-container">
            <div class="logo-area">
                <a href="index.html">🍃 Shizuku_macos_restore_study</a>
            </div>
            <nav class="nav-links">
                <a href="index.html" class="lang-btn">🏠 Home</a>
                <a href="article-zh.html" class="lang-btn {'active' if active_tab == 'zh' else ''}">🇨🇳 简体中文</a>
                <a href="article-en.html" class="lang-btn {'active' if active_tab == 'en' else ''}">🇺🇸 English</a>
                <a href="article-jp.html" class="lang-btn {'active' if active_tab == 'jp' else ''}">🇯🇵 日本語</a>
            </nav>
        </div>
    </header>

    <div class="main-wrapper">
        <aside class="toc-sidebar">
            <h3>Table of Contents</h3>
            {toc_html}
        </aside>

        <article class="markdown-body">
            {body_html}
        </article>
    </div>

    <footer class="site-footer">
        <div class="footer-content">
            <p class="footer-title">Shizuku_macos_restore_study · Leaf LVNS Engine Reverse Engineering & Native macOS Restoration</p>
            <p class="footer-author">
                jill 推特<a href="https://x.com/jill05617147" target="_blank" rel="noopener noreferrer">@jill05617147</a> 微博<a href="https://weibo.com/n/jill_mk3" target="_blank" rel="noopener noreferrer">@jill_mk3</a>
            </p>
        </div>
    </footer>
</body>
</html>"""
    return html

def generate_index_html():
    return """<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Shizuku_macos_restore_study · Leaf LVNS 逆向与 macOS 原生重构研究工程</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header class="site-header">
        <div class="nav-container">
            <div class="logo-area">
                <a href="index.html">🍃 Shizuku_macos_restore_study</a>
            </div>
            <nav class="nav-links">
                <a href="index.html" class="lang-btn active">🏠 Home</a>
                <a href="article-zh.html" class="lang-btn">🇨🇳 简体中文</a>
                <a href="article-en.html" class="lang-btn">🇺🇸 English</a>
                <a href="article-jp.html" class="lang-btn">🇯🇵 日本語</a>
            </nav>
        </div>
    </header>

    <main>
        <section class="hero-section">
            <h1 class="hero-title">Leaf LVNS 逆向与 macOS 原生重构研究工程</h1>
            <p class="hero-subtitle">
                完整记录如何将 Leaf 于 1996 年发布的经典视觉小说《雫～しずく～》（以及同架构的 LVNS 引擎家族）从 Windows 95 原始数据中解构，并使用现代 Swift + Metal 管线原生呈现为 60Hz 独立应用的技术全景资料库。
            </p>
        </section>

        <section class="article-cards">
            <div class="article-card">
                <div>
                    <div class="card-tag">🇨🇳 简体中文 · 深度工程复盘</div>
                    <h2 class="card-title">中文工程技术指南</h2>
                    <p class="card-desc">
                        剔除全部修饰性文字的务实技术文档。深入二进制加法滚动解密、LZS3 截断守卫、24×24 点阵字库列优先解码、双层虚拟机（Event VM + Inline VM）、调色板暗化、13 种转场几何算法，以及钟楼 (448, 128) 隐藏音乐室反汇编实录。
                    </p>
                </div>
                <a href="article-zh.html" class="card-btn">阅读中文全文 →</a>
            </div>

            <div class="article-card">
                <div>
                    <div class="card-tag">🇺🇸 English · Engineering Postmortem</div>
                    <h2 class="card-title">English Technical Guide</h2>
                    <p class="card-desc">
                        A rigorous, pragmatic systems engineering postmortem. Covers proprietary PAK XOR cryptanalysis, positive vs inverted LZS3 decompression, 24x24 1bpp vertical font typography, CoreAudio mono 11025Hz exception handling, and App Nap throttling circumvention.
                    </p>
                </div>
                <a href="article-en.html" class="card-btn">Read English Article →</a>
            </div>

            <div class="article-card">
                <div>
                    <div class="card-tag">🇯🇵 日本語 · 技術仕様書</div>
                    <h2 class="card-title">日本語技術仕様書</h2>
                    <p class="card-desc">
                        LVNSエンジンのバイナリ解析、2層仮想マシンの設計、描画およびCoreAudio障害追究、タイトル画面 VA 0x430ebc の第5不可視ポインタから導く隠し音楽室の復元など、全工程を実務的・網羅的に解説した技術ドキュメント。
                    </p>
                </div>
                <a href="article-jp.html" class="card-btn">技術仕様書を読む →</a>
            </div>
        </section>

        <section class="feature-grid">
            <div class="feature-box">
                <h4>🔐 LEAFPACK 解密</h4>
                <p>11 字节累加滚动异或密钥盲破还原，无源码逆向 403 个游戏资产。</p>
            </div>
            <div class="feature-box">
                <h4>📜 双层虚拟机 (VM)</h4>
                <p>外层 Block 事件机与内层行内演出宏（B/E, C, S, D, M, P, F, Q）精准解耦。</p>
            </div>
            <div class="feature-box">
                <h4>🎨 视觉高保真渲染</h4>
                <p>25×13 Sound Novel 网格、三 Pass 硬阴影字绘、11/16 调色板暗化与 13 种转场。</p>
            </div>
            <div class="feature-box">
                <h4>🎵 音频与底层系统排错</h4>
                <p>AVAudioConverter 重采样规避 AppKit 静默异常，ProcessInfo 锁死 60Hz 刷新。</p>
            </div>
        </section>
    </main>

    <footer class="site-footer">
        <div class="footer-content">
            <p class="footer-title">Shizuku_macos_restore_study · Leaf LVNS Engine Reverse Engineering & Native macOS Restoration</p>
            <p class="footer-author">
                jill 推特<a href="https://x.com/jill05617147" target="_blank" rel="noopener noreferrer">@jill05617147</a> 微博<a href="https://weibo.com/n/jill_mk3" target="_blank" rel="noopener noreferrer">@jill_mk3</a>
            </p>
        </div>
    </footer>
</body>
</html>"""

# Generate CSS
css_path = os.path.join(ROOT_DIR, "style.css")
with open(css_path, "w", encoding="utf-8") as f:
    f.write(CSS_CONTENT)
print("Generated style.css")

# Generate Articles
zh_html = generate_article_html(os.path.join(ARTICLES_DIR, "leaf-galgame-port-zh.md"), "zh-CN", "Leaf galgame 移植工程文档 (中文)", "zh")
with open(os.path.join(ROOT_DIR, "article-zh.html"), "w", encoding="utf-8") as f:
    f.write(zh_html)
print("Generated article-zh.html")

en_html = generate_article_html(os.path.join(ARTICLES_DIR, "leaf-galgame-port-en.md"), "en", "Leaf LVNS Porting Guide (English)", "en")
with open(os.path.join(ROOT_DIR, "article-en.html"), "w", encoding="utf-8") as f:
    f.write(en_html)
print("Generated article-en.html")

jp_html = generate_article_html(os.path.join(ARTICLES_DIR, "leaf-galgame-port-jp.md"), "ja", "Leaf LVNS 移植技術仕様書 (日本語)", "jp")
with open(os.path.join(ROOT_DIR, "article-jp.html"), "w", encoding="utf-8") as f:
    f.write(jp_html)
print("Generated article-jp.html")

# Generate Index
index_html = generate_index_html()
with open(os.path.join(ROOT_DIR, "index.html"), "w", encoding="utf-8") as f:
    f.write(index_html)
print("Generated index.html")

print("All static HTML pages successfully generated!")
