"""Agent-Wun Browser Automation.

Merges Agent Zero's Playwright tools with AgenticSeek's Selenium stealth browser.
"""
import logging
from typing import Optional, Dict, Any, List

logger = logging.getLogger("agent-wun.tools.browser")


class BrowserController:
    """Unified browser controller supporting Playwright and Selenium."""

    def __init__(self):
        self.playwright_page = None
        self.selenium_driver = None
        self._mode: Optional[str] = None

    async def open(self, url: str, mode: str = "playwright") -> str:
        self._mode = mode
        if mode == "playwright":
            return await self._open_playwright(url)
        elif mode == "selenium":
            return self._open_selenium(url)
        return f"Unknown browser mode: {mode}"

    async def _open_playwright(self, url: str) -> str:
        try:
            from playwright.async_api import async_playwright
            p = await async_playwright().start()
            browser = await p.chromium.launch(headless=True)
            self.playwright_page = await browser.new_page()
            await self.playwright_page.goto(url)
            title = await self.playwright_page.title()
            return f"Opened {url} (title: {title})"
        except Exception as e:
            return f"Playwright error: {e}"

    def _open_selenium(self, url: str) -> str:
        try:
            import undetected_chromedriver as uc
            options = uc.ChromeOptions()
            options.add_argument("--headless=new")
            options.add_argument("--no-sandbox")
            options.add_argument("--disable-dev-shm-usage")
            self.selenium_driver = uc.Chrome(options=options)
            self.selenium_driver.get(url)
            title = self.selenium_driver.title
            return f"Opened {url} (title: {title})"
        except Exception as e:
            return f"Selenium error: {e}"

    async def screenshot(self) -> str:
        if self.playwright_page:
            path = "tmp/browser_screenshot.png"
            await self.playwright_page.screenshot(path=path)
            return path
        elif self.selenium_driver:
            path = "tmp/browser_screenshot.png"
            self.selenium_driver.save_screenshot(path)
            return path
        return "No browser session active"

    async def close(self):
        if self.playwright_page:
            await self.playwright_page.close()
            self.playwright_page = None
        if self.selenium_driver:
            self.selenium_driver.quit()
            self.selenium_driver = None


_browser: Optional[BrowserController] = None


def get_browser() -> BrowserController:
    global _browser
    if _browser is None:
        _browser = BrowserController()
    return _browser
