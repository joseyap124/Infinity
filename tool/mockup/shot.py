import asyncio, pathlib
from playwright.async_api import async_playwright
H = pathlib.Path(__file__).parent
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={'width': 1800, 'height': 1000}, device_scale_factor=1.2)
        await pg.goto((H / 'mock.html').as_uri())
        await pg.wait_for_timeout(800)
        await pg.screenshot(path=str(H / 'mockup-infinity.png'), full_page=True)
        await b.close()
    from PIL import Image
    Image.open(H / 'mockup-infinity.png').convert('RGB').save(H / '../../docs/mockup-infinity.jpg', quality=86, optimize=True)
asyncio.run(main())
