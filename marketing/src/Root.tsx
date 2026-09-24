import { Composition, Still } from 'remotion';
import { AppStorePreview, previewSchema } from './AppStorePreview';
import { StoreOverview } from './StoreOverview';
import { StoreScreenshot, storeScreenshotSchema } from './StoreScreenshot';
import { TikTokPreview, tikTokSchema } from './TikTokPreview';

// 30 seconds @ 30 fps = 900 frames — App Store Preview max length.
// 1080×1920 portrait matches App Store Preview specs for iPhone.
export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Still id="StoreOverview" component={StoreOverview} width={2240} height={1480} />
      {/* Static App Store screenshots, 1290×2796 — see storeShots.ts for copy */}
      <Still
        id="StoreScreenshot"
        component={StoreScreenshot}
        width={1290}
        height={2796}
        schema={storeScreenshotSchema}
        defaultProps={{ locale: 'en' as const, slot: 1 }}
      />
      <Composition
        id="AppStorePreview"
        component={AppStorePreview}
        durationInFrames={900}
        fps={30}
        width={1080}
        height={1920}
        schema={previewSchema}
        defaultProps={{ locale: 'uk' as const }}
      />
      {/* TikTok / Reels — 15s tight cut, same 9:16 1080×1920 frame. */}
      <Composition
        id="TikTokPreview"
        component={TikTokPreview}
        durationInFrames={450}
        fps={30}
        width={1080}
        height={1920}
        schema={tikTokSchema}
        defaultProps={{ locale: 'uk' as const }}
      />
    </>
  );
};
